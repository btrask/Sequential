#import "XADChecksumHandle.h"

@implementation XADChecksumHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctChecksum:(int)correct mask:(int)mask
{
	if((self=[super initWithName:[handle name] length:length]))
	{
		parent=[handle retain];
		correctchecksum=correct;
		summask=mask;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}

-(void)resetStream
{
	[parent seekToFileOffset:0];
	checksum=0;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];

	uint8_t *bytes=buffer;
	for(int i=0;i<actual;i++) checksum+=bytes[i];

	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	return (checksum&summask)==(correctchecksum&summask);
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end

