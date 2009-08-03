#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADCompactProLZHHandle:XADLZSSHandle
{
	XADPrefixCode *literalcode,*lengthcode,*offsetcode;
	int blocksize,blockcount;
	off_t blockstart;
}

-(id)initWithHandle:(CSHandle *)handle blockSize:(int)blocklen;
-(void)dealloc;

-(void)resetLZSSHandle;
-(XADPrefixCode *)allocAndParseCodeOfSize:(int)size;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

@end
