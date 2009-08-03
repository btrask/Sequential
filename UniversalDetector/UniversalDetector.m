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

-(NSString *)MIMECharset
{
	if(!charset)
	{
		const char *cstr=UniversalDetectorCharset(detector,&confidence);
		if(!cstr) return nil;
		charset=[[NSString alloc] initWithUTF8String:cstr];
	}
	return charset;
}

-(float)confidence
{
	if(!charset) [self MIMECharset];
	return confidence;
}

#ifndef GNUSTEP

-(NSStringEncoding)encoding
{
	NSString *mimecharset=[self MIMECharset];
	if(!mimecharset) return 0;

	CFStringEncoding cfenc=CFStringConvertIANACharSetNameToEncoding((CFStringRef)mimecharset);
	if(cfenc==kCFStringEncodingInvalidId) return 0;

	return CFStringConvertEncodingToNSStringEncoding(cfenc);
}

#else

-(NSStringEncoding)encoding
{
	static NSDictionary *encodingdictionary=nil;
	if(!encodingdictionary) encodingdictionary=[[NSDictionary alloc] initWithObjectsAndKeys:
		// Foundation
		[NSNumber numberWithUnsignedInt:NSJapaneseEUCStringEncoding],@"EUC-JP",
		[NSNumber numberWithUnsignedInt:NSJapaneseEUCStringEncoding],@"EUCJP",
		[NSNumber numberWithUnsignedInt:NSISO2022JPStringEncoding],@"ISO-2022-JP",
		[NSNumber numberWithUnsignedInt:NSISOLatin2StringEncoding],@"ISO-8859-2",
		[NSNumber numberWithUnsignedInt:NSShiftJISStringEncoding],@"Shift_JIS",
		[NSNumber numberWithUnsignedInt:NSShiftJISStringEncoding],@"SJIS",
		[NSNumber numberWithUnsignedInt:NSUTF8StringEncoding],@"UTF-8",
		[NSNumber numberWithUnsignedInt:NSUTF8StringEncoding],@"UTF8",
		[NSNumber numberWithUnsignedInt:NSWindowsCP1250StringEncoding],@"windows-1250",
		[NSNumber numberWithUnsignedInt:NSWindowsCP1251StringEncoding],@"windows-1251",
		[NSNumber numberWithUnsignedInt:NSWindowsCP1252StringEncoding],@"windows-1252",
		[NSNumber numberWithUnsignedInt:NSWindowsCP1253StringEncoding],@"windows-1253",
		// GNUstep only
		[NSNumber numberWithUnsignedInt:NSBIG5StringEncoding],@"Big5",
		[NSNumber numberWithUnsignedInt:NSKoreanEUCStringEncoding],@"EUC-KR",
		[NSNumber numberWithUnsignedInt:NSKoreanEUCStringEncoding],@"EUCKR",
		[NSNumber numberWithUnsignedInt:NSGB2312StringEncoding],@"GB2312",
		[NSNumber numberWithUnsignedInt:NSGB2312StringEncoding],@"HZ-GB-2312",
		[NSNumber numberWithUnsignedInt:NSISOCyrillicStringEncoding],@"ISO-8859-5",
		[NSNumber numberWithUnsignedInt:NSISOGreekStringEncoding],@"ISO-8859-7",
		[NSNumber numberWithUnsignedInt:NSISOHebrewStringEncoding],@"ISO-8859-8",
		[NSNumber numberWithUnsignedInt:NSKOI8RStringEncoding],@"KOI8-R",
		// GNUstep only, approximate
		[NSNumber numberWithUnsignedInt:NSGB2312StringEncoding],@"gb18030",
		[NSNumber numberWithUnsignedInt:NSGB2312StringEncoding],@"GB18030",
		[NSNumber numberWithUnsignedInt:NSISOHebrewStringEncoding],@"ISO-8859-8-I",
		[NSNumber numberWithUnsignedInt:NSISOHebrewStringEncoding],@"windows-1255",
		// Unsupported
		/*[NSNumber numberWithUnsignedInt:],@"EUCTW",
		[NSNumber numberWithUnsignedInt:],@"IBM855",
		[NSNumber numberWithUnsignedInt:],@"IBM866",
		[NSNumber numberWithUnsignedInt:],@"ISO-2022-CN",
		[NSNumber numberWithUnsignedInt:],@"ISO-2022-KR",
		[NSNumber numberWithUnsignedInt:],@"TIS-620",
		[NSNumber numberWithUnsignedInt:],@"UTF-16BE",
		[NSNumber numberWithUnsignedInt:],@"UTF-16LE",
		[NSNumber numberWithUnsignedInt:],@"UTF-32BE",
		[NSNumber numberWithUnsignedInt:],@"UTF-32LE",
		[NSNumber numberWithUnsignedInt:],@"x-euc-tw",
		[NSNumber numberWithUnsignedInt:],@"X-ISO-10646-UCS-4-2143",
		[NSNumber numberWithUnsignedInt:],@"X-ISO-10646-UCS-4-3412",
		[NSNumber numberWithUnsignedInt:],@"x-mac-cyrillic",
		[NSNumber numberWithUnsignedInt:],@"x-mac-hebrew",*/
	nil];

	NSString *mimecharset=[self MIMECharset];
	if(!mimecharset) return 0;

	NSNumber *encoding=[encodingdictionary objectForKey:mimecharset];
	if(!encoding) return 0;

	return [encoding unsignedIntValue];
}

#endif

@end
