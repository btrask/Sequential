#import "XAD7ZipBCJ2Handle.h"

#define NumTopBits 24
#define TopValue (1<<NumTopBits)

#define BitModelTotalBits 11
#define BitModelTotal (1<<BitModelTotalBits)
#define NumMoveBits 5


@implementation XAD7ZipBCJ2Handle

static inline BOOL IsJ(int b0,int b1)
{
	if((b1&0xfe)==0xe8) return YES;
	if(b0==0x0f&&(b1&0xf0)==0x80) return YES;
	return NO;
}

static inline int NextRangeBit(XAD7ZipBCJ2Handle *self,uint16_t *prob)
{
	int res;
	uint32_t bound=(self->range>>BitModelTotalBits)**prob;
	if(self->code<bound)
	{
		res=0;
		self->range=bound;
		*prob=*prob+((BitModelTotal-*prob)>>NumMoveBits);
	}
	else
	{
		res=1;
		self->range-=bound;
		self->code-=bound;
		*prob=*prob-(*prob>>NumMoveBits);
	}

	// Normalize
	if(self->range<TopValue)
	{
		self->range<<=8;
		self->code=(self->code<<8)|[self->ranges readUInt8];
	}

	return res;
}

-(id)initWithHandle:(CSHandle *)handle callHandle:(CSHandle *)callhandle
jumpHandle:(CSHandle *)jumphandle rangeHandle:(CSHandle *)rangehandle length:(off_t)length
{
	if((self=[super initWithHandle:handle length:length]))
	{
		calls=[callhandle retain];
		jumps=[jumphandle retain];
		ranges=[rangehandle retain];
		callstart=[calls offsetInFile];
		jumpstart=[jumps offsetInFile];
		rangestart=[ranges offsetInFile];
	}
	return self;
}

-(void)dealloc
{
	[calls release];
	[jumps release];
	[ranges release];
	[super dealloc];
}

-(void)resetByteStream
{
	[calls seekToFileOffset:callstart];
	[jumps seekToFileOffset:jumpstart];
	[ranges seekToFileOffset:rangestart];

	code=0;
	range=0xffffffff;
	for(int i=0;i<5;i++) code=(code<<8)|[ranges readUInt8];
	for(int i=0;i<258;i++) probabilities[i]=BitModelTotal/2;

	prevbyte=0;
	valbyte=4;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(valbyte<4)
	{
		prevbyte=(val>>valbyte*8)&0xff;
		valbyte++;
		return prevbyte;
	}

	uint8_t b=CSInputNextByte(input);

	if(IsJ(prevbyte,b))
	{
		uint16_t *prob;
		if(b==0xe8) prob=&probabilities[prevbyte];
		else if (b==0xe9) prob=&probabilities[256];
		else prob=&probabilities[257];

		if(NextRangeBit(self,prob)==1)
		{
			CSHandle *handle;
			if(b==0xe8) handle=calls;
			else handle=jumps;

			val=[handle readUInt32BE]-(pos+5);
			valbyte=0;
		}
	}

	return prevbyte=b;
}

@end

