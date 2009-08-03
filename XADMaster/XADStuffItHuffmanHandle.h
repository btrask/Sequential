#import "CSByteStreamHandle.h"
#import "XADPrefixCode.h"

@interface XADStuffItHuffmanHandle:CSByteStreamHandle
{
	XADPrefixCode *code;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetByteStream;
-(void)parseTree;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
