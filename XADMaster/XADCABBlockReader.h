#import "CSHandle.h"

@interface XADCABBlockReader:NSObject
{
	CSHandle *parent;
	int extbytes;

	int numfolders;
	off_t offsets[100];
	int numblocks[100];

	int currentfolder,currentblock;

	off_t complen,uncomplen;
}

-(id)initWithHandle:(CSHandle *)handle reservedBytes:(int)reserved;
-(void)dealloc;

-(void)addFolderAtOffset:(off_t)startoffs numberOfBlocks:(int)numblocks;
-(void)scanLengths;

-(CSHandle *)handle;
-(off_t)compressedLength;
-(off_t)uncompressedLength;

-(void)restart;
-(BOOL)readNextBlockToBuffer:(uint8_t *)buffer compressedLength:(int *)compptr
uncompressedLength:(int *)uncompptr;

@end
