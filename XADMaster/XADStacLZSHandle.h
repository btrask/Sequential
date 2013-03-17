#import "XADFastLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADStacLZSHandle:XADFastLZSSHandle
{
	XADPrefixCode *lengthcode;
	int extralength,extraoffset;
}

-(id)initWithHandle:(CSHandle *)handle;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(void)expandFromPosition:(off_t)pos;

@end
