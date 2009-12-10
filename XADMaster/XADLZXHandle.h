#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADLZXHandle:XADLZSSHandle
{
	XADPrefixCode *maincode,*offsetcode;

	int blocktype,lastoffs;
	off_t blockend;
	int mainlengths[768];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

-(void)readBlockHeaderAtPosition:(off_t)pos;
-(void)readDeltaLengths:(int *)lengths count:(int)count alternateMode:(BOOL)altmode;

@end


@interface XADLZXSwapHandle:CSByteStreamHandle
{
	uint8_t otherbyte;
}

-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
