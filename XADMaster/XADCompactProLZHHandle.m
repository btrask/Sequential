#import "XADCompactProLZHHandle.h"
#import "XADException.h"

@implementation XADCompactProLZHHandle

-(id)initWithHandle:(CSHandle *)handle blockSize:(int)blocklen
{
	if((self=[super initWithHandle:handle windowSize:8192]))
	{
		blocksize=blocklen;
		literalcode=lengthcode=offsetcode=nil;
	}
	return self;
}

-(void)dealloc
{
	[literalcode release];
	[lengthcode release];
	[offsetcode release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	blockcount=blocksize;
	blockstart=0;
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	@try
	{
		if(blockcount>=blocksize)
		{
			if(blockstart)
			{
				// Don't let your bad implementations leak into your file formats, people!
				CSInputSkipToByteBoundary(input);
				if((CSInputBufferOffset(input)-blockstart)&1) CSInputSkipBytes(input,3);
				else CSInputSkipBytes(input,2);
			}

			[literalcode release];
			[lengthcode release];
			[offsetcode release];
			literalcode=lengthcode=offsetcode=nil;
			literalcode=[self allocAndParseCodeOfSize:256];
			lengthcode=[self allocAndParseCodeOfSize:64];
			offsetcode=[self allocAndParseCodeOfSize:128];
			blockcount=0;
			blockstart=CSInputBufferOffset(input);
		}

		if(CSInputNextBit(input))
		{
			blockcount+=2;
			return CSInputNextSymbolUsingCode(input,literalcode);
		}
		else
		{
			blockcount+=3;

			*length=CSInputNextSymbolUsingCode(input,lengthcode);

			*offset=CSInputNextSymbolUsingCode(input,offsetcode)<<6;
			*offset|=CSInputNextBitString(input,6);

			return XADLZSSMatch;
		}
	}
	@catch(id e) { }

	return XADLZSSEnd;
}

-(XADPrefixCode *)allocAndParseCodeOfSize:(int)size
{
	int numbytes=CSInputNextByte(input);
	if(numbytes*2>size) [XADException raiseIllegalDataException];

	int codelengths[size];

	for(int i=0;i<numbytes;i++)
	{
		int val=CSInputNextByte(input);
		codelengths[2*i]=val>>4;
		codelengths[2*i+1]=val&0x0f;
	}
	for(int i=numbytes*2;i<size;i++) codelengths[i]=0;

	return [[XADPrefixCode alloc] initWithLengths:codelengths numberOfSymbols:size maximumLength:15 shortestCodeIsZeros:YES];
}

@end
