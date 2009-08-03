#import "CSByteStreamHandle.h"

@interface XADStuffItRLEHandle:CSByteStreamHandle
{
	int byte,count;
}

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
