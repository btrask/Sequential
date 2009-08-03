#import "XADCompressParser.h"
#import "XADCompressHandle.h"


@implementation XADCompressParser

+(int)requiredHeaderSize { return 3; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	return length>=3&&bytes[0]==0x1f&&bytes[1]==0x9d;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:2];
	int flags=[fh readUInt8];

	NSString *name=[[self name] stringByDeletingPathExtension];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithUnseparatedString:name],XADFileNameKey,
		[self XADStringWithString:@"Compress"],XADCompressionNameKey,
		[NSNumber numberWithLongLong:3],XADDataOffsetKey,
		[NSNumber numberWithInt:flags],@"CompressFlags",
	nil];

	if([name matchedByPattern:@"\\.(tar|cpio)" options:REG_ICASE])
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	off_t size=[[self handle] fileSize];
	if(size!=CSHandleMaxLength)
	[dict setObject:[NSNumber numberWithLongLong:size-3] forKey:XADCompressedSizeKey];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [[[XADCompressHandle alloc] initWithHandle:[self handleAtDataOffsetForDictionary:dict]
	flags:[[dict objectForKey:@"CompressFlags"] intValue]] autorelease];
}

-(NSString *)formatName { return @"Compress"; }

@end
