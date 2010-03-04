#import <XADMaster/XADArchiveParser.h>
#import <XADMaster/CRC.h>

@interface TestDelegate:NSObject
@end

@implementation TestDelegate

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	NSLog(@"%@",dict);

	CSHandle *fh=[parser handleForEntryWithDictionary:dict wantChecksum:YES];

	NSData *data=[fh remainingFileContents];
/*
//	if(![dict objectForKey:XADIsResourceForkKey])
	if([[[dict objectForKey:XADCompressionNameKey] string] isEqual:@"LZMA+BCJ"])
	{
		NSMutableString *name=[NSMutableString stringWithString:[[dict objectForKey:XADFileNameKey] string]];
		[name replaceOccurrencesOfString:@"/" withString:@"_" options:0 range:NSMakeRange(0,[name length])];
		[data writeToFile:name atomically:YES];
	}
*/

	uint32_t crc=0;
	uint8_t xor=0;

	const uint8_t *bytes=[data bytes];
	int length=[data length];
	if(bytes)
	{
		crc=XADCalculateCRC(0xffffffff,bytes,length,XADCRCTable_edb88320)^0xffffffff;
		for(int i=0;i<length;i++) xor^=bytes[i];
	}

	NSLog(@"Checksum: %@, Length: %d, CRC32: %08x, XOR: %02x",
	[fh hasChecksum]?[fh isChecksumCorrect]?@"Correct":@"Incorrect":@"Unknown",
	[data length],crc,xor);

	NSLog(@"\n%@",[data subdataWithRange:NSMakeRange(0,[data length]<256?[data length]:256)]);
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return NO;
}

@end

int main(int argc,char **argv)
{
	for(int i=1;i<argc;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		NSString *filename=[NSString stringWithUTF8String:argv[i]];
		XADArchiveParser *parser=[XADArchiveParser archiveParserForPath:filename];

		NSLog(@"Parsing file \"%@\" with parser \"%@\".",filename,[parser formatName]);

		[parser setDelegate:[[TestDelegate new] autorelease]];

		char *pass=getenv("XADTestPassword");
		if(pass) [parser setPassword:[NSString stringWithUTF8String:pass]];

		[parser parse];
		NSLog(@"Archive format: \"%@\", properties: %@",[parser formatName],[parser properties]);

		[pool release];
	}
	return 0;
}
