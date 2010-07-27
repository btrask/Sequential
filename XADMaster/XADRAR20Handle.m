#import "XADRAR20Handle.h"
#import "XADException.h"

@implementation XADRAR20Handle

-(id)initWithRARParser:(XADRARParser *)parent parts:(NSArray *)partarray
{
	if(self=[super initWithName:[parent filename] windowSize:0x100000])
	{
		parser=parent;
		parts=[partarray retain];

		maincode=nil;
		offsetcode=nil;
		lengthcode=nil;
		for(int i=0;i<4;i++) audiocode[i]=nil;
	}
	return self;
}

-(void)dealloc
{
	[parts release];
	[maincode release];
	[offsetcode release];
	[lengthcode release];
	for(int i=0;i<4;i++) [audiocode[i] release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	part=0;
	endpos=0;

	lastoffset=0;
	lastlength=0;
	memset(oldoffset,0,sizeof(oldoffset));
	oldoffsetindex=0;

	channel=channeldelta=0;
	memset(audiostate,0,sizeof(audiostate));

	memset(lengthtable,0,sizeof(lengthtable));

	[self startNextPart];
	[self allocAndParseCodes];
}

-(void)startNextPart
{
	off_t partlength;
	CSInputBuffer *buf=[parser inputBufferForNextPart:&part parts:parts length:&partlength];

	[self setInputBuffer:buf];
	endpos+=partlength;
}

-(void)expandFromPosition:(off_t)pos
{
	static const int lengthbases[28]={0,1,2,3,4,5,6,7,8,10,12,14,16,20,24,28,32,
	40,48,56,64,80,96,112,128,160,192,224};
	static const int lengthbits[28]={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5};
	static const int offsetbases[48]={0,1,2,3,4,6,8,12,16,24,32,48,64,96,128,192,256,384,
	512,768,1024,1536,2048,3072,4096,6144,8192,12288,16384,24576,32768,49152,
	65536,98304,131072,196608,262144,327680,393216,458752,524288,589824,655360,
	720896,786432,851968,917504,983040};
	static unsigned char offsetbits[48]={0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,
	9,10,10,11,11,12,12,13,13,14,14,15,15,16,16,16,16,16,16,16,16,16,16,16,16,16,16};
	static unsigned int shortbases[8]={0,4,8,16,32,64,128,192};
	static unsigned int shortbits[8]={2,2,3,4,5,6,6,6};

	while(XADLZSSShouldKeepExpanding(self))
	{
		if(pos==endpos)
		{
/*			if(1) //if(ReadTop>=InAddr+5)
			if(audioblock)
			{
				//if (DecodeNumber((struct Decode *)&MD[UnpCurChannel])==256)ReadTables20();
			}
			else
			{
				if(CSInputNextSymbolUsingCode(input,maincode)==269) [self allocAndParseCodes];
			}*/

			[self startNextPart];
		}

		if(audioblock)
		{
			int symbol=CSInputNextSymbolUsingCode(input,audiocode[channel]);
			if(symbol==256)
			{
				[self allocAndParseCodes];
				continue;
				//return [self nextLiteralOrOffset:offset andLength:length atPosition:pos];
			}
			else
			{
				int byte=DecodeRAR20Audio(&audiostate[channel],&channeldelta,symbol);

				channel++;
				if(channel==numchannels) channel=0;

				XADLZSSLiteral(self,byte,&pos);
				//return byte;
			}
		}
		else
		{
			int symbol=CSInputNextSymbolUsingCode(input,maincode);
			int offs,len;

//			if(symbol<256) return symbol;
			if(symbol<256)
			{
				XADLZSSLiteral(self,symbol,&pos);
				continue;
			}
			else if(symbol==256)
			{
				offs=lastoffset;
				len=lastlength;
			}
			else if(symbol<=260)
			{
				offs=oldoffset[(oldoffsetindex-(symbol-256))&3];

				int lensymbol=CSInputNextSymbolUsingCode(input,lengthcode);
				len=lengthbases[lensymbol]+2;
				if(lengthbits[lensymbol]>0) len+=CSInputNextBitString(input,lengthbits[lensymbol]);

				if(offs>=0x40000) len++;
				if(offs>=0x2000) len++;
				if(offs>=0x101) len++;
			}
			else if(symbol<=268)
			{
				offs=shortbases[symbol-261]+1;
				if(shortbits[symbol-261]>0) offs+=CSInputNextBitString(input,shortbits[symbol-261]);

				len=2;
			}
			else if(symbol==269)
			{
				[self allocAndParseCodes];
				continue;
//				return [self nextLiteralOrOffset:offset andLength:length atPosition:pos];
			}
			else //if(code>=270)
			{
				len=lengthbases[symbol-270]+3;
				if(lengthbits[symbol-270]>0) len+=CSInputNextBitString(input,lengthbits[symbol-270]);

				int offssymbol=CSInputNextSymbolUsingCode(input,offsetcode);
				offs=offsetbases[offssymbol]+1;
				if(offsetbits[offssymbol]>0) offs+=CSInputNextBitString(input,offsetbits[offssymbol]);

				if(offs>=0x40000) len++;
				if(offs>=0x2000) len++;
			}

			lastoffset=oldoffset[oldoffsetindex++&3]=offs;
			lastlength=len;

//			*offset=offs;
//			*length=len;
//
//			return XADLZSSMatch;
			XADLZSSMatch(self,offs,len,&pos);
		}
	}
}

-(void)allocAndParseCodes
{
	[maincode release]; maincode=nil;
	[offsetcode release]; offsetcode=nil;
	[lengthcode release]; lengthcode=nil;
	for(int i=0;i<4;i++) { [audiocode[i] release]; audiocode[i]=nil; }

	audioblock=CSInputNextBit(input);

	if(CSInputNextBit(input)==0) memset(lengthtable,0,sizeof(lengthtable));

	int count;
	if(audioblock)
	{
		numchannels=CSInputNextBitString(input,2)+1;
		count=numchannels*257;
		if(channel>=numchannels) channel=0;
	}
	else count=298+48+28;

	XADPrefixCode *precode=nil;
	@try
	{
		int prelengths[19];
		for(int i=0;i<19;i++) prelengths[i]=CSInputNextBitString(input,4);

		precode=[[XADPrefixCode alloc] initWithLengths:prelengths
		numberOfSymbols:19 maximumLength:15 shortestCodeIsZeros:YES];

		int i=0;
		while(i<count)
		{
			int val=CSInputNextSymbolUsingCode(input,precode);
//NSLog(@"%d",val);
			if(val<16)
			{
				lengthtable[i]=(lengthtable[i]+val)&0x0f;
				i++;
			}
			else if(val==16)
			{
				if(i==0) [XADException raiseDecrunchException];
				int n=CSInputNextBitString(input,2)+3;
				for(int j=0;j<n && i<count;j++)
				{
					lengthtable[i]=lengthtable[i-1];
					i++;
				}
			}
			else
			{
				int n;
				if(val==17) n=CSInputNextBitString(input,3)+3;
				else n=CSInputNextBitString(input,7)+11;

				for(int j=0;j<n && i<count;j++) lengthtable[i++]=0;
			}
		}

		[precode release];
	}
	@catch(id e)
	{
		[precode release];
		@throw;
	}

	if(audioblock)
	{
		for(int i=0;i<numchannels;i++) audiocode[i]=[[XADPrefixCode alloc]
		initWithLengths:&lengthtable[i*257]
		numberOfSymbols:257 maximumLength:15 shortestCodeIsZeros:YES];
	}
	else
	{
		maincode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[0]
		numberOfSymbols:298 maximumLength:15 shortestCodeIsZeros:YES];

		offsetcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[298]
		numberOfSymbols:48 maximumLength:15 shortestCodeIsZeros:YES];

		lengthcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[298+48]
		numberOfSymbols:28 maximumLength:15 shortestCodeIsZeros:YES];
	}
}

@end

