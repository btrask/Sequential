#import "PPMdSubAllocatorVariantG.h"

#include <stdlib.h>
#include <string.h>

#define N1 4
#define N2 4
#define N3 4
#define N4 ((128+3-1*N1-2*N2-3*N3)/4)
#define UNIT_SIZE 12
#define N_INDEXES (N1+N2+N3+N4)

static void InsertNode(PPMdSubAllocatorVariantG *self,void *p,int index);
static void *RemoveNode(PPMdSubAllocatorVariantG *self,int index);
static unsigned int I2B(PPMdSubAllocatorVariantG *self,int index);
static void SplitBlock(PPMdSubAllocatorVariantG *self,void *pv,int oldindex,int newindex);
static uint32_t GetUsedMemory(PPMdSubAllocatorVariantG *self);

static void InitVariantG(PPMdSubAllocatorVariantG *self);
static uint32_t AllocContextVariantG(PPMdSubAllocatorVariantG *self);
static uint32_t AllocUnitsVariantG(PPMdSubAllocatorVariantG *self,int num);
static uint32_t ExpandUnitsVariantG(PPMdSubAllocatorVariantG *self,uint32_t oldoffs,int oldnum);
static uint32_t ShrinkUnitsVariantG(PPMdSubAllocatorVariantG *self,uint32_t oldoffs,int oldnum,int newnum);
static void FreeUnitsVariantG(PPMdSubAllocatorVariantG *self,uint32_t offs,int num);

static inline void *_OffsetToPointer(PPMdSubAllocatorVariantG *self,uint32_t offset) { return ((uint8_t *)self)+offset; }
static inline uint32_t _PointerToOffset(PPMdSubAllocatorVariantG *self,void *pointer) { return ((uintptr_t)pointer)-(uintptr_t)self; }




PPMdSubAllocatorVariantG *CreateSubAllocatorVariantG(int size)
{
	PPMdSubAllocatorVariantG *self=malloc(sizeof(PPMdSubAllocatorVariantG)+size);
	if(!self) return NULL;

	self->core.Init=(void *)InitVariantG;
	self->core.AllocContext=(void *)AllocContextVariantG;
	self->core.AllocUnits=(void *)AllocUnitsVariantG;
	self->core.ExpandUnits=(void *)ExpandUnitsVariantG;
	self->core.ShrinkUnits=(void *)ShrinkUnitsVariantG;
	self->core.FreeUnits=(void *)FreeUnitsVariantG;

    self->SubAllocatorSize=size;

	return self;
}

void FreeSubAllocatorVariantG(PPMdSubAllocatorVariantG *self)
{
	free(self);
}



static void InitVariantG(PPMdSubAllocatorVariantG *self)
{
	memset(self->FreeList,0,sizeof(self->FreeList));

	self->LowUnit=self->HeapStart;
	self->HighUnit=self->HeapStart+UNIT_SIZE*(self->SubAllocatorSize/UNIT_SIZE);
	self->LastBreath=self->LowUnit;
	self->LowUnit+=128*128*UNIT_SIZE;

	for(int i=0;i<N1;i++) self->Index2Units[i]=1+i;
    for(int i=0;i<N2;i++) self->Index2Units[N1+i]=2+N1+i*2;
    for(int i=0;i<N3;i++) self->Index2Units[N1+N2+i]=3+N1+2*N2+i*3;
	for(int i=0;i<N4;i++) self->Index2Units[N1+N2+N3+i]=4+N1+2*N2+3*N3+i*4;

	int i=0;
    for(int k=0;k<128;k++)
	{
        if(self->Index2Units[i]<k+1) i++;
		self->Units2Index[k]=i;
    }
}

static uint32_t AllocContextVariantG(PPMdSubAllocatorVariantG *self)
{
    if(self->HighUnit!=self->LowUnit)
	{
		self->HighUnit-=UNIT_SIZE;
		return _PointerToOffset(self,self->HighUnit);
	}

    return AllocUnitsVariantG(self,1);
}

