#import "XADPPMdParser.h"
#import "XADPPMdHandles.h"
#import "NSDateXAD.h"

#import "XADCRCHandle.h"

@implementation XADPPMdParser

+(int)requiredHeaderSize { return 16; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<16) return NO;

	if(bytes[0]==0x84&&bytes[1]==0xac&&bytes[2]==0xaf&&bytes[3]==0x8f) return YES;
	if(bytes[3]==0x84&&bytes[2]==0xac&&bytes[1]==0xaf&&bytes[0]==0x8f) return YES;
	return NO;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	uint32_t signature=[fh readID];

	BOOL bigendian;
	if(signature==0x84acaf8f) bigendian=YES;
	else bigendian=NO;

	uint32_t attrib;
	int info,namelen,time,date;

	if(bigendian)
	{
		attrib=[fh readUInt32BE];
		info=[fh readUInt16BE];
		namelen=[fh readUInt16BE];
		time=[fh readUInt16BE];
		date=[fh readUInt16BE];
	}
	else
	{
		attrib=[fh readUInt32LE];
		info=[fh readUInt16LE];
		namelen=[fh readUInt16LE];
		time=[fh readUInt16LE];
		date=[fh readUInt16LE];
	}

	int maxorder=(info&0x0f)+1;
	int suballocsize=((info>>4)&0xff)+1;
	int variant=(info>>12)+'A';

	int modelrestoration;
	if(variant>='I')
	{
		modelrestoration=namelen>>14;
		namelen&=0x3fff;
	}
	else modelrestoration=-1;

	NSData *filename=[fh readDataOfLength:namelen];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		// TODO: Should this really be XADEitherPathSeparator?
		[self XADPathWithData:filename separators:XADEitherPathSeparator],XADFileNameKey,
		[self XADStringWithString:[NSString stringWithFormat:@"PPMd Variant %c",variant]],XADCompressionNameKey,
		[NSNumber numberWithUnsignedLongLong:[fh offsetInFile]],XADDataOffsetKey,
		[NSNumber numberWithInt:maxorder],@"PPMdMaxOrder",
		[NSNumber numberWithInt:variant],@"PPMdVariant",
		[NSNumber numberWithInt:suballocsize],@"PPMdSubAllocSize",
	nil];

	if(modelrestoration>=0)
	[dict setObject:[NSNumber numberWithInt:modelrestoration] forKey:@"PPMdModelRestoration"];

	if(date&0xc000) // assume that the next highest bit is always set in unix dates and never in DOS (true until 2011)
	{
		[dict setObject:[NSDate dateWithTimeIntervalSince1970:(date<<16)|time] forKey:XADLastModificationDateKey];
		[dict setObject:[NSNumber numberWithInt:attrib] forKey:XADPosixPermissionsKey];
	}
	else
	{
		[dict setObject:[NSDate XADDateWithMSDOSDateTime:(date<<16)|time] forKey:XADLastModificationDateKey];
		[dict setObject:[NSNumber numberWithInt:attrib] forKey:XADWindowsFileAttributesKey];
	}

	off_t filesize=[fh fileSize];
	if(filesize!=CSHandleMaxLength)
	[dict setObject:[NSNumber numberWithUnsignedLongLong:filesize-16-namelen] forKey:XADCompressedSizeKey];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];

	int variant=[[dict objectForKey:@"PPMdVariant"] intValue];
	int maxorder=[[dict objectForKey:@"PPMdMaxOrder"] intValue];
	int suballocsize=[[dict objectForKey:@"PPMdSubAllocSize"] intValue];

	switch(variant)
	{
		case 'G':
			return [XADCRCHandle IEEECRC32HandleWithHandle:
			[[[XADPPMdVariantGHandle alloc] initWithHandle:handle maxOrder:maxorder subAllocSize:suballocsize<<20] autorelease]
			length:13745624 correctCRC:0xc1c1c00a conditioned:YES];

		case 'H':
			return [XADCRCHandle IEEECRC32HandleWithHandle:
			[[[XADPPMdVariantHHandle alloc] initWithHandle:handle maxOrder:maxorder subAllocSize:suballocsize<<20] autorelease]
//			length:20259 correctCRC:0xb4e8f7a1 conditioned:YES];
			length:13745624 correctCRC:0xc1c1c00a conditioned:YES];

		case 'I':
			return [XADCRCHandle IEEECRC32HandleWithHandle:
			[[[XADPPMdVariantIHandle alloc] initWithHandle:handle maxOrder:maxorder subAllocSize:suballocsize<<20
			modelRestorationMethod:[[dict objectForKey:@"PPMdModelRestoration"] intValue]] autorelease]
//			length:8559 correctCRC:0xb193cc7d conditioned:YES];
			length:13745624 correctCRC:0xc1c1c00a conditioned:YES];

		default: return nil;
	}
}

-(NSString *)formatName { return @"PPMd"; }

@end
