#import "XADCABBlockHandle.h"

@interface XADMSZipHandle:XADCABBlockHandle
{
	uint8_t outbuffer[32768];
	int lastlength;
}

-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength;

@end
