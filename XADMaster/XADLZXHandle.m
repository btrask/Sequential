#import "XADLZXHandle.h"
#import "XADException.h"

@implementation XADLZXHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:[[[XADLZXSwapHandle alloc] initWithHandle:handle] autorelease]
	length:length windowSize:65536])
	{
		maincode=offsetcode=nil;
	}
	return self;
}

-(void)dealloc
{
	[maincode release];
	[offsetcode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	lastoffs=1;
	blockend=0;
	memset(mainlengths,0,sizeof(mainlengths));
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	static const unsigned char AdditionalBitsTable[32]=
	{
		0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14
	};

	static const unsigned int BaseTable[32]=
	{
		0,1,2,3,4,6,8,12,16,24,32,48,64,96,128,192,256,384,512,768,1024,
		1536,2048,3072,4096,6144,8192,12288,16384,24576,32768,49152
	};

	if(pos>=blockend) [self readBlockHeaderAtPosition:pos];

	int symbol=CSInputNextSymbolUsingCodeLE(input,maincode);
	if(symbol<256) return symbol;

	int offsclass=symbol&31;
	int offs=BaseTable[offsclass];
	int offsbits=AdditionalBitsTable[offsclass];

	if(offs==0)
	{
		offs=lastoffs;
	}
	else if(blocktype==3 && offsbits>=3)
	{
		offs+=CSInputNextBitStringLE(input,offsbits-3)<<3;
		offs+=CSInputNextSymbolUsingCodeLE(input,offsetcode);
	}
	else
	{
		offs+=CSInputNextBitStringLE(input,offsbits);
	}

	int lenclass=((symbol-256)>>5)&15;
	int len=BaseTable[lenclass]+3;
	int lenbits=AdditionalBitsTable[lenclass];
	len+=CSInputNextBitStringLE(input,lenbits);

	*offset=offs;
	*length=len;
	lastoffs=offs;

	return XADLZSSMatch;
}

-(void)readBlockHeaderAtPosition:(off_t)pos
{
	[maincode release];
	[offsetcode release];
	maincode=offsetcode=nil;

	blocktype=CSInputNextBitStringLE(input,3);
	if(blocktype<1||blocktype>3) [XADException raiseIllegalDataException];

	if(blocktype==1) [XADException raiseNotSupportedException]; // Never encountered one of these?

	if(blocktype==3)
	{
		int codelengths[8];
		for(int i=0;i<8;i++) codelengths[i]=CSInputNextBitStringLE(input,3);

		offsetcode=[[XADPrefixCode alloc] initWithLengths:codelengths
		numberOfSymbols:8 maximumLength:7 shortestCodeIsZeros:YES];
	}

	int blocksize=CSInputNextBitStringLE(input,8)<<16;
	blocksize|=CSInputNextBitStringLE(input,8)<<8;
	blocksize|=CSInputNextBitStringLE(input,8);

	blockend=pos+blocksize;

	if(blocktype!=1)
	{
		[self readDeltaLengths:&mainlengths[0] count:256 alternateMode:NO];
		[self readDeltaLengths:&mainlengths[256] count:512 alternateMode:YES];

		maincode=[[XADPrefixCode alloc] initWithLengths:mainlengths
		numberOfSymbols:768 maximumLength:16 shortestCodeIsZeros:YES];
	}
}

-(void)readDeltaLengths:(int *)lengths count:(int)count alternateMode:(BOOL)altmode;
{
	XADPrefixCode *precode=nil;
	int fix=altmode?1:0;

	@try
	{
		int prelengths[20];
		for(int i=0;i<20;i++) prelengths[i]=CSInputNextBitStringLE(input,4);

		precode=[[XADPrefixCode alloc] initWithLengths:prelengths
		numberOfSymbols:20 maximumLength:15 shortestCodeIsZeros:YES];

		int i=0;
		while(i<count)
		{
			int val=CSInputNextSymbolUsingCodeLE(input,precode);
			int n,length;

			if(val<=16)
			{
				n=1;
				length=(lengths[i]+17-val)%17;
			}
			else if(val==17)
			{
				n=CSInputNextBitStringLE(input,4)+4-fix;
				length=0;
			}
			else if(val==18)
			{
				n=CSInputNextBitStringLE(input,5+fix)+20-fix;
				length=0;
			}
			else if(val==19)
			{
				n=CSInputNextBitStringLE(input,1)+4-fix;
				int newval=CSInputNextSymbolUsingCodeLE(input,precode);
				length=(lengths[i]+17-newval)%17;
			}

			for(int j=0;j<n;j++) lengths[i+j]=length;
			i+=n;
		}

		[precode release];
	}
	@catch(id e)
	{
		[precode release];
		@throw;
	}
}

@end



@implementation XADLZXSwapHandle

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(pos&1) return otherbyte;

	if(CSInputAtEOF(input)) CSByteStreamEOF(self);
	otherbyte=CSInputNextByte(input);
	if(CSInputAtEOF(input)) CSByteStreamEOF(self);
	return CSInputNextByte(input);
}

@end

