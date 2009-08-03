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
