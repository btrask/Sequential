#ifndef __PPMD_SUB_ALLOCATOR_BRIMSTONE_H__
#define __PPMD_SUB_ALLOCATOR_BRIMSTONE_H__

#include "SubAllocator.h"

typedef struct PPMdSubAllocatorBrimstone
{
	PPMdSubAllocator core;

	uint32_t SubAllocatorSize;
	uint8_t Index2Units[38],Units2Index[128];
	uint8_t *LowUnit,*HighUnit;
	struct PPMAllocatorNodeBrimstone { struct PPMAllocatorNodeBrimstone *next; } FreeList[38];
	uint8_t HeapStart[0];
} PPMdSubAllocatorBrimstone;

PPMdSubAllocatorBrimstone *CreateSubAllocatorBrimstone(int size);
void FreeSubAllocatorBrimstone(PPMdSubAllocatorBrimstone *self);

#endif