static uint32_t AllocUnitsVariantG(PPMdSubAllocatorVariantG *self,int num)
{
	int index=self->Units2Index[num-1];
	if(self->FreeList[index].next) return _PointerToOffset(self,RemoveNode(self,index));

	void *units=self->LowUnit;
	self->LowUnit+=I2B(self,index);
	if(self->LowUnit<=self->HighUnit) return _PointerToOffset(self,units);

	if(self->LastBreath)
	{
		uint8_t *ptr=self->LastBreath;
		for(int i=0;i<128;i++)
		{
			InsertNode(self,ptr,N_INDEXES-1);
			ptr+=128*UNIT_SIZE;
		}
		self->LastBreath=NULL;
	}

	self->LowUnit-=I2B(self,index);

	for(int i=index+1;i<N_INDEXES;i++)
	{
		if(self->FreeList[i].next)
		{
			void *units=RemoveNode(self,i);
			SplitBlock(self,units,i,index);
			return _PointerToOffset(self,units);
		}
	}

	return 0;
}

static uint32_t ExpandUnitsVariantG(PPMdSubAllocatorVariantG *self,uint32_t oldoffs,int oldnum)
{
	void *oldptr=_OffsetToPointer(self,oldoffs);
	int oldindex=self->Units2Index[oldnum-1];
	int newindex=self->Units2Index[oldnum];
	if(oldindex==newindex) return oldoffs;

	uint32_t offs=AllocUnitsVariantG(self,oldnum+1);
	if(offs)
	{
		memcpy(_OffsetToPointer(self,offs),oldptr,I2B(self,oldindex));
		InsertNode(self,oldptr,oldindex);
	}
	return offs;
}

static uint32_t ShrinkUnitsVariantG(PPMdSubAllocatorVariantG *self,uint32_t oldoffs,int oldnum,int newnum)
{
	void *oldptr=_OffsetToPointer(self,oldoffs);
	int oldindex=self->Units2Index[oldnum-1];
	int newindex=self->Units2Index[newnum-1];
	if(oldindex==newindex) return oldoffs;

	if(self->FreeList[newindex].next)
	{
		void *ptr=RemoveNode(self,newindex);
		memcpy(ptr,oldptr,I2B(self,newindex));
		InsertNode(self,oldptr,oldindex);
		return _PointerToOffset(self,ptr);
	}
	else
	{
		SplitBlock(self,oldptr,oldindex,newindex);
		return oldoffs;
    }
}

static void FreeUnitsVariantG(PPMdSubAllocatorVariantG *self,uint32_t offs,int num)
{
	InsertNode(self,_OffsetToPointer(self,offs),self->Units2Index[num-1]);
}




static void InsertNode(PPMdSubAllocatorVariantG *self,void *p,int index)
{
	((struct PPMAllocatorNodeVariantG *)p)->next=self->FreeList[index].next;
	self->FreeList[index].next=p;
}

static void *RemoveNode(PPMdSubAllocatorVariantG *self,int index)
{
	struct PPMAllocatorNodeVariantG *node=self->FreeList[index].next;
	self->FreeList[index].next=node->next;
	return node;
}

static unsigned int I2B(PPMdSubAllocatorVariantG *self,int index) { return UNIT_SIZE*self->Index2Units[index]; }

static void SplitBlock(PPMdSubAllocatorVariantG *self,void *pv,int oldindex,int newindex)
{
	uint8_t *p=((uint8_t *)pv)+I2B(self,newindex);

	int diff=self->Index2Units[oldindex]-self->Index2Units[newindex];
	int i=self->Units2Index[diff-1];
	if(self->Index2Units[i]!=diff)
	{
		InsertNode(self,p,i-1);
		p+=I2B(self,i-1);
        diff-=self->Index2Units[i-1];
    }

    InsertNode(self,p,self->Units2Index[diff-1]);
}
