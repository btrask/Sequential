#import "UniversalDetector.h"
#import "WrappedUniversalDetector.h"

@implementation UniversalDetector

+(UniversalDetector *)detector
{
	return [[self new] autorelease];
}

-(id)init
{
	if(self=[super init])
	{
		detector=AllocUniversalDetector();
		charset=nil;
	}
	return self;
}

-(void)dealloc
{
	FreeUniversalDetector(detector);
	[charset release];
	[super dealloc];
}

-(void)analyzeData:(NSData *)data
{
	[self analyzeBytes:(const char *)[data bytes] length:[data length]];
}

-(void)analyzeBytes:(const char *)data length:(int)len
{
	UniversalDetectorHandleData(detector,data,len);
	[charset release];
	charset=nil;
}

-(void)reset { UniversalDetectorReset(detector); }

-(BOOL)done { return UniversalDetectorDone(detector); }

/*
The possible return values of -[UniversalDetector MIMECharset] should be as follows:

@"UTF-8",@"UTF-16BE",@"UTF-16LE",@"UTF-32BE",@"UTF-32LE",
@"ISO-8859-2",@"ISO-8859-5",@"ISO-8859-7",@"ISO-8859-8",@"ISO-8859-8-I",
@"windows-1250",@"windows-1251",@"windows-1252",@"windows-1253",@"windows-1255",
@"KOI8-R",@"Shift_JIS",@"EUC-JP",@"EUC-KR"/ * actually CP949 * /, @"x-euc-tw",
@"ISO-2022-JP",@"ISO-2022-CN",@"ISO-2022-KR",
@"Big5",@"GB2312",@"HZ-GB-2312",@"gb18030",@"GB18030",
@"IBM855",@"IBM866",@"TIS-620",@"X-ISO-10646-UCS-4-2143",@"X-ISO-10646-UCS-4-3412",
@"x-mac-cyrillic",@"x-mac-hebrew",
*/

-(NSString *)MIMECharset
{
	if(!charset)
	{
		const char *cstr=UniversalDetectorCharset(detector,&confidence);
		if(!cstr) return nil;

		// nsUniversalDetector detects CP949 but returns "EUC-KR" because CP949
		// lacks an IANA name. Kludge the name to make sure decoding succeeds.
		if(strcmp(cstr,"EUC-KR")==0) cstr="CP949";

		charset=[[NSString alloc] initWithUTF8String:cstr];
	}
	return charset;
}

-(float)confidence
{
	if(!charset) [self MIMECharset];
	return confidence;
}

#ifdef __APPLE__
-(NSStringEncoding)encoding
{
	NSString *mimecharset=[self MIMECharset];
	if(!mimecharset) return 0;

	CFStringEncoding cfenc=CFStringConvertIANACharSetNameToEncoding((CFStringRef)mimecharset);
	if(cfenc==kCFStringEncodingInvalidId) return 0;

	return CFStringConvertEncodingToNSStringEncoding(cfenc);
}

#endif

@end
