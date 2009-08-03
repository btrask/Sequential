#import "CSByteStreamHandle.h"


@interface XADCompactProRLEHandle:CSByteStreamHandle
{
	int saved,repeat;
	BOOL halfescaped;
}

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
