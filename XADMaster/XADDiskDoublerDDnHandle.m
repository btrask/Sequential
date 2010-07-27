#import "XADDiskDoublerDDnHandle.h"
#import "XADException.h"

static void CopyBytesWithRepeat(uint8_t *dest,uint8_t *src,int length)
{
	for(int i=0;i<length;i++) dest[i]=src[i];
}

@implementation XADDiskDoublerDDnHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length windowSize:65536])
	{
		lengthcode=nil;
	}
	return self;
}

-(void)dealloc
{
	[lengthcode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	nextblock=0;
	blockend=0;
	literalsleft=0;
	correctxor=0;
	checksumcorrect=YES;
}

-(int)nextLiteralOrOffset:(int *)offsetout andLength:(int *)lengthout atPosition:(off_t)pos
{
	if(pos>=blockend) [self readBlockAtPosition:pos];

	if(uncompressed) return CSInputNextByte(input);

	if(literalsleft)
	{
		literalsleft--;
		// TODO: check for literals left
		return *literalptr++;
	}

	int code=CSInputNextSymbolUsingCode(input,lengthcode);
	if(code==0)
	{
		// TODO: check for literals left
		return *literalptr++;
	}
	else if(code<128)
	{
		int length=code+2;
		// TODO: check for offsets left
		int offset=*offsetptr++;

		if(offset>pos) [XADException raiseIllegalDataException];
		if(pos+length>blockend) length=blockend-pos;

		*offsetout=offset;
		*lengthout=length;
		return XADLZSSMatch;
	}
	else
	{
		int length=1<<(code-128);

		if(pos+length>blockend) length=blockend-pos;
		// TODO: check for literals left

		literalsleft=length-1;
		return *literalptr++;
	}
}

-(void)readBlockAtPosition:(off_t)pos
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	if(blocksize<=65536)
	{
		int xor=0;
		for(int i=0;i<blocksize;i++) xor^=windowbuffer[(pos-blocksize+i)&windowmask];
		if(xor!=correctxor) checksumcorrect=NO;
	}

	CSInputSeekToBufferOffset(input,nextblock);

	uint8_t headxor=0;

	uint32_t uncompsize=CSInputNextUInt32BE(input);
	headxor^=uncompsize^(uncompsize>>8)^(uncompsize>>16)^(uncompsize>>24);

	int numliterals=CSInputNextUInt16BE(input);
	headxor^=numliterals^(numliterals>>8);

	int numoffsets=CSInputNextUInt16BE(input);
	headxor^=numoffsets^(numoffsets>>8);

	int lengthcompsize=CSInputNextUInt16BE(input);
	headxor^=lengthcompsize^(lengthcompsize>>8);

	int literalcompsize=CSInputNextUInt16BE(input);
	headxor^=literalcompsize^(literalcompsize>>8);

	int offsetcompsize=CSInputNextUInt16BE(input);
	headxor^=offsetcompsize^(offsetcompsize>>8);

	int flags=CSInputNextByte(input);
	headxor^=flags;

	headxor^=CSInputNextByte(input);

	int datacorrectxor1=CSInputNextByte(input);
	headxor^=datacorrectxor1;

	int datacorrectxor2=CSInputNextByte(input);
	headxor^=datacorrectxor2;

	int datacorrectxor3=CSInputNextByte(input);
	headxor^=datacorrectxor3;

	int uncompcorrectxor=CSInputNextByte(input);
	headxor^=uncompcorrectxor;

	headxor^=CSInputNextByte(input);

	int headcorrectxor=CSInputNextByte(input);
	if(headxor!=headcorrectxor) [XADException raiseIllegalDataException];

	//NSLog(@"%d (%d %d) %d %d %d %x <%x %x %x %x>",uncompsize,numliterals,numoffsets,lengthcompsize,literalcompsize,offsetcompsize,
	//flags,datacorrectxor1,datacorrectxor2,datacorrectxor3,uncompcorrectxor);

	blocksize=uncompsize;
	blockend=pos+uncompsize;
	correctxor=uncompcorrectxor;

	if(flags&0x40)
	{
		uncompressed=YES;
		[pool release];
		return;
	}

	off_t literalstart=CSInputBufferOffset(input)+offsetcompsize;
	off_t lengthstart=literalstart+literalcompsize;
	nextblock=lengthstart+lengthcompsize;

	if(numliterals+numoffsets*2>sizeof(buffer)) [XADException raiseIllegalDataException];

	literalptr=buffer;
	offsetptr=(uint16_t *)&buffer[numliterals];

	XADPrefixCode *offsetcode=[self readCode];

	for(int i=0;i<numoffsets;i++)
	{
		int slot=CSInputNextSymbolUsingCode(input,offsetcode);

		if(slot<4)
		{
			offsetptr[i]=slot+1;
		}
		else
		{
			int bits=slot/2-1;
			int start=((2+(slot&1))<<bits)+1;
			offsetptr[i]=start+CSInputNextBitString(input,bits);
		}
	}

	CSInputSeekToBufferOffset(input,literalstart);

	if(flags&0x80)
	{
		XADPrefixCode *literalcode=[self readCode];

		// Compressed literals
		for(int i=0;i<numliterals;i++) literalptr[i]=CSInputNextSymbolUsingCode(input,literalcode);
	}
	else
	{
		// Uncompressed literals
		for(int i=0;i<numliterals;i++) literalptr[i]=CSInputNextByte(input);
	}

	CSInputSeekToBufferOffset(input,lengthstart);

	[lengthcode release];
	lengthcode=[[self readCode] retain];

	[pool release];
}

-(XADPrefixCode *)readCode
{
	uint32_t head=CSInputNextUInt32BE(input);

	int numcodes=((head>>24)&0xff)+1;
	int numbytes=(head>>13)&0x7ff;
	int maxlength=(head>>8)&0x1f;
	int numbits=(head>>3)&0x1f;
	int codelengths[numcodes];

	off_t end=CSInputBufferOffset(input)+numbytes;

	if(head&0x04) // uses zero coding
	{
		for(int i=0;i<numcodes;i++)
		{
			if(CSInputNextBit(input))
			{
				codelengths[i]=CSInputNextBitString(input,numbits);
				if(codelengths[i]>maxlength) [XADException raiseIllegalDataException];
			}
			else codelengths[i]=0;
		}
	}
	else
	{
		for(int i=0;i<numcodes;i++)
		{
			codelengths[i]=CSInputNextBitString(input,numbits);
			if(codelengths[i]>maxlength) [XADException raiseIllegalDataException];
		}
	}

	CSInputSeekToBufferOffset(input,end);

	return [XADPrefixCode prefixCodeWithLengths:codelengths numberOfSymbols:numcodes
	maximumLength:maxlength shortestCodeIsZeros:YES];
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect { return streampos==blockend && checksumcorrect; }

@end
