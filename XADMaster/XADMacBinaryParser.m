#import "XADMacBinaryParser.h"

@implementation XADMacBinaryParser

+(int)requiredHeaderSize
{
	return 128;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	return [XADMacArchiveParser macBinaryVersionForHeader:data]>0;
}

-(void)parseWithSeparateMacForks
{
	[self setIsMacArchive:YES];

	[properties removeObjectForKey:XADDisableMacForkExpansionKey];
	[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES],XADIsMacBinaryKey,
	nil]];
}

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self handle];
}

-(void)inspectEntryDictionary:(NSMutableDictionary *)dict
{
	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];
	if(rsrc&&[rsrc boolValue]) return;

	if([[self name] matchedByPattern:@"\\.sea(\\.|$)" options:REG_ICASE]||
	[[[dict objectForKey:XADFileNameKey] string] matchedByPattern:@"\\.(sea|sit|cpt)$" options:REG_ICASE])
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	// TODO: Better detection of embedded archives. Also applies to BinHex!
//	if([[dict objectForKey:XADFileTypeKey] unsignedIntValue]=='APPL')...
}

-(NSString *)formatName
{
	return @"MacBinary";
}

@end
