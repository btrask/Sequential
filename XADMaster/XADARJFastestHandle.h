#import "XADLZSSHandle.h"

@interface XADARJFastestHandle:XADLZSSHandle
{
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

@end
