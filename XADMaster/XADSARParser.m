#import "XADSARParser.h"
#import "XADRegex.h"

@implementation XADSARParser

+(int)requiredHeaderSize { return 6; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	if(!name) return NO;
	if(![[name lastPathComponent] matchedByPattern:@"^arc[0-9]*\\.sar$" options:REG_ICASE]) return NO;

	//const uint8_t *bytes=[data bytes];
	//int length=[data length];

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	int numfiles=[fh readUInt16BE];
	if(numfiles==0) numfiles=[fh readUInt16BE];

	uint32_t offset=[fh readUInt32BE];

	for(int i=0;i<numfiles && [self shouldKeepParsing];i++)
	{
		NSMutableData *namedata=[NSMutableData data];
		uint8_t c;
		while((c=[fh readUInt8])) [namedata appendBytes:&c length:1];

		uint32_t dataoffs=[fh readUInt32BE];
		uint32_t datalen=[fh readUInt32BE];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[self XADPathWithData:namedata separators:XADWindowsPathSeparator],XADFileNameKey,
			[NSNumber numberWithUnsignedLong:datalen],XADFileSizeKey,
			[NSNumber numberWithUnsignedLong:datalen],XADCompressedSizeKey,
			[NSNumber numberWithUnsignedLong:datalen],XADDataLengthKey,
			[NSNumber numberWithUnsignedLong:dataoffs+offset],XADDataOffsetKey,
			[self XADStringWithString:@"None"],XADCompressionNameKey,
		nil];

		[self addEntryWithDictionary:dict retainPosition:YES];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self handleAtDataOffsetForDictionary:dict];
}

-(NSString *)formatName { return @"SAR"; }

@end
