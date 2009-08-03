#import "XADLZMAAloneParser.h"
#import "XADLZMAHandle.h"

@implementation XADLZMAAloneParser

+(int)requiredHeaderSize { return 13; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	// Geez, put some magic bytes in your file formats, people!

	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<13) return NO;

	if(bytes[0]>=9*5*5) return NO;

	uint32_t dictsize=CSUInt32LE(&bytes[1]);
	uint32_t div3=dictsize*0xaaaaaaab; // Multiplicative inverse of three
	if((dictsize&dictsize-1)!=0 && (div3&div3-1)!=0) return NO;

	if(!(bytes[11]==0x00&&bytes[12]==0x00)&&!(bytes[11]==0xff&&bytes[12]==0xff)) return NO;

	return YES;

//	if([name rangeOfString:@".lzma" options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound) return YES;
//	if([name rangeOfString:@".tlz" options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound) return YES;
//	return NO;
}

-(void)parse
{
	CSHandle *handle=[self handle];

	NSString *name=[self name];
	NSString *extension=[[name pathExtension] lowercaseString];
	NSString *contentname;
	if([extension isEqual:@"tlz"]) contentname=[[name stringByDeletingPathExtension] stringByAppendingPathExtension:@"tar"];
	else contentname=[name stringByDeletingPathExtension];

	NSData *props=[handle readDataOfLength:5];

	// TODO: set no filename flag
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithUnseparatedString:contentname],XADFileNameKey,
		[self XADStringWithString:@"LZMA"],XADCompressionNameKey,
		props,@"LZMAProperties",
	nil];

	if([contentname matchedByPattern:@"\\.(tar|cpio)$" options:REG_ICASE])
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	uint64_t size=[handle readUInt64LE];
	if(size!=0xffffffffffffffff)
	[dict setObject:[NSNumber numberWithUnsignedLongLong:size] forKey:XADFileSizeKey];

	off_t filesize=[[self handle] fileSize];
	if(filesize!=CSHandleMaxLength)
	[dict setObject:[NSNumber numberWithUnsignedLongLong:filesize-13] forKey:XADCompressedSizeKey];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	NSNumber *size=[dictionary objectForKey:XADFileSizeKey];
	[handle seekToFileOffset:13];

	if(size) return [[[XADLZMAHandle alloc] initWithHandle:handle length:[size unsignedLongLongValue]
	propertyData:[dictionary objectForKey:@"LZMAProperties"]] autorelease];
	else return [[[XADLZMAHandle alloc] initWithHandle:handle
	propertyData:[dictionary objectForKey:@"LZMAProperties"]] autorelease];

}

-(NSString *)formatName { return @"LZMA_Alone"; }

@end
