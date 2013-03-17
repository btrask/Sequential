#import "XADLibXADIOHandle.h"

// Implementation using the old xadIO code from libxad, emulated through XADLibXADIOHandle
// TODO: Re-implement these as cleaner code. Problem: no test cases.

@interface XADCrunchZHandle:XADLibXADIOHandle
{
	BOOL oldversion,haschecksum,checksumcorrect;
}

-(id)initWithHandle:(CSHandle *)handle old:(BOOL)old hasChecksum:(BOOL)checksum;
-(xadINT32)unpackData;

@end

@interface XADCrunchYHandle:XADLibXADIOHandle
{
	BOOL oldversion,haschecksum,checksumcorrect;
}

-(id)initWithHandle:(CSHandle *)handle old:(BOOL)old hasChecksum:(BOOL)checksum;
-(xadINT32)unpackData;

@end
