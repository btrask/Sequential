#import "CSStreamHandle.h";
#import "Checksums.h"
#import "Progress.h"

@interface XADChecksumHandle:CSStreamHandle
{
	CSHandle *parent;
	uint32_t correctchecksum,summask,checksum;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length correctChecksum:(int)correct mask:(int)mask;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end
