#import "XADSkipHandle.h"
#import "SystemSpecific.h"

@implementation XADSkipHandle

static off_t ActualStart(XADSkipHandle *self,int index)
{
	return self->regions[index].actual;
}

static off_t ActualGapStart(XADSkipHandle *self,int index)
{
	if(index>=self->numregions-1) return CSHandleMaxLength;
	return self->regions[index].actual+self->regions[index+1].skip-self->regions[index].skip;
}

static off_t ActualEnd(XADSkipHandle *self,int index)
{
	if(index>=self->numregions-1) return CSHandleMaxLength;
	return self->regions[index+1].actual;
}

static off_t SkipStart(XADSkipHandle *self,int index)
{
	return self->regions[index].skip;
}

static off_t SkipEnd(XADSkipHandle *self,int index)
{
	if(index>=self->numregions-1) return CSHandleMaxLength;
	return self->regions[index+1].skip;
}

static int FindIndexOfRegionContainingActualOffset(XADSkipHandle *self,off_t pos)
{
	int first=0,last=self->numregions-1;

	if(ActualStart(self,last)<=pos) return last;
	if(ActualEnd(self,first)>pos) return first;

	while(last-first>1)
	{
		int mid=(last+first)/2;
		if(ActualStart(self,mid)<=pos)
		{
			if(ActualEnd(self,mid)>pos) return mid;
			first=mid;
		}
		else last=mid;
	}
	return first;
}

static int FindIndexOfRegionContainingSkipOffset(XADSkipHandle *self,off_t pos)
{
	int first=0,last=self->numregions-1;

	if(SkipStart(self,last)<=pos) return last;
	if(SkipEnd(self,first)>pos) return first;

	while(last-first>1)
	{
		int mid=(last+first)/2;
		if(SkipStart(self,mid)<=pos)
		{
			if(SkipEnd(self,mid)>pos) return mid;
			first=mid;
		}
		else last=mid;
	}
	return first;
}

static off_t SkipOffsetToActual(XADSkipHandle *self,off_t pos)
{
	int index=FindIndexOfRegionContainingSkipOffset(self,pos);
	return pos+ActualStart(self,index)-SkipStart(self,index);
}

static off_t ActualOffsetToSkip(XADSkipHandle *self,off_t pos)
{
	int index=FindIndexOfRegionContainingActualOffset(self,pos);

	// Skip ahead to next region if position is in the gap between regions
	if(pos>=ActualGapStart(self,index)) return SkipStart(self,index+1);

	return pos-ActualStart(self,index)+SkipStart(self,index);
}



-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		regions=malloc(sizeof(XADSkipRegion));
		regions[0].actual=regions[0].skip=0;
		numregions=1;
	}
	return self;
}

-(id)initAsCopyOf:(XADSkipHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		parent=[other->parent copy];
		numregions=other->numregions;
		regions=malloc(sizeof(XADSkipRegion)*numregions);
		memcpy(regions,other->regions,sizeof(XADSkipRegion)*numregions);
	}
	return self;
}

-(void)dealloc
{
	free(regions);
	[parent release];
	[super dealloc];
}



-(void)addSkipFrom:(off_t)start length:(off_t)length
{
	[self addSkipFrom:start length:start+length];
}

-(void)addSkipFrom:(off_t)start to:(off_t)end
{
	int index=FindIndexOfRegionContainingActualOffset(self,start);

	// TODO: merge regions instead of bailing out
	if(end>=ActualGapStart(self,index)) [NSException raise:NSInvalidArgumentException format:@"Attempted to add overlapping or neighbouring skips"];

	regions=reallocf(regions,sizeof(XADSkipRegion)*(numregions+1));

	for(int i=numregions-1;i>index;i++)
	{
		regions[i+1].actual=regions[i].actual;
		regions[i+1].skip=regions[i].skip-end+start;
	}

	regions[index+1].actual=end;
	regions[index+1].skip=regions[index].skip+start-regions[index].actual;

	numregions++;
}

-(off_t)actualOffsetForSkipOffset:(off_t)skipoffset { return SkipOffsetToActual(self,skipoffset); }

-(off_t)skipOffsetForActualOffset:(off_t)actualoffset { return ActualOffsetToSkip(self,actualoffset); }



-(off_t)fileSize
{
	off_t size=[parent fileSize];
	if(size==CSHandleMaxLength) return CSHandleMaxLength;
	return ActualOffsetToSkip(self,size-1)+1;
}

-(off_t)offsetInFile
{
	off_t offs=[parent offsetInFile];
	return ActualOffsetToSkip(self,offs);
}

-(BOOL)atEndOfFile
{
	return [super atEndOfFile];
	// TODO: handle skips at EOF
}

-(void)seekToFileOffset:(off_t)offs
{
	[parent seekToFileOffset:SkipOffsetToActual(self,offs)];
}

-(void)seekToEndOfFile
{
	[parent seekToEndOfFile];
	// TODO: handle skips at EOF
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	off_t pos=[parent offsetInFile];
	int index=FindIndexOfRegionContainingActualOffset(self,pos);
	if(pos>=ActualGapStart(self,index)) [parent seekToFileOffset:pos=ActualStart(self,++index)];

	off_t total=0;
	for(;;)
	{
		off_t gap=ActualGapStart(self,index);

		if(num-total<gap-pos)
		{
			total+=[parent readAtMost:num-total toBuffer:buffer+total];
			return total;
		}

		int actual=[parent readAtMost:gap-pos toBuffer:buffer+total];
		total+=actual;

		if(actual!=gap-pos) return total;

		[parent seekToFileOffset:pos=ActualStart(self,++index)];
	}
}

@end
