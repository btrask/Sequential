#import "XADCRCSuffixHandle.h"

@implementation XADCRCSuffixHandle

+(XADCRCSuffixHandle *)IEEECRC32SuffixHandleWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle
bigEndianCRC:(BOOL)bigendian conditioned:(BOOL)conditioned
{
	if(conditioned) return [[[self alloc] initWithHandle:handle CRCHandle:crchandle initialCRC:0xffffffff
	CRCSize:4 bigEndianCRC:bigendian CRCTable:XADCRCTable_edb88320] autorelease];
	else return [[[self alloc] initWithHandle:handle CRCHandle:crchandle initialCRC:0
	CRCSize:4 bigEndianCRC:bigendian CRCTable:XADCRCTable_edb88320] autorelease];
}

+(XADCRCSuffixHandle *)CCITTCRC16SuffixHandleWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle
bigEndianCRC:(BOOL)bigendian conditioned:(BOOL)conditioned
{
	// Evil trick: negating the big endian flag does the same thing as XADUnReverseCRC16()
	if(conditioned) return [[[self alloc] initWithHandle:handle CRCHandle:crchandle initialCRC:0xffff
	CRCSize:2 bigEndianCRC:!bigendian  CRCTable:XADCRCReverseTable_1021] autorelease];
	else return [[[self alloc] initWithHandle:handle CRCHandle:crchandle initialCRC:0
	CRCSize:2 bigEndianCRC:!bigendian CRCTable:XADCRCReverseTable_1021] autorelease];
}

-(id)initWithHandle:(CSHandle *)handle CRCHandle:(CSHandle *)crchandle initialCRC:(uint32_t)initialcrc
CRCSize:(int)crcbytes bigEndianCRC:(BOOL)bigendian CRCTable:(const uint32_t *)crctable
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		crcparent=[crchandle retain];
		crcsize=crcbytes;
		bigend=bigendian;
		crc=initcrc=initialcrc;
		table=crctable;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}

-(void)resetStream
{
	[parent seekToFileOffset:0];
	crc=initcrc;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];
	crc=XADCalculateCRC(crc,buffer,actual,table);
	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	if([parent hasChecksum]&&![parent isChecksumCorrect]) return NO;
	if(![parent atEndOfFile]) return NO; 

	if(crcparent)
	{
		@try {
NSLog(@"? %x",crc^initcrc);
			if(bigend&&crcsize==2) compcrc=[crcparent readUInt16BE];
			else if(bigend&&crcsize==4) compcrc=[crcparent readUInt32BE];
			else if(!bigend&&crcsize==2) compcrc=[crcparent readUInt16LE];
			else if(!bigend&&crcsize==4) compcrc=[crcparent readUInt32LE];
NSLog(@"??? %x",compcrc);
		} @catch(id e) { compcrc=(crc+1)^initcrc; NSLog(@"what");} // make sure check fails if reading failed
		[crcparent release];
		crcparent=nil;
	}
NSLog(@"%x %x",crc^initcrc,compcrc);
	return (crc^initcrc)==compcrc;
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end


