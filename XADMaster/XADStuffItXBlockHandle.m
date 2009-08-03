#import "XADStuffItXBlockHandle.h"
#import "StuffItXUtilities.h"
#import "SystemSpecific.h"

@implementation XADStuffItXBlockHandle

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		startoffs=[parent offsetInFile];
		buffer=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(buffer);
	[parent release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
}

-(int)produceBlockAtOffset:(off_t)pos
{
	int size=ReadSitxP2(parent);
	if(!size) return -1;

	buffer=reallocf(buffer,size);
	[self setBlockPointer:buffer];

	return [parent readAtMost:size toBuffer:buffer];
}

@end
