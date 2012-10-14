#import "XADSqueezeHandle.h"
#import "XADException.h"

@implementation XADSqueezeHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithHandle:handle length:length]))
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


static void BuildCodeFromTree(XADPrefixCode *code,int *tree,int node,int numnodes)
{
	if(node<0)
	{
		[code makeLeafWithValue:-(node+1)];
	}
	else
	{
		[code startZeroBranch];
		BuildCodeFromTree(code,tree,tree[2*node],numnodes);
		[code startOneBranch];
		BuildCodeFromTree(code,tree,tree[2*node+1],numnodes);
		[code finishBranches];
	}
}

-(void)resetByteStream
{
	int numnodes=CSInputNextUInt16LE(input)*2;
	if(numnodes>=257*2) [XADException raiseDecrunchException];

	int nodes[numnodes];
	nodes[0]=nodes[1]=-(256+1);

	for(int i=0;i<numnodes;i++) nodes[i]=CSInputNextInt16LE(input);

	[code release];
	code=[XADPrefixCode new];

	[code startBuildingTree];
	BuildCodeFromTree(code,nodes,0,numnodes);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int symbol=CSInputNextSymbolUsingCodeLE(input,code);
	if(symbol==256) CSByteStreamEOF(self);
	return symbol;
}

@end
