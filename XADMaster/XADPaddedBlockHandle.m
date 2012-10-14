#import "XADPaddedBlockHandle.h"

@implementation XADPaddedBlockHandle

-(id)initWithHandle:(CSHandle *)handle startOffset:(off_t)start
logicalBlockSize:(int)logical physicalBlockSize:(int)physical;
{
	if((self=[super initWithName:[handle name]]))
	{
		parent=[handle retain];
		startoffset=start;
		logicalsize=logical;
		physicalsize=physical;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}


static inline off_t PhysicalToLogical(XADPaddedBlockHandle *self,off_t physical)
{
	off_t block=(physical-self->startoffset)/self->physicalsize;
	int offset=(physical-self->startoffset)%self->physicalsize;
	if(offset>self->logicalsize) physical-=offset-self->logicalsize;
	return physical-self->startoffset-block*(self->physicalsize-self->logicalsize);
}

static inline off_t LogicalToPhysical(XADPaddedBlockHandle *self,off_t logical)
{
	off_t block=logical/self->logicalsize;
	return logical+self->startoffset+block*(self->physicalsize-self->logicalsize);
}

-(off_t)fileSize
{
	off_t size=[parent fileSize];
	if(size==CSHandleMaxLength) return CSHandleMaxLength;
	return PhysicalToLogical(self,size);
}

-(off_t)offsetInFile
{
	return PhysicalToLogical(self,[parent offsetInFile]);
}

-(BOOL)atEndOfFile
{
	return [parent atEndOfFile];
}

-(void)seekToFileOffset:(off_t)offs
{
	if(offs<0) [self _raiseEOF];

	[parent seekToFileOffset:LogicalToPhysical(self,offs)];
}

-(void)seekToEndOfFile
{
	[parent seekToEndOfFile];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(!num) return 0;

	uint8_t *bytebuffer=(uint8_t *)buffer;
	off_t pos=[parent offsetInFile];
	int total=0;

	while(total<num)
	{
		int offset=(pos-startoffset)%physicalsize;
		if(offset>=logicalsize)
		{
			pos+=physicalsize-offset;
			offset=0;
			[parent seekToFileOffset:pos];
		}

		int numbytes=logicalsize-offset;
		if(numbytes>num-total) numbytes=num-total;

		int actual=[parent readAtMost:numbytes toBuffer:&bytebuffer[total]];
		if(actual==0) return total;

		total+=actual;
		pos+=actual;
	}

	return total;
}

@end
