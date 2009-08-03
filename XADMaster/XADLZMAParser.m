#import "XADLZMAParser.h"
#import "XADLZMAHandle.h"

// TODO: Implement this somewhat insane format

@implementation XADLZMAParser

+(int)requiredHeaderSize { return 6; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<6) return NO;

	return bytes[0]==0xff&&bytes[1]=='L'&&bytes[2]=='Z'&&bytes[3]=='M'&&bytes[4]=='A'&&bytes[5]==0;
}

-(void)parse
{
//	CSHandle *handle=[self handle];

	[XADException raiseNotSupportedException];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary wantChecksum:(BOOL)checksum
{
	return nil;
}

-(NSString *)formatName { return @"LZMA"; }

@end
