#import "XADString.h"

#import "../UniversalDetector/UniversalDetector.h"



NSString *XADASCIIStringEncodingName=@"US-ASCII";
NSString *XADUTF8StringEncodingName=@"UTF-8";

NSString *XADISOLatin1StringEncodingName=@"iso-8859-1";
NSString *XADISOLatin2StringEncodingName=@"iso-8859-2";
NSString *XADISOLatin3StringEncodingName=@"iso-8859-3";
NSString *XADISOLatin4StringEncodingName=@"iso-8859-4";
NSString *XADISOLatin5StringEncodingName=@"iso-8859-5";
NSString *XADISOLatin6StringEncodingName=@"iso-8859-6";
NSString *XADISOLatin7StringEncodingName=@"iso-8859-7";
NSString *XADISOLatin8StringEncodingName=@"iso-8859-8";
NSString *XADISOLatin9StringEncodingName=@"iso-8859-9";
NSString *XADISOLatin10StringEncodingName=@"iso-8859-10";
NSString *XADISOLatin11StringEncodingName=@"iso-8859-11";
NSString *XADISOLatin12StringEncodingName=@"iso-8859-12";
NSString *XADISOLatin13StringEncodingName=@"iso-8859-13";
NSString *XADISOLatin14StringEncodingName=@"iso-8859-14";
NSString *XADISOLatin15StringEncodingName=@"iso-8859-15";
NSString *XADISOLatin16StringEncodingName=@"iso-8859-16";

NSString *XADShiftJISStringEncodingName=@"Shift_JIS";

NSString *XADWindowsCP1250StringEncodingName=@"windows-1250";
NSString *XADWindowsCP1251StringEncodingName=@"windows-1251";
NSString *XADWindowsCP1252StringEncodingName=@"windows-1252";
NSString *XADWindowsCP1253StringEncodingName=@"windows-1253";
NSString *XADWindowsCP1254StringEncodingName=@"windows-1254";

NSString *XADMacOSRomanStringEncodingName=@"macintosh";
NSString *XADMacOSJapaneseStringEncodingName=@"x-mac-japanese";
NSString *XADMacOSTraditionalChineseStringEncodingName=@"x-mac-trad-chinese";
NSString *XADMacOSKoreanStringEncodingName=@"x-mac-korean";
NSString *XADMacOSArabicStringEncodingName=@"x-mac-arabic";
NSString *XADMacOSHebrewStringEncodingName=@"x-mac-hebrew";
NSString *XADMacOSGreekStringEncodingName=@"x-mac-greek";
NSString *XADMacOSCyrillicStringEncodingName=@"x-mac-cyrillic";
NSString *XADMacOSSimplifiedChineseStringEncodingName=@"x-mac-simp-chinese";
NSString *XADMacOSRomanianStringEncodingName=@"x-mac-romanian";
NSString *XADMacOSUkranianStringEncodingName=@"x-mac-ukrainian";
NSString *XADMacOSThaiStringEncodingName=@"x-mac-thai";
NSString *XADMacOSCentralEuropeanRomanStringEncodingName=@"x-mac-centraleurroman";
NSString *XADMacOSIcelandicStringEncodingName=@"x-mac-icelandic";
NSString *XADMacOSTurkishStringEncodingName=@"x-mac-turkish";
NSString *XADMacOSCroatianStringEncodingName=@"x-mac-croatian";

static BOOL IsDataASCII(NSData *data);

@implementation XADString

+(XADString *)XADStringWithString:(NSString *)string
{
	return [[[self alloc] initWithString:string] autorelease];
}

+(XADString *)analyzedXADStringWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
{
	[stringsource analyzeData:bytedata];

	if(IsDataASCII(bytedata))
	{
		return [self decodedXADStringWithData:bytedata encodingName:XADASCIIStringEncodingName];
	}
	else
	{
		return [[[self alloc] initWithData:bytedata source:stringsource] autorelease];
	}
}

+(XADString *)decodedXADStringWithData:(NSData *)bytedata encodingName:(NSString *)encoding
{
	NSString *string=[XADString stringForData:bytedata encodingName:encoding];
	return [[[self alloc] initWithString:string] autorelease];
}




