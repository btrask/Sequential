#include "SubAllocatorBrimstone.h"

#include <stdlib.h>
#include <string.h>

#define N1 4
#define N2 4
#define N3 4
#define N4 ((128+3-1*N1-2*N2-3*N3)/4)
#define UNIT_SIZE 12
#define N_INDEXES (N1+N2+N3+N4)

static void InsertNode(PPMdSubAllocatorBrimstone *self,void *p,int index);
static void *RemoveNode(PPMdSubAllocatorBrimstone *self,int index);
static unsigned int I2B(PPMdSubAllocatorBrimstone *self,int index);
static void SplitBlock(PPMdSubAllocatorBrimstone *self,void *pv,int oldindex,int newindex);
static uint32_t GetUsedMemory(PPMdSubAllocatorBrimstone *self);

static void InitBrimstone(PPMdSubAllocatorBrimstone *self);
static uint32_t AllocContextBrimstone(PPMdSubAllocatorBrimstone *self);
static uint32_t AllocUnitsBrimstone(PPMdSubAllocatorBrimstone *self,int num);
static uint32_t ExpandUnitsBrimstone(PPMdSubAllocatorBrimstone *self,uint32_t oldoffs,int oldnum);
static uint32_t ShrinkUnitsBrimstone(PPMdSubAllocatorBrimstone *self,uint32_t oldoffs,int oldnum,int newnum);
static void FreeUnitsBrimstone(PPMdSubAllocatorBrimstone *self,uint32_t offs,int num);




PPMdSubAllocatorBrimstone *CreateSubAllocatorBrimstone(int size)
{
	PPMdSubAllocatorBrimstone *self=malloc(sizeof(PPMdSubAllocatorBrimstone)+size);
	if(!self) return NULL;

	self->core.Init=(void *)InitBrimstone;
	self->core.AllocContext=(void *)AllocContextBrimstone;
	self->core.AllocUnits=(void *)AllocUnitsBrimstone;
	self->core.ExpandUnits=(void *)ExpandUnitsBrimstone;
	self->core.ShrinkUnits=(void *)ShrinkUnitsBrimstone;
	self->core.FreeUnits=(void *)FreeUnitsBrimstone;

    self->SubAllocatorSize=size;

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

	return self;
}

void FreeSubAllocatorBrimstone(PPMdSubAllocatorBrimstone *self)
{
	free(self);
}



static void InitBrimstone(PPMdSubAllocatorBrimstone *self)
{
	memset(self->FreeList,0,sizeof(self->FreeList));

	self->LowUnit=self->HeapStart;
	self->HighUnit=self->HeapStart+UNIT_SIZE*(self->SubAllocatorSize/UNIT_SIZE);
}

static uint32_t AllocContextBrimstone(PPMdSubAllocatorBrimstone *self)
{
    if(self->HighUnit>self->LowUnit)
	{
		self->HighUnit-=UNIT_SIZE;
		return PointerToOffset(self,self->HighUnit);
	}

    return AllocUnitsBrimstone(self,1);
}

static uint32_t AllocUnitsBrimstone(PPMdSubAllocatorBrimstone *self,int num)
{
	int index=self->Units2Index[num-1];
	if(self->FreeList[index].next) return PointerToOffset(self,RemoveNode(self,index));

	void *units=self->LowUnit;
	self->LowUnit+=I2B(self,index);
	if(self->LowUnit<=self->HighUnit) return PointerToOffset(self,units);

	self->LowUnit-=I2B(self,index);

	for(int i=index+1;i<N_INDEXES;i++)
	{
		if(self->FreeList[i].next)
		{
			void *units=RemoveNode(self,i);
			SplitBlock(self,units,i,index);
			return PointerToOffset(self,units);
		}
	}

	return 0;
}

static uint32_t ExpandUnitsBrimstone(PPMdSubAllocatorBrimstone *self,uint32_t oldoffs,int oldnum)
{
	void *oldptr=OffsetToPointer(self,oldoffs);
	int oldindex=self->Units2Index[oldnum-1];
	int newindex=self->Units2Index[oldnum];
	if(oldindex==newindex) return oldoffs;

	uint32_t offs=AllocUnitsBrimstone(self,oldnum+1);
	if(offs)
	{
		// TODO: could copy less data
		memcpy(OffsetToPointer(self,offs),oldptr,I2B(self,oldindex));
		InsertNode(self,oldptr,oldindex);
	}
	return offs;
}

static uint32_t ShrinkUnitsBrimstone(PPMdSubAllocatorBrimstone *self,uint32_t oldoffs,int oldnum,int newnum)
{
	void *oldptr=OffsetToPointer(self,oldoffs);
	int oldindex=self->Units2Index[oldnum-1];
	int newindex=self->Units2Index[newnum-1];
	if(oldindex==newindex) return oldoffs;

	if(self->FreeList[newindex].next)
	{
		void *ptr=RemoveNode(self,newindex);
		memcpy(ptr,oldptr,I2B(self,newindex));
		InsertNode(self,oldptr,oldindex);
		return PointerToOffset(self,ptr);
	}
	else
	{
		SplitBlock(self,oldptr,oldindex,newindex);
		return oldoffs;
    }
}

static void FreeUnitsBrimstone(PPMdSubAllocatorBrimstone *self,uint32_t offs,int num)
{
	InsertNode(self,OffsetToPointer(self,offs),self->Units2Index[num-1]);
}




static void InsertNode(PPMdSubAllocatorBrimstone *self,void *p,int index)
{
	((struct PPMAllocatorNodeBrimstone *)p)->next=self->FreeList[index].next;
	self->FreeList[index].next=p;
}

static void *RemoveNode(PPMdSubAllocatorBrimstone *self,int index)
{
	struct PPMAllocatorNodeBrimstone *node=self->FreeList[index].next;
	self->FreeList[index].next=node->next;
	return node;
}

static unsigned int I2B(PPMdSubAllocatorBrimstone *self,int index) { return UNIT_SIZE*self->Index2Units[index]; }

static void SplitBlock(PPMdSubAllocatorBrimstone *self,void *pv,int oldindex,int newindex)
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
