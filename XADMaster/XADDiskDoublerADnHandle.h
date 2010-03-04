#import "CSBlockStreamHandle.h"

@interface XADDiskDoublerADnHandle:CSBlockStreamHandle
{
	uint8_t outbuffer[8192];
}

-(int)produceBlockAtOffset:(off_t)pos;

@end
