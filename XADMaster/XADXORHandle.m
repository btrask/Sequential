#import "XADXORHandle.h"

@implementation XADXORHandle

-(id)initWithHandle:(CSHandle *)handle password:(NSData *)passdata
{
	if((self=[super initWithName:[handle name]]))
	{
		parent=[handle retain];
		password=[passdata retain];
		passwordbytes=[password bytes];
		passwordlength=[password length];
	}
	return self;
}

-(id)initAsCopyOf:(XADXORHandle *)other
{
	[self _raiseNotSupported:_cmd];
	return nil;
}

-(void)dealloc
{
	[parent release];
	[password release];
	[super dealloc];
}



-(off_t)fileSize { return [parent fileSize]; }

-(off_t)offsetInFile { return [parent offsetInFile]; }

-(BOOL)atEndOfFile { return [parent atEndOfFile]; }

-(void)seekToFileOffset:(off_t)offs { [parent seekToFileOffset:offs]; }

-(void)seekToEndOfFile { [parent seekToEndOfFile]; }

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	off_t pos=[parent offsetInFile];
	int actual=[parent readAtMost:num toBuffer:buffer];

	if(passwordlength)
	{
		uint8_t *buf=(uint8_t *)buffer;
		for(int i=0;i<actual;i++) buf[i]^=passwordbytes[(pos+i)%passwordlength];
	}

	return actual;
}

@end
