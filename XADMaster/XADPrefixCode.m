#import "XADPrefixCode.h"
#import "SystemSpecific.h"

NSString *XADInvalidPrefixCodeException=@"XADInvalidPrefixCodeException";

@implementation XADPrefixCode

static inline int *NodePointer(XADPrefixCode *self,int node) { return self->tree[node]; }

static inline int NewNode(XADPrefixCode *self)
{
	self->tree=reallocf(self->tree,(self->numentries+1)*sizeof(int)*2);
	NodePointer(self,self->numentries)[0]=-1;
	NodePointer(self,self->numentries)[1]=-2;
	return self->numentries++;
}

static inline BOOL IsEmptyNode(XADPrefixCode *self,int node) { return NodePointer(self,node)[0]==-1&&NodePointer(self,node)[1]==-2; }

static inline int Branch(XADPrefixCode *self,int node,int bit) { return NodePointer(self,node)[bit]; }
static inline BOOL IsOpenBranch(XADPrefixCode *self,int node,int bit) { return NodePointer(self,node)[bit]<0; }
static inline void SetBranch(XADPrefixCode *self,int node,int bit,int nextnode) { NodePointer(self,node)[bit]=nextnode; }

static inline int LeafValue(XADPrefixCode *self,int node) { return NodePointer(self,node)[0]; }
static inline BOOL IsLeafNode(XADPrefixCode *self,int node) { return NodePointer(self,node)[0]==NodePointer(self,node)[1]; }
static inline void SetLeafValue(XADPrefixCode *self,int node,int value) { NodePointer(self,node)[0]=NodePointer(self,node)[1]=value; }


int CSInputNextSymbolUsingCode(CSInputBuffer *buf,XADPrefixCode *code)
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
}



+(XADPrefixCode *)prefixCode { return [[self new] autorelease]; }

+(XADPrefixCode *)prefixCodeWithLengths:(const int *)lengths numberOfSymbols:(int)numsymbols
maximumLength:(int)maxlength shortestCodeIsZeros:(BOOL)zeros
{
	return [[[self alloc] initWithLengths:lengths numberOfSymbols:numsymbols
	maximumLength:maxlength shortestCodeIsZeros:zeros] autorelease];
}

-(id)init
{
	if(self=[super init])
	{
		tree=malloc(sizeof(int)*2);
		tree[0][0]=-1;
		tree[0][1]=-2;
		numentries=1;
		isstatic=NO;
		stack=nil;

		for(int i=0;i<sizeof(tables)/sizeof(tables[0]);i++) tables[i]=NULL;
	}
	return self;
}

-(id)initWithStaticTable:(int (*)[2])statictable
{
	if(self=[super init])
	{
		tree=statictable;
		isstatic=YES;

		for(int i=0;i<sizeof(tables)/sizeof(tables[0]);i++) tables[i]=NULL;
	}
	return self;
}

-(id)initWithLengths:(const int *)lengths numberOfSymbols:(int)numsymbols
maximumLength:(int)maxlength shortestCodeIsZeros:(BOOL)zeros
{
	if(self=[self init])
	{
//NSLog(@"--------");
//for(int i=0;i<numsymbols;i++) NSLog(@"%d",lengths[i]);

		@try
		{
			int code=0,symbolsleft=numsymbols;

			for(int length=1;length<=maxlength;length++)
			for(int i=0;i<numsymbols;i++)
			{
				if(lengths[i]!=length) continue;
				// Instead of reversing to get a low-bit-first code, we shift and use high-bit-first.
				if(zeros) [self addValue:i forCodeWithHighBitFirst:code>>32-length length:length];
				else [self addValue:i forCodeWithHighBitFirst:~code>>32-length length:length];
				code+=1<<32-length;
				if(--symbolsleft==0) return self; // early exit if all codes have been handled
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

//NSLog(@"%d -> %x %d",value,code,length);

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

@end

