#import "CSByteStreamHandle.h"

@interface XAD7ZipDeltaHandle:CSByteStreamHandle
{
	uint8_t deltabuffer[256];
	int distance;
}

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
