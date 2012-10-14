#import "XADPrefixCode.h"
#import "Realloc.h"

NSString *XADInvalidPrefixCodeException=@"XADInvalidPrefixCodeException";


struct XADCodeTreeNode
{
	int branches[2];
};

struct XADCodeTableEntry
{
	uint32_t length;
	int32_t value;
};


@implementation XADPrefixCode

static inline XADCodeTreeNode *NodePointer(XADPrefixCode *self,int node) { return &self->tree[node]; }
static inline int Branch(XADPrefixCode *self,int node,int bit) { return NodePointer(self,node)->branches[bit]; }
static inline void SetBranch(XADPrefixCode *self,int node,int bit,int nextnode) { NodePointer(self,node)->branches[bit]=nextnode; }

static inline int LeftBranch(XADPrefixCode *self,int node) { return Branch(self,node,0); }
static inline int RightBranch(XADPrefixCode *self,int node) { return Branch(self,node,1); }
static inline void SetLeftBranch(XADPrefixCode *self,int node,int nextnode) { SetBranch(self,node,0,nextnode); }
static inline void SetRightBranch(XADPrefixCode *self,int node,int nextnode) { SetBranch(self,node,1,nextnode); }

static inline int LeafValue(XADPrefixCode *self,int node) { return LeftBranch(self,node); }
static inline void SetLeafValue(XADPrefixCode *self,int node,int value) { SetLeftBranch(self,node,value); SetRightBranch(self,node,value); }

static inline void SetEmptyNode(XADPrefixCode *self,int node) { SetLeftBranch(self,node,-1); SetRightBranch(self,node,-2); }

static inline BOOL IsInvalidNode(XADPrefixCode *self,int node) { return node<0; }
static inline BOOL IsOpenBranch(XADPrefixCode *self,int node,int bit) { return IsInvalidNode(self,Branch(self,node,bit)); }
static inline BOOL IsEmptyNode(XADPrefixCode *self,int node) { return LeftBranch(self,node)==-1&&RightBranch(self,node)==-2; }
static inline BOOL IsLeafNode(XADPrefixCode *self,int node) { return LeftBranch(self,node)==RightBranch(self,node); }

static inline int NewNode(XADPrefixCode *self)
{
	self->tree=Realloc(self->tree,(self->numentries+1)*sizeof(XADCodeTreeNode));
	SetEmptyNode(self,self->numentries);
	return self->numentries++;
}



int CSInputNextSymbolUsingCode(CSInputBuffer *buf,XADPrefixCode *code)
{
	if(!code->table1) [code _makeTable];

	int bits=CSInputPeekBitString(buf,code->tablesize);

	int length=code->table1[bits].length;
	int value=code->table1[bits].value;

	if(length<0) [NSException raise:XADInvalidPrefixCodeException format:@"Invalid prefix code in bitstream"];

	if(length<=code->tablesize)
	{
		CSInputSkipPeekedBits(buf,length);
		return value;
	}

	CSInputSkipPeekedBits(buf,code->tablesize);

	int node=value;
	while(!IsLeafNode(code,node))
	{
		int bit=CSInputNextBit(buf);
		if(IsOpenBranch(code,node,bit)) [NSException raise:XADInvalidPrefixCodeException format:@"Invalid prefix code in bitstream"];
		node=Branch(code,node,bit);
	}
	return LeafValue(code,node);
}

int CSInputNextSymbolUsingCodeLE(CSInputBuffer *buf,XADPrefixCode *code)
{
	if(!code->table2) [code _makeTableLE];

	int bits=CSInputPeekBitStringLE(buf,code->tablesize);

	int length=code->table2[bits].length;
	int value=code->table2[bits].value;

	if(length<0) [NSException raise:XADInvalidPrefixCodeException format:@"Invalid prefix code in bitstream"];

	if(length<=code->tablesize)
	{
		CSInputSkipPeekedBitsLE(buf,length);
		return value;
	}

	CSInputSkipPeekedBitsLE(buf,code->tablesize);

	int node=value;
	while(!IsLeafNode(code,node))
	{
		int bit=CSInputNextBitLE(buf);
		if(IsOpenBranch(code,node,bit)) [NSException raise:XADInvalidPrefixCodeException format:@"Invalid prefix code in bitstream"];
		node=Branch(code,node,bit);
	}
	return LeafValue(code,node);
}

