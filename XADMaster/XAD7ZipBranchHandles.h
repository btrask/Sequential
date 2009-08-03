#import "CSBlockStreamHandle.h"

@interface XAD7ZipBranchHandle:CSBlockStreamHandle
{
	CSHandle *parent;
	off_t startoffs;
	uint8_t inbuffer[4096];
	int leftoverstart,leftoverlength;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos;

@end

@interface XAD7ZipBCJHandle:XAD7ZipBranchHandle { uint32_t state; }
@end

@interface XAD7ZipPPCHandle:XAD7ZipBranchHandle {}
@end

@interface XAD7ZipIA64Handle:XAD7ZipBranchHandle {}
@end

@interface XAD7ZipARMHandle:XAD7ZipBranchHandle {}
@end

@interface XAD7ZipThumbHandle:XAD7ZipBranchHandle {}
@end

@interface XAD7ZipSPARCHandle:XAD7ZipBranchHandle {}
@end
