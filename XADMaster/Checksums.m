#import "Checksums.h"




@implementation CSHandle (Checksums)

-(BOOL)hasChecksum { return NO; }
-(BOOL)isChecksumCorrect { return YES; }

@end




@implementation CSSubHandle (Checksums)

-(BOOL)hasChecksum
{
	off_t length=[parent fileSize];
	if(length==CSHandleMaxLength) return NO;

	return end==length&&[parent hasChecksum];
}

-(BOOL)isChecksumCorrect { return [parent isChecksumCorrect]; }

@end




@implementation CSStreamHandle (Checksums)

-(BOOL)hasChecksum
{
	if(input) return [CSInputHandle(input) hasChecksum];
	else return NO;
}

-(BOOL)isChecksumCorrect
{
	if(input) return [CSInputHandle(input) isChecksumCorrect];
	else return YES;
}

@end




@implementation CSChecksumWrapperHandle

-(id)initWithHandle:(CSHandle *)handle checksumHandle:(CSHandle *)checksumhandle
{
	if((self=[super initWithName:[handle name]]))
	{
		parent=[handle retain];
		checksum=[checksumhandle retain];
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[checksum release];
	[super dealloc];
}

-(off_t)fileSize { return [parent fileSize]; }
-(off_t)offsetInFile { return [parent offsetInFile]; }
-(BOOL)atEndOfFile { return [parent atEndOfFile]; }
-(void)seekToFileOffset:(off_t)offs { [parent seekToFileOffset:offs]; }
-(void)seekToEndOfFile { [parent seekToEndOfFile]; }
-(void)pushBackByte:(int)byte { [parent pushBackByte:byte]; }
-(int)readAtMost:(int)num toBuffer:(void *)buffer { return [parent readAtMost:num toBuffer:buffer]; }
-(void)writeBytes:(int)num fromBuffer:(const void *)buffer { [parent writeBytes:num fromBuffer:buffer]; }

-(BOOL)hasChecksum { return [checksum hasChecksum]; }
-(BOOL)isChecksumCorrect { return [checksum isChecksumCorrect]; }

@end
