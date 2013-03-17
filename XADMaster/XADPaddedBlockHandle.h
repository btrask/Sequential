#import "CSHandle.h"


@interface XADPaddedBlockHandle:CSHandle
{
	CSHandle *parent;
	off_t startoffset;
	int logicalsize,physicalsize;
}

-(id)initWithHandle:(CSHandle *)handle startOffset:(off_t)start
logicalBlockSize:(int)logical physicalBlockSize:(int)physical;
-(void)dealloc;

-(off_t)fileSize;
-(off_t)offsetInFile;
-(BOOL)atEndOfFile;

-(void)seekToFileOffset:(off_t)offs;
-(void)seekToEndOfFile;
-(int)readAtMost:(int)num toBuffer:(void *)buffer;

@end