/*int CSInputNextSymbolUsingCode(CSInputBuffer *buf,XADPrefixCode *code)
{
	int node=0;
	while(!IsLeafNode(code,node))
	{
		int bit=CSInputNextBit(buf);
		if(IsOpenBranch(code,node,bit)) [NSException raise:XADInvalidPrefixCodeException format:@"Invalid prefix code in bitstream"];
		node=Branch(code,node,bit);
	}
	return LeafValue(code,node);
}

int CSInputNextSymbolUsingCodeLE(CSInputBuffer *buf,XADPrefixCode *code)
{
	int node=0;
	while(!IsLeafNode(code,node))
	{
		int bit=CSInputNextBitLE(buf);
		if(IsOpenBranch(code,node,bit)) [NSException raise:XADInvalidPrefixCodeException format:@"Invalid prefix code in bitstream"];
		node=Branch(code,node,bit);
	}
	return LeafValue(code,node);
}*/



+(XADPrefixCode *)prefixCode { return [[self new] autorelease]; }

+(XADPrefixCode *)prefixCodeWithLengths:(const int *)lengths numberOfSymbols:(int)numsymbols
maximumLength:(int)maxlength shortestCodeIsZeros:(BOOL)zeros
{
	return [[[self alloc] initWithLengths:lengths numberOfSymbols:numsymbols
	maximumLength:maxlength shortestCodeIsZeros:zeros] autorelease];
}

-(id)init
{
	if((self=[super init]))
	{
		tree=malloc(sizeof(int)*2);
		SetEmptyNode(self,0);
		numentries=1;
		minlength=INT_MAX;
		maxlength=INT_MIN;
		isstatic=NO;

		stack=nil;

		table1=table2=NULL;
	}
	return self;
}

-(id)initWithStaticTable:(int (*)[2])statictable
{
	if((self=[super init]))
	{
		tree=(XADCodeTreeNode *)statictable; // TODO: fix the ugly cast
		isstatic=YES;

		stack=nil;
		table1=table2=NULL;
	}
	return self;
}

-(id)initWithLengths:(const int *)lengths numberOfSymbols:(int)numsymbols
maximumLength:(int)maxcodelength shortestCodeIsZeros:(BOOL)zeros
{
	if((self=[self init]))
	{
		@try
		{
			int code=0,symbolsleft=numsymbols;

			for(int length=1;length<=maxcodelength;length++)
			{
				for(int i=0;i<numsymbols;i++)
				{
					if(lengths[i]!=length) continue;
					// Instead of reversing to get a low-bit-first code, we shift and use high-bit-first.
					if(zeros) [self addValue:i forCodeWithHighBitFirst:code length:length];
					else [self addValue:i forCodeWithHighBitFirst:~code length:length];
					code++;
					if(--symbolsleft==0) return self; // early exit if all codes have been handled
				}
				code<<=1;
			}
		}
		@catch (id e)
		{
			[self release];
			@throw;
		}
	}

	return self;
}


-(void)dealloc
{
	if(!isstatic) free(tree);
	free(table1);
	free(table2);
	[stack release];
	[super dealloc];
}

-(void)addValue:(int)value forCodeWithHighBitFirst:(uint32_t)code length:(int)length
{
	[self addValue:value forCodeWithHighBitFirst:code length:length repeatAt:length];
}

-(void)addValue:(int)value forCodeWithHighBitFirst:(uint32_t)code length:(int)length repeatAt:(int)repeatpos
{
	if(isstatic) [NSException raise:NSGenericException format:@"Attempted to add codes to a static prefix tree"];

	free(table1);
	free(table2);
	table1=table2=NULL;

	if(length>maxlength) maxlength=length;
	if(length<minlength) minlength=length;

	repeatpos=length-1-repeatpos;
	if(repeatpos==0||(repeatpos>=0&&(((code>>repeatpos-1)&3)==0||((code>>repeatpos-1)&3)==3)))
	[NSException raise:NSInvalidArgumentException format:@"Invalid repeat position"];

	int lastnode=0;
	for(int bitpos=length-1;bitpos>=0;bitpos--)
	{
		int bit=(code>>bitpos)&1;

		if(IsLeafNode(self,lastnode)) [NSException raise:NSInvalidArgumentException format:@"Prefix found"];

		if(bitpos==repeatpos)
		{
			if(!IsOpenBranch(self,lastnode,bit)) [NSException raise:NSInvalidArgumentException format:@"Invalid repeating code"];

			int repeatnode=NewNode(self);
			int nextnode=NewNode(self);

			SetBranch(self,lastnode,bit,repeatnode);
			SetBranch(self,repeatnode,bit,repeatnode);
			SetBranch(self,repeatnode,bit^1,nextnode);
			lastnode=nextnode;

			bitpos++; // terminating bit already handled, skip it
		}
		else
		{
			if(IsOpenBranch(self,lastnode,bit)) SetBranch(self,lastnode,bit,NewNode(self));
			lastnode=Branch(self,lastnode,bit);
		}

	}

	if(!IsEmptyNode(self,lastnode)) [NSException raise:NSInvalidArgumentException format:@"Prefix found"];
	SetLeafValue(self,lastnode,value);
}

