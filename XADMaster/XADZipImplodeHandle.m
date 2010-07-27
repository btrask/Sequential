#import "XADZipImplodeHandle.h"
#import "XADException.h"

@implementation XADZipImplodeHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
largeDictionary:(BOOL)largedict hasLiterals:(BOOL)hasliterals
{
	if(self=[super initWithHandle:handle length:length windowSize:largedict?8192:4096])
	{
		if(largedict) offsetbits=7;
		else offsetbits=6;

		literals=hasliterals;

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
	[literalcode release];
	[lengthcode release];
	[offsetcode release];
	literalcode=lengthcode=offsetcode=nil;

	if(literals) literalcode=[self allocAndParseCodeOfSize:256];
	lengthcode=[self allocAndParseCodeOfSize:64];
	offsetcode=[self allocAndParseCodeOfSize:64];
}

-(XADPrefixCode *)allocAndParseCodeOfSize:(int)size
{
	int numgroups=CSInputNextByte(input)+1;

	int codelengths[size],currcode=0;
	for(int i=0;i<numgroups;i++)
	{
		int val=CSInputNextByte(input);
		int num=(val>>4)+1;
		int length=(val&0x0f)+1;
		while(num--) codelengths[currcode++]=length;
	}
	if(currcode!=size) [XADException raiseDecrunchException];

	return [[XADPrefixCode alloc] initWithLengths:codelengths numberOfSymbols:size maximumLength:16 shortestCodeIsZeros:NO];
}

-(void)expandFromPosition:(off_t)pos;
{
	while(XADLZSSShouldKeepExpanding(self))
	{
		if(CSInputNextBitLE(input))
		{
			if(literals) XADLZSSLiteral(self,CSInputNextSymbolUsingCodeLE(input,literalcode),NULL);
			else XADLZSSLiteral(self,CSInputNextBitStringLE(input,8),NULL);
		}
		else
		{
			int offset=CSInputNextBitStringLE(input,offsetbits);
			offset|=CSInputNextSymbolUsingCodeLE(input,offsetcode)<<offsetbits;
			offset+=1;

			int length=CSInputNextSymbolUsingCodeLE(input,lengthcode)+2;
			if(length==65) length+=CSInputNextBitStringLE(input,8);
			if(literals) length++;

			XADLZSSMatch(self,offset,length,NULL);
		}
	}
}

@end

