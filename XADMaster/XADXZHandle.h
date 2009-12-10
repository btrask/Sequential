#import "CSStreamHandle.h"

@interface XADXZHandle:CSStreamHandle
{
	CSHandle *parent,*currhandle;
	off_t startoffs;
	int state;
	BOOL checksumscorrect;
	int checksumflags;
	uint64_t crc;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;
-(double)estimatedProgress;

@end