static uint32_t Reverse32(uint32_t val)
{
	val=((val>>1)&0x55555555)|((val&0x55555555)<<1);
	val=((val>>2)&0x33333333)|((val&0x33333333)<<2);
	val=((val>>4)&0x0F0F0F0F)|((val&0x0F0F0F0F)<<4);
	val=((val>>8)&0x00FF00FF)|((val&0x00FF00FF)<<8);
	return (val>>16)|(val<<16);
}

static uint32_t ReverseN(uint32_t val,int length)
{
	return Reverse32(val)>>(32-length);
}

-(void)addValue:(int)value forCodeWithLowBitFirst:(uint32_t)code length:(int)length
{
	[self addValue:value forCodeWithHighBitFirst:ReverseN(code,length) length:length repeatAt:length];
}

-(void)addValue:(int)value forCodeWithLowBitFirst:(uint32_t)code length:(int)length repeatAt:(int)repeatpos
{
	[self addValue:value forCodeWithHighBitFirst:ReverseN(code,length) length:length repeatAt:repeatpos];
}

-(void)startBuildingTree
{
	currnode=0;
	if(!stack) stack=[NSMutableArray new];
	else [stack removeAllObjects];
}

-(void)startZeroBranch
{
	int new=NewNode(self);
	SetBranch(self,currnode,0,new);
	[self _pushNode];
	currnode=new;
}

-(void)startOneBranch
{
	int new=NewNode(self);
	SetBranch(self,currnode,1,new);
	[self _pushNode];
	currnode=new;
}

-(void)finishBranches
{
	[self _popNode];
}

-(void)makeLeafWithValue:(int)value
{
	SetLeafValue(self,currnode,value);
	[self _popNode];
}

-(void)_pushNode
{
	[stack addObject:[NSNumber numberWithInt:currnode]];
}

-(void)_popNode
{
	if(![stack count]) return; // the final pop will underflow the stack otherwise
	NSNumber *num=[stack lastObject];
	[stack removeLastObject];
	currnode=[num intValue];
}

static void MakeTable(XADPrefixCode *code,int node,XADCodeTableEntry *table,int depth,int maxdepth)
{
	int currtablesize=1<<(maxdepth-depth);

	if(IsLeafNode(code,node))
	{
		for(int i=0;i<currtablesize;i++)
		{
			table[i].length=depth;
			table[i].value=LeafValue(code,node);
		}
	}
	else if(IsInvalidNode(code,node))
	{
		for(int i=0;i<currtablesize;i++) table[i].length=-1;
	}
	else
	{
		if(depth==maxdepth)
		{
			table[0].length=maxdepth+1;
			table[0].value=node;
		}
		else
		{
			MakeTable(code,LeftBranch(code,node),table,depth+1,maxdepth);
			MakeTable(code,RightBranch(code,node),table+currtablesize/2,depth+1,maxdepth);
		}
	}
}

static void MakeTableLE(XADPrefixCode *code,int node,XADCodeTableEntry *table,int depth,int maxdepth)
{
	int currtablesize=1<<(maxdepth-depth);
	int currstride=1<<depth;

	if(IsLeafNode(code,node))
	{
		for(int i=0;i<currtablesize;i++)
		{
			table[i*currstride].length=depth;
			table[i*currstride].value=LeafValue(code,node);
		}
	}
	else if(IsInvalidNode(code,node))
	{
		for(int i=0;i<currtablesize;i++) table[i*currstride].length=-1;
	}
	else
	{
		if(depth==maxdepth)
		{
			table[0].length=maxdepth+1;
			table[0].value=node;
		}
		else
		{
			MakeTableLE(code,LeftBranch(code,node),table,depth+1,maxdepth);
			MakeTableLE(code,RightBranch(code,node),table+currstride,depth+1,maxdepth);
		}
	}
}

#define TableMaxSize 10

-(void)_makeTable
{
	if(table1) return;

	if(maxlength<minlength) tablesize=TableMaxSize; // no code lengths recorded
	else if(maxlength>=TableMaxSize) tablesize=TableMaxSize;
	else tablesize=maxlength;

	table1=malloc(sizeof(XADCodeTableEntry)*(1<<tablesize));

	MakeTable(self,0,table1,0,tablesize);
}

-(void)_makeTableLE
{
	if(table2) return;

	if(maxlength<minlength) tablesize=TableMaxSize; // no code lengths recorded
	else if(maxlength>=TableMaxSize) tablesize=TableMaxSize;
	else tablesize=maxlength;

	table2=malloc(sizeof(XADCodeTableEntry)*(1<<tablesize));

	MakeTableLE(self,0,table2,0,tablesize);
}

@end

