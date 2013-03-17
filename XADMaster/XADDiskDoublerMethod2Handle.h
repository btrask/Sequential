#import "CSByteStreamHandle.h"

@interface XADDiskDoublerMethod2Handle:CSByteStreamHandle
{
	int numtrees,currtree;

	struct
	{
		uint8_t parents[512];
		uint16_t leftchildren[256];
		uint16_t rightchildren[256];
	} trees[256];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length numberOfTrees:(int)num;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

-(void)updateStateForByte:(int)byte;

@end
