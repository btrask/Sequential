#import "XADSqueezeParser.h"
#import "XADSqueezeHandle.h"
#import "XADRLE90Handle.h"
#import "XADChecksumHandle.h"
#import "NSDateXAD.h"

@implementation XADSqueezeParser

+(NSMutableDictionary *)parseWithHandle:(CSHandle *)fh endOffset:(off_t)end parser:(XADArchiveParser *)parser
{
	int magic1=[fh readUInt8];
	if(magic1!=0x76) return nil;

	int magic2=[fh readUInt8];
	if(magic2!=0xff) return nil;

	int sum=[fh readUInt16LE];

	NSMutableData *data=[NSMutableData data];
	uint8_t byte;
	while((byte=[fh readUInt8])) [data appendBytes:&byte length:1];

	off_t dataoffset=[fh offsetInFile];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[parser XADPathWithData:data separators:XADNoPathSeparator],XADFileNameKey,
		[parser XADStringWithString:@"Squeeze"],XADCompressionNameKey,
		[NSNumber numberWithUnsignedLongLong:dataoffset],XADDataOffsetKey,
		[NSNumber numberWithInt:sum],@"SqueezeChecksum",
	nil];

	[fh seekToFileOffset:end-8];

	int marker=[fh readUInt16LE];
	if(marker==0xff77)
	{
		// TODO: Test this.
		int date=[fh readUInt16LE];
		int time=[fh readUInt16LE];
		[dict setObject:[NSDate XADDateWithMSDOSDate:date time:time] forKey:XADLastModificationDateKey];

		NSNumber *compsize=[NSNumber numberWithLongLong:end-dataoffset-8];
		[dict setObject:compsize forKey:XADCompressedSizeKey];
		[dict setObject:compsize forKey:XADDataLengthKey];
	}
	else
	{
		NSNumber *compsize=[NSNumber numberWithLongLong:end-dataoffset];
		[dict setObject:compsize forKey:XADCompressedSizeKey];
		[dict setObject:compsize forKey:XADDataLengthKey];
	}

	return dict;
}

+(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum handle:(CSHandle *)handle
{
	int sum=[[dict objectForKey:@"SqueezeChecksum"] intValue];

	handle=[[[XADSqueezeHandle alloc] initWithHandle:handle] autorelease];
	handle=[[[XADRLE90Handle alloc] initWithHandle:handle] autorelease];

	if(checksum) handle=[[[XADChecksumHandle alloc] initWithHandle:handle
	length:CSHandleMaxLength correctChecksum:sum mask:0xffff] autorelease];

	return handle;
}




+(int)requiredHeaderSize { return 1024; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<5) return NO;

	if(bytes[0]!=0x76||bytes[1]!=0xff) return NO;

	if(bytes[4]==0) return NO;
	for(int i=4;i<length;i++)
	{
		if(bytes[i]==0)
		{
			return YES;
		}
		if(bytes[i]<32) return NO;
	}

	return NO;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	NSMutableDictionary *dict=[XADSqueezeParser parseWithHandle:fh
	endOffset:[fh fileSize] parser:self];

	XADPath *filename=[dict objectForKey:XADFileNameKey];
	NSData *namedata=[filename data];
	const char *bytes=[namedata bytes];
	int length=[namedata length];

	if(length>4)
	if(bytes[length-4]=='.')
	if(tolower(bytes[length-3])=='l')
	if(tolower(bytes[length-2])=='b')
	if(tolower(bytes[length-1])=='r')
	{
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];
	}

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	return [XADSqueezeParser handleForEntryWithDictionary:dict wantChecksum:checksum handle:handle];
}

-(NSString *)formatName { return @"Squeeze"; }

@end




