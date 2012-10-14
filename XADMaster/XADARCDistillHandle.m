#import "XADARCDistillHandle.h"
#import "XADException.h"

static const int offsetlengths[0x40]=
{
	3,4,4,4, 5,5,5,5, 5,5,5,5, 6,6,6,6,
	6,6,6,6, 6,6,6,6, 7,7,7,7, 7,7,7,7,
	7,7,7,7, 7,7,7,7, 7,7,7,7, 7,7,7,7,
	8,8,8,8, 8,8,8,8, 8,8,8,8, 8,8,8,8,
};

static const int offsetcodes[0x40]=
{
	0x00,0x02,0x04,0x0c,0x01,0x06,0x0a,0x0e,
	0x11,0x16,0x1a,0x1e,0x05,0x09,0x0d,0x15,
	0x19,0x1d,0x25,0x29,0x2d,0x35,0x39,0x3d,
	0x03,0x07,0x0b,0x13,0x17,0x1b,0x23,0x27,
	0x2b,0x33,0x37,0x3b,0x43,0x47,0x4b,0x53,
	0x57,0x5b,0x63,0x67,0x6b,0x73,0x77,0x7b,
	0x0f,0x1f,0x2f,0x3f,0x4f,0x5f,0x6f,0x7f,
	0x8f,0x9f,0xaf,0xbf,0xcf,0xdf,0xef,0xff,
};

@implementation XADARCDistillHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithHandle:handle length:length windowSize:8192]))
	{
		maincode=nil;
		offsetcode=[XADPrefixCode new];
		for(int i=0;i<0x40;i++)
		[offsetcode addValue:i forCodeWithLowBitFirst:offsetcodes[i] length:offsetlengths[i]];
	}
	return self;
}

-(void)dealloc
{
	[maincode release];
	[offsetcode release];
	[super dealloc];
}

static void BuildCodeFromTree(XADPrefixCode *code,int *tree,int node,int numnodes)
{
	if(node>=numnodes)
	{
		[code makeLeafWithValue:node-numnodes];
	}
	else
	{
		[code startZeroBranch];
		BuildCodeFromTree(code,tree,tree[node],numnodes);
		[code startOneBranch];
		BuildCodeFromTree(code,tree,tree[node+1],numnodes);
		[code finishBranches];
	}
}

-(void)resetLZSSHandle
{
	int numnodes=CSInputNextUInt16LE(input);
	int codelength=CSInputNextByte(input);

	if(numnodes>0x274) [XADException raiseDecrunchException];

	int nodes[numnodes];
	for(int i=0;i<numnodes;i++) nodes[i]=CSInputNextBitStringLE(input,codelength);

	[maincode release];
	maincode=[XADPrefixCode new];

	[maincode startBuildingTree];
	BuildCodeFromTree(maincode,nodes,numnodes-2,numnodes);
}

-(void)expandFromPosition:(off_t)pos
{
	while(XADLZSSShouldKeepExpanding(self))
	{
		int symbol=CSInputNextSymbolUsingCodeLE(input,maincode);

		if(symbol<256)
		{
			XADEmitLZSSLiteral(self,symbol,&pos);
		}
		else if(symbol==256)
		{
			[self endLZSSHandle];
			return;
		}
		else
		{
			int length=symbol-0x101+3;

			int offsetsymbol=CSInputNextSymbolUsingCodeLE(input,offsetcode);

			int extralength;
			if(pos>=0x1000-0x3c) extralength=7;
			else if(pos>=0x800-0x3c) extralength=6;
			else if(pos>=0x400-0x3c) extralength=5;
			else if(pos>=0x200-0x3c) extralength=4;
			else if(pos>=0x100-0x3c) extralength=3;
			else if(pos>=0x80-0x3c) extralength=2;
			else if(pos>=0x40-0x3c) extralength=1;
			else extralength=0;

			int extrabits=CSInputNextBitStringLE(input,extralength);
			int offset=(offsetsymbol<<extralength)+extrabits+1;

			XADEmitLZSSMatch(self,offset,length,&pos);
		}
	}
}

@end

