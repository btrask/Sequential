#import "CSStreamHandle.h"

@interface XADStuffItXBlendHandle:CSStreamHandle
{
	CSHandle *parent;
	CSHandle *currhandle;
	CSInputBuffer *currinput;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

@end