+(NSString *)escapedStringForData:(NSData *)data encodingName:(NSString *)encoding
{
	NSString *decstr=[XADString stringForData:data encodingName:encoding];
	if(decstr) return decstr;

	// Fall back on escaped ASCII if the encoding was unusable.
	return [self escapedASCIIStringForBytes:[data bytes] length:[data length]];
}

+(NSString *)escapedStringForBytes:(const void *)bytes length:(size_t)length
encodingName:(NSString *)encoding
{
	NSString *decstr=[XADString stringForBytes:bytes length:length encodingName:encoding];
	if(decstr) return decstr;

	// Fall back on escaped ASCII if the encoding was unusable.
	return [self escapedASCIIStringForBytes:bytes length:length];
}

+(NSString *)escapedASCIIStringForBytes:(const void *)bytes length:(size_t)length
{
	NSMutableString *str=[NSMutableString stringWithCapacity:length];

	const uint8_t *byteptr=bytes;
	for(int i=0;i<length;i++)
	{
		if(byteptr[i]<0x80) [str appendFormat:@"%c",byteptr[i]];
		else [str appendFormat:@"%%%02x",byteptr[i]];
	}

	return [NSString stringWithString:str];
}

+(NSData *)escapedASCIIDataForString:(NSString *)string
{
	int length=[string length];
	NSMutableData *encdata=[NSMutableData dataWithCapacity:length];

	for(int i=0;i<length;i++)
	{
		char bytes[8];
		unichar c=[string characterAtIndex:i];
		if(c<0x80)
		{
			bytes[0]=c;
			[encdata appendBytes:bytes length:1];
		}
		else
		{
			sprintf(bytes,"%%u%04x",c&0xffff);
			[encdata appendBytes:bytes length:6];
		}
	}

	return [NSData dataWithData:encdata];
	// Do not use this because Cocotron doesn't support it.
	//return [string dataUsingEncoding:NSNonLossyASCIIStringEncoding];
}




-(id)initWithData:(NSData *)bytedata source:(XADStringSource *)stringsource
{
	if((self=[super init]))
	{
		data=[bytedata retain];
		string=nil;
		source=[stringsource retain];
	}
	return self;
}

-(id)initWithString:(NSString *)knownstring
{
	if((self=[super init]))
	{
		string=[knownstring retain];
		data=nil;
		source=nil;
	}
	return self;
}

-(void)dealloc
{
	[data release];
	[string release];
	[source release];
	[super dealloc];
}



-(BOOL)canDecodeWithEncodingName:(NSString *)encoding
{
	if(string) return YES;
	return [XADString canDecodeData:data encodingName:encoding];
}

-(NSString *)string
{
	return [self stringWithEncodingName:[source encodingName]];
}

-(NSString *)stringWithEncodingName:(NSString *)encoding
{
	if(string) return string;
	return [XADString escapedStringForData:data encodingName:encoding];
}

-(NSData *)data
{
	if(data) return data;
	return [XADString escapedASCIIDataForString:string];
}



-(BOOL)encodingIsKnown
{
	if(!source) return YES;
	if([source hasFixedEncoding]) return YES;
	return NO;
}

-(NSString *)encodingName
{
	if(!source) return XADUTF8StringEncodingName; // TODO: what should this really return?
	return [source encodingName];
}

-(float)confidence
{
	if(!source) return 1;
	return [source confidence];
}



-(XADStringSource *)source { return source; }



-(BOOL)hasASCIIPrefix:(NSString *)asciiprefix
{
	if(string) return [string hasPrefix:asciiprefix];
	else
	{
		int length=[asciiprefix length];
		if([data length]<length) return NO;

		const uint8_t *bytes=[data bytes];
		for(int i=0;i<length;i++) if(bytes[i]!=[asciiprefix characterAtIndex:i]) return NO;

		return YES;
	}
}

-(XADString *)XADStringByStrippingASCIIPrefixOfLength:(int)length
{
	if(string)
	{
		return [[[XADString alloc]
		initWithString:[string substringFromIndex:length]]
		autorelease];
	}
	else
	{
		return [[[XADString alloc]
		initWithData:[data subdataWithRange:
		NSMakeRange(length,[data length]-length)]
		source:source] autorelease];
	}
}



