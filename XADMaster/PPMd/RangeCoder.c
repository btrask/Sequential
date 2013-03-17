#include "RangeCoder.h"

void InitializePPMdRangeCoder(PPMdRangeCoder *self,
PPMdReadFunction *readfunc,void *inputcontext,
bool uselow,int bottom)
{
	self->readfunc=readfunc;
	self->inputcontext=inputcontext;
	self->low=0;
	self->code=0;
	self->range=0xffffffff;
	self->uselow=uselow;
	self->bottom=bottom;
	for(int i=0;i<4;i++) self->code=(self->code<<8)|readfunc(inputcontext);
}

uint32_t PPMdRangeCoderCurrentCount(PPMdRangeCoder *self,uint32_t scale)
{
	self->range/=scale;
	return (self->code-self->low)/self->range;
}

void RemovePPMdRangeCoderSubRange(PPMdRangeCoder *self,uint32_t lowcount,uint32_t highcount)
{
	if(self->uselow) self->low+=self->range*lowcount;
	else self->code-=self->range*lowcount;

	self->range*=highcount-lowcount;

	NormalizePPMdRangeCoder(self);
}

int NextWeightedBitFromPPMdRangeCoder(PPMdRangeCoder *self,int weight,int size)
{
	uint32_t val=PPMdRangeCoderCurrentCount(self,size);

	if(val<weight)
	{
		RemovePPMdRangeCoderSubRange(self,0,weight);
		return 0;
	}
	else
	{
		RemovePPMdRangeCoderSubRange(self,weight,size);
		return 1;
	}
}

int NextWeightedBitFromPPMdRangeCoder2(PPMdRangeCoder *self,int weight,int shift)
{
	uint32_t threshold=(self->range>>shift)*weight;

	int bit;
	if(self->code<threshold) // <= ?
	{
		bit=0;
		self->range=threshold;
	}
	else
	{
		bit=1;
		self->range-=threshold;
		self->code-=threshold;
	}

	NormalizePPMdRangeCoder(self);

	return bit;
}


void NormalizePPMdRangeCoder(PPMdRangeCoder *self)
{
	for(;;)
	{
		if( (self->low^(self->low+self->range))>=0x1000000 )
		{
			if(self->range>=self->bottom) break;
			else self->range=-self->low&(self->bottom-1);
		}

		int byte=self->readfunc(self->inputcontext);
		self->code=(self->code<<8)|byte;
		self->range<<=8;
		self->low<<=8;
	}
}
