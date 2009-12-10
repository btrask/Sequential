#import "XADXZParser.h"
#import "XADXZHandle.h"

@implementation XADXZParser

+(int)requiredHeaderSize { return 6; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<6) return NO;

//	return bytes[0]==0xff&&bytes[1]=='L'&&bytes[2]=='Z'&&bytes[3]=='M'&&bytes[4]=='A'&&bytes[5]==0;
	return bytes[0]==0xfd&&bytes[1]=='7'&&bytes[2]=='z'&&bytes[3]=='X'&&bytes[4]=='Z'&&bytes[5]==0;
}

-(void)parse
{
	NSString *name=[self name];
	NSString *extension=[[name pathExtension] lowercaseString];
	NSString *contentname;
	if([extension isEqual:@"txz"]) contentname=[[name stringByDeletingPathExtension] stringByAppendingPathExtension:@"tar"];
	else contentname=[name stringByDeletingPathExtension];

	// TODO: set no filename flag
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithUnseparatedString:contentname],XADFileNameKey,
		[self XADStringWithString:@"LZMA2"],XADCompressionNameKey,
	nil];

	if([contentname matchedByPattern:@"\\.(tar|cpio)$" options:REG_ICASE])
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	off_t filesize=[[self handle] fileSize];
	if(filesize!=CSHandleMaxLength)
	[dict setObject:[NSNumber numberWithUnsignedLongLong:filesize] forKey:XADCompressedSizeKey];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	[handle seekToFileOffset:0];
	return [[[XADXZHandle alloc] initWithHandle:handle] autorelease];
}

-(NSString *)formatName { return @"XZ"; }

@end


