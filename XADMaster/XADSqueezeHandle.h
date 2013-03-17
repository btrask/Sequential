#import "CSByteStreamHandle.h"
#import "XADPrefixCode.h"

@interface XADSqueezeHandle:CSByteStreamHandle
{
	XADPrefixCode *code;
}

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
