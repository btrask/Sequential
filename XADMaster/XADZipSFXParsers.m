#import "XADZipSFXParsers.h"

@implementation XADZipSFXParser

+(int)requiredHeaderSize { return 0x10000; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<12) return NO;
	if(bytes[0]!=0x4d||bytes[1]!=0x5a) return NO;

	for(int i=2;i<length-9;i++)
	{
		if(bytes[i]=='P'&&bytes[i+1]=='K'&&bytes[i+2]==3&&bytes[i+3]==4)
		if(bytes[i+4]>=10&&bytes[i+4]<40&&!bytes[i+9]) return YES;
    }

	return NO;
}

-(NSString *)formatName { return @"Self-extracting Zip"; }

@end



@implementation XADWinZipSFXParser

+(int)requiredHeaderSize { return 20480; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<26) return NO;
	if(bytes[0]!=0x4d||bytes[1]!=0x5a) return NO;

	for(int i=2;i<length-24;++i)
	{
		if(memcmp(bytes+i,"WinZip(R) Self-Extractor",24)==0) return YES;
	}

	return NO;
}

-(NSString *)formatName { return @"WinZip Self-Extractor"; }

@end



@implementation XADZipItSEAParser

+(int)requiredHeaderSize { return 4; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<4) return NO;
	if(CSUInt32BE(bytes)=='Joy!') return YES;

	return NO;
}

-(void)parse
{
	[super parse];
}

-(NSString *)formatName { return @"ZipIt SEA"; }

@end
