/*
 * This implementation does not really work much at all, because iconv is horrible. Use ICU instead.
 */

#import "XADString.h"

#import <iconv.h>

#define MaxEncodingNameLength 128

static void IconvNameForEncodingName(char *cstr,NSString *name);

@implementation XADString (PlatformSpecific)

+(NSString *)stringForData:(NSData *)data encodingName:(NSString *)encoding
{
	char encbuf[MaxEncodingNameLength+1];
	IconvNameForEncodingName(encbuf,encoding);

	iconv_t ic=iconv_open("UCS-2-INTERNAL",encbuf);
	if(ic==(iconv_t)(-1)) return nil;

	char *inptr=(char *)[data bytes]; // iconv is horrible and doesn't declare its input as const.
	size_t inlen=[data length];

	uint16_t chars[1024];
	NSMutableString *string=[NSMutableString string];

	while(inlen)
	{
		char *outptr=(char *)&chars;
		size_t outlen=sizeof(chars)/sizeof(*chars)-1;
		if(iconv(ic,&inptr,&inlen,&outptr,&outlen)==-1)
		{
			if(errno!=E2BIG) return nil;
		}

		*(uint16_t *)outptr=0;
		[string appendFormat:@"%S",chars];
	}

	return [NSString stringWithString:string];
}

+(NSData *)dataForString:(NSString *)string encodingName:(NSString *)encoding
{
	char encbuf[MaxEncodingNameLength+1];
	IconvNameForEncodingName(encbuf,encoding);

	iconv_t ic=iconv_open(encbuf,"UCS-2-INTERNAL");
	if(ic==(iconv_t)(-1)) return nil;

	int numchars=[string length];
	unichar chars[numchars];
	[string getCharacters:chars range:NSMakeRange(0,numchars)];
	char *inptr=(char *)chars;
	size_t inlen=numchars*2;

	char bytes[1024];
	NSMutableData *data=[NSMutableData data];

	while(inlen)
	{
		char *outptr=bytes;
		size_t outlen=sizeof(bytes);

		if(iconv(ic,&inptr,&inlen,&outptr,&outlen)==-1)
		{
			if(errno!=E2BIG) return nil;
		}

		[data appendBytes:bytes length:outptr-bytes];
	}

	return [NSData dataWithData:data];
}

+(NSArray *)availableEncodingNames
{
}

static void IconvNameForEncodingName(char *cstr,NSString *name)
{
	static NSDictionary *replacementdictionary=nil;
	if(!replacementdictionary) replacementdictionary=[[NSDictionary alloc] initWithObjectsAndKeys:
	// Try to map normal names to weird iconv ones. Apparently these vary from implementation
	// to implementation though and this will be all wrong anyway. Sheesh.
	@"MACCENTRALEUROPE",@"x-mac-centraleurroman",
	@"MACICELAND",@"x-mac-icelandic",
	@"MACCROATIAN",@"x-mac-croatian",
	@"MACROMANIA",@"x-mac-romanian",
	@"MACCYRILLIC",@"x-mac-cyrillic",
	@"MACUKRAINE",@"x-mac-ukrainian",
	@"MACGREEK",@"x-mac-greek",
	@"MACTURKISH",@"x-mac-turkish",
	@"MACHEBREW",@"x-mac-hebrew",
	@"MACARABIC",@"x-mac-arabic",
	@"MACTHAI",@"x-mac-thai",
	// Still unknown:
	//x-mac-japanese
	//x-mac-trad-chinese
	//x-mac-korean
	//x-mac-devanagari
	//x-mac-gurmukhi
	//x-mac-gujarati
	//x-mac-simp-chinese
	//x-mac-tibetan
	//x-mac-symbol
	//x-mac-dingbats
	//x-mac-celtic
	//x-mac-gaelic
	//x-mac-farsi
	//x-mac-inuit
	//x-mac-roman-latin1
	nil];

	name=[name lowercaseString];

	NSString *replacement=[replacementdictionary objectForKey:name];
	if(replacement) name=replacement;

	NSAutoreleasePool *pool=[NSAutoreleasePool new];
	NSData *data=[name dataUsingEncoding:NSASCIIStringEncoding allowLossyConversion:YES];
	int length=[data length];
	if(length>MaxEncodingNameLength) length=MaxEncodingNameLength;
	memcpy(cstr,[data bytes],length);
	cstr[length]=0;
	[pool release];
}

@end
