#import "XADLibXADIOHandle.h"

// Implementation using the old xadIO code from libxad, emulated through XADLibXADIOHandle
// TODO: Re-implement these as cleaner code. Problem: no test cases.

@interface XADStuffItMWHandle:XADLibXADIOHandle {}
-(xadINT32)unpackData;
@end

@interface XADStuffIt14Handle:XADLibXADIOHandle {}
-(xadINT32)unpackData;
@end

