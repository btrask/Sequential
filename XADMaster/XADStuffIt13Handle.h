#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADStuffIt13Handle:XADLZSSHandle
{
	XADPrefixCode *firstcode,*secondcode,*offsetcode;
	XADPrefixCode *currcode;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(XADPrefixCode *)allocAndParseCodeOfSize:(int)numcodes metaCode:(XADPrefixCode *)metacode;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

@end
