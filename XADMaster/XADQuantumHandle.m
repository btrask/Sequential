#import "XADQuantumHandle.h"
#import "XADException.h"



static void InitQuantumCoder(QuantumCoder *self,CSInputBuffer *input);
static uint16_t GetQuantumFrequency(QuantumCoder *self,uint16_t totfreq);
static void RemoveQuantumCode(QuantumCoder *self,int cumfreqm1,int cumfreq,int totfreq);
static int NextQuantumSymbolForModel(QuantumCoder *self,QuantumModel *model);
static void InitQuantumModel(QuantumModel *self,int numsymbols);
static void UpdateQuantumModel(QuantumModel *model,int index);




@implementation XADQuantumHandle

-(id)initWithBlockReader:(XADCABBlockReader *)blockreader windowBits:(int)windowbits
{
	if(self=[super initWithBlockReader:blockreader])
	{
		[self setInputBuffer:CSInputBufferAllocEmpty()];

		InitializeLZSS(&lzss,1<<windowbits);

		numslots6=windowbits*2;

		if(numslots6>36) numslots5=36;
		else numslots5=numslots6;

		if(numslots6>24) numslots4=24;
		else numslots4=numslots6;
	}
	return self;
}

-(void)dealloc
{
	CleanupLZSS(&lzss);
	[super dealloc];
}

-(void)resetCABBlockHandle
{
	InitQuantumModel(&selectormodel,7);

	for(int i=0;i<4;i++) InitQuantumModel(&literalmodel[i],64);

	InitQuantumModel(&offsetmodel4,numslots4);
	InitQuantumModel(&offsetmodel5,numslots5);
	InitQuantumModel(&offsetmodel6,numslots6);

	InitQuantumModel(&lengthmodel6,27);

	RestartLZSS(&lzss);
}

-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)complength atOffset:(off_t)pos length:(int)uncomplength
{
	static int OffsetBaseTable[]=
	{
		0x00000,0x00001,0x00002,0x00003,0x00004,0x00006,0x00008,0x0000c,
		0x00010,0x00018,0x00020,0x00030,0x00040,0x00060,0x00080,0x000c0,
		0x00100,0x00180,0x00200,0x00300,0x00400,0x00600,0x00800,0x00c00,
		0x01000,0x01800,0x02000,0x03000,0x04000,0x06000,0x08000,0x0c000,
		0x10000,0x18000,0x20000,0x30000,0x40000,0x60000,0x80000,0xc0000,
		0x100000,0x180000
	};
	static int OffsetAdditionalBitsTable[]=
	{
		0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,
		11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19
	};

	static int LengthBaseTable[]=
	{
		0x00,0x01,0x02,0x03,0x04,0x05,0x06,0x08,0x0a,0x0c,0x0e,0x12,
		0x16,0x1a,0x1e,0x26,0x2e,0x36,0x3e,0x4e,0x5e,0x6e,0x7e,0x9e,
		0xbe,0xde,0xfe
	};

	static int LengthAdditionalBitsTable[] =
	{
		0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5,0
	};

	CSInputSetMemoryBuffer(input,buffer,complength,0);
	InitQuantumCoder(&coder,input);

//	int dicpos=pos&dictionarymask;
	int end=LZSSPosition(&lzss)+uncomplength;

	[self setBlockPointer:CurrentLZSSWindowPointer(&lzss)];

	while(LZSSPosition(&lzss)<end)
	{
		int selector=NextQuantumSymbolForModel(&coder,&selectormodel);
		if(selector<4)
		{
			EmitLZSSLiteral(&lzss,NextQuantumSymbolForModel(&coder,&literalmodel[selector])+selector*64);
		}
		else
		{
			int offset,length;
			if(selector==4)
			{
				length=3;

				int offsetslot=NextQuantumSymbolForModel(&coder,&offsetmodel4);
				offset=OffsetBaseTable[offsetslot]+
				CSInputNextBitString(input,OffsetAdditionalBitsTable[offsetslot])+1;
			}
			else if(selector==5)
			{
				length=4;

				int offsetslot=NextQuantumSymbolForModel(&coder,&offsetmodel5);
				offset=OffsetBaseTable[offsetslot]+
				CSInputNextBitString(input,OffsetAdditionalBitsTable[offsetslot])+1;
			}
			else if(selector==6)
			{
				int lengthslot=NextQuantumSymbolForModel(&coder,&lengthmodel6);
				length=LengthBaseTable[lengthslot]+
				CSInputNextBitString(input,LengthAdditionalBitsTable[lengthslot])+5;

				int offsetslot=NextQuantumSymbolForModel(&coder,&offsetmodel6);
				offset=OffsetBaseTable[offsetslot]+
				CSInputNextBitString(input,OffsetAdditionalBitsTable[offsetslot])+1;
			}

			EmitLZSSMatch(&lzss,offset,length);
		}
	}
	return uncomplength;
}

