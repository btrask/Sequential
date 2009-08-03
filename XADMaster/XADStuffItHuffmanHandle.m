#import "XADStuffItHuffmanHandle.h"

@implementation XADStuffItHuffmanHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length])
	{
		code=nil;
	}
	return self;
}

-(void)dealloc
{
	[code release];
	[super dealloc];
}

-(void)resetByteStream
{
	[code release];
	code=[XADPrefixCode new];

	[code startBuildingTree];
	[self parseTree];
}

-(void)parseTree
{
	if(CSInputNextBit(input)==1)
	{
		[code makeLeafWithValue:CSInputNextBitString(input,8)];
	}
	else
	{
		[code startZeroBranch];
		[self parseTree];
		[code startOneBranch];
		[self parseTree];
		[code finishBranches];
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	return CSInputNextSymbolUsingCode(input,code);
}

@end