-(BOOL)isEqual:(id)other
{
	if([other isKindOfClass:[NSString class]]) return [[self string] isEqual:other];
	else if([other isKindOfClass:[self class]])
	{
		XADString *xadstr=(XADString *)other;

		if(string&&xadstr->string) return [string isEqual:xadstr->string];
		else if(data&&xadstr->data&&source==xadstr->source) return [data isEqual:xadstr->data];
		else return NO;
	}
	else return NO;
}

-(NSUInteger)hash
{
	if(string) return [string hash];
	else return [data hash];
}



-(NSString *)description
{
	// TODO: more info?
	return [self string];
}

-(id)copyWithZone:(NSZone *)zone
{
	if(string) return [[XADString allocWithZone:zone] initWithString:string];
	else return [[XADString allocWithZone:zone] initWithData:data source:source];
}


#ifdef __APPLE__
-(BOOL)canDecodeWithEncoding:(NSStringEncoding)encoding
{
	return [self canDecodeWithEncodingName:[XADString encodingNameForEncoding:encoding]];
}

-(NSString *)stringWithEncoding:(NSStringEncoding)encoding
{
	return [self stringWithEncodingName:[XADString encodingNameForEncoding:encoding]];
}

-(NSStringEncoding)encoding
{
	if(!source) return NSUTF8StringEncoding; // TODO: what should this really return?
	else return [source encoding];
}
#endif

@end



@implementation XADStringSource

-(id)init
{
	if((self=[super init]))
	{
		detector=[UniversalDetector new]; // can return nil if UniversalDetector is not found
		fixedencodingname=nil;
		mac=NO;
		hasanalyzeddata=NO;
	}
	return self;
}

-(void)dealloc
{
	[detector release];
	[fixedencodingname release];
	[super dealloc];
}

-(void)analyzeData:(NSData *)data
{
	hasanalyzeddata=YES;
	[detector analyzeData:data];
}

-(BOOL)hasAnalyzedData { return hasanalyzeddata; }

-(NSString *)encodingName
{
	if(fixedencodingname) return fixedencodingname;
	if(!detector) return XADWindowsCP1252StringEncodingName;

	NSString *encoding=[detector MIMECharset];
	if(!encoding) encoding=XADWindowsCP1252StringEncodingName;

	// Kludge to use Mac encodings instead of the similar Windows encodings for Mac archives
	// TODO: improve
	if(mac)
	{
		static NSDictionary *macalternatives=nil;
		if(!macalternatives) macalternatives=[[NSDictionary alloc] initWithObjectsAndKeys:
			XADMacOSRomanStringEncodingName,[XADASCIIStringEncodingName lowercaseString],
			XADMacOSRomanStringEncodingName,[XADWindowsCP1252StringEncodingName lowercaseString],
			XADMacOSJapaneseStringEncodingName,[XADShiftJISStringEncodingName lowercaseString],
		nil];

		NSString *macalternative=[macalternatives objectForKey:[encoding lowercaseString]];
		if(macalternative) return macalternative;
	}

	return encoding;
}

-(float)confidence
{
	if(fixedencodingname) return 1;
	if(!detector) return 0;
	if(![detector MIMECharset]) return 0;
	return [detector confidence];
}

-(UniversalDetector *)detector
{
	return detector;
}

-(void)setFixedEncodingName:(NSString *)encoding
{
	[fixedencodingname autorelease];
	fixedencodingname=[encoding retain];
}

-(BOOL)hasFixedEncoding
{
	return fixedencodingname!=nil;
}

-(void)setPrefersMacEncodings:(BOOL)prefermac
{
	mac=prefermac;
}



#ifdef __APPLE__
-(NSStringEncoding)encoding
{
	NSString *encodingname=[self encodingName];
	if(!encodingname) return 0;

	return [XADString encodingForEncodingName:encodingname];
}

-(void)setFixedEncoding:(NSStringEncoding)encoding
{
	if(!encoding) [self setFixedEncodingName:nil];
	else [self setFixedEncodingName:[XADString encodingNameForEncoding:encoding]];
}
#endif

@end




static BOOL IsDataASCII(NSData *data)
{
	const char *bytes=[data bytes];
	int length=[data length];
	for(int i=0;i<length;i++) if(bytes[i]&0x80) return NO;
	return YES;
}