@end





static void InitQuantumCoder(QuantumCoder *self,CSInputBuffer *input)
{
	self->CS_L=0;
	self->CS_H=0xffff;
	self->CS_C=CSInputNextBitString(input,16);
	self->input=input;
}

static uint16_t GetQuantumFrequency(QuantumCoder *self,uint16_t totfreq)
{
	uint32_t range=((self->CS_H-self->CS_L)&0xffff)+1;
	uint32_t freq=((self->CS_C-self->CS_L+1)*totfreq-1)/range;
	return freq&0xffff;
}

static void RemoveQuantumCode(QuantumCoder *self,int cumfreqm1,int cumfreq,int totfreq)
{
	uint32_t range=(self->CS_H-self->CS_L) + 1;
	self->CS_H=self->CS_L+((cumfreqm1*range)/totfreq)-1;
	self->CS_L=self->CS_L+(cumfreq*range)/totfreq;

	for(;;)
	{
		if((self->CS_L&0x8000)!=(self->CS_H&0x8000))
		{
			if((self->CS_L&0x4000)&&!(self->CS_H&0x4000))
			{
				self->CS_C^=0x4000;
				self->CS_L&=0x3fff;
				self->CS_H|=0x4000;
			}
			else return;
		}
		self->CS_L<<=1;
		self->CS_H=(self->CS_H<<1)|1;
		self->CS_C=(self->CS_C<<1)|CSInputNextBit(self->input);
	}
}

static int NextQuantumSymbolForModel(QuantumCoder *self,QuantumModel *model)
{
	int freq=GetQuantumFrequency(self,model->symbols[0].cumfreq);

	int i;
	for(i=1;i<model->numsymbols;i++)
	{
		if(model->symbols[i].cumfreq<=freq) break;
	}

	int symbol=model->symbols[i-1].symbol;

	RemoveQuantumCode(self,model->symbols[i-1].cumfreq,
	model->symbols[i].cumfreq,model->symbols[0].cumfreq);

	UpdateQuantumModel(model,i);

	return symbol;
}

static void InitQuantumModel(QuantumModel *self,int numsymbols)
{
	self->numsymbols=numsymbols;
	self->shiftsleft=4;
	for(int i=0;i<numsymbols;i++)
	{
		self->symbols[i].symbol=i;
		self->symbols[i].cumfreq=numsymbols-i;
	}
	self->symbols[numsymbols].cumfreq=0;
}

static void UpdateQuantumModel(QuantumModel *self,int index)
{
	for(int i=0;i<index;i++) self->symbols[i].cumfreq+=8;

	if(self->symbols[0].cumfreq<=3800) return;

	self->shiftsleft--;
	if(self->shiftsleft)
	{
		for(int i=self->numsymbols-1;i>=0;i--)
		{
			self->symbols[i].cumfreq>>=1;

			if(self->symbols[i].cumfreq<=self->symbols[i+1].cumfreq)
			self->symbols[i].cumfreq=self->symbols[i+1].cumfreq+1;
		}
	}
	else
	{
		self->shiftsleft=50;
		for(int i=0;i<self->numsymbols;i++)
		{
			self->symbols[i].cumfreq-=self->symbols[i+1].cumfreq;
			self->symbols[i].cumfreq++;
			self->symbols[i].cumfreq>>=1;
		}

		for(int i=0;i<self->numsymbols-1;i++)
		{
			for(int j=i+1;j<self->numsymbols;j++)
			{
				if(self->symbols[i].cumfreq<self->symbols[j].cumfreq)
				{
					QuantumModelSymbol temp=self->symbols[i];
					self->symbols[i]=self->symbols[j];
					self->symbols[j]=temp;
				}
			}
		}

		for(int i=self->numsymbols-1;i>=0;i--)
		self->symbols[i].cumfreq+=self->symbols[i+1].cumfreq;
	}
}

