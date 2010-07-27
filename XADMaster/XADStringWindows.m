#import "XADString.h"

#import <windows.h>

#ifndef MB_ERR_INVALID_CHARS
#define MB_ERR_INVALID_CHARS 0x8
#endif

static int EncodingNameToWindowsCodePage(NSString *name);
static NSDictionary *EncodingNamesForWindowsCodePageDictionary();
static NSDictionary *WindowsCodePageForEncodingNameDictionary();
static NSDictionary *DescriptionForWindowsCodePageDictionary();

@implementation XADString (PlatformSpecific)

+(NSString *)stringForData:(NSData *)data encodingName:(NSString *)encoding
{
	int codepage=EncodingNameToWindowsCodePage(encoding);
	if(!codepage) return nil;

	int numbytes=[data length];
	const uint8_t *bytebuf=[data bytes];

	int numchars=MultiByteToWideChar(codepage,MB_ERR_INVALID_CHARS,bytebuf,numbytes,NULL,0);
	if(numchars==0) return nil;

	unichar *charbuf=malloc(sizeof(unichar)*numchars);
	MultiByteToWideChar(codepage,MB_ERR_INVALID_CHARS,bytebuf,numbytes,charbuf,numchars);

	return [[[NSString alloc] initWithCharactersNoCopy:charbuf length:numchars freeWhenDone:YES] autorelease];
}

+(NSData *)dataForString:(NSString *)string encodingName:(NSString *)encoding
{
	int codepage=EncodingNameToWindowsCodePage(encoding);
	if(!codepage) return nil;

	int numchars=[string length];
	unichar charbuf[numchars];
	[string getCharacters:charbuf range:NSMakeRange(0,numchars)];

	int numbytes=WideCharToMultiByte(codepage,MB_ERR_INVALID_CHARS,charbuf,numchars,NULL,0,NULL,NULL);
	if(numbytes==0) return nil;

	uint8_t *bytebuf=malloc(numbytes);
	WideCharToMultiByte(codepage,MB_ERR_INVALID_CHARS,charbuf,numchars,bytebuf,numbytes,NULL,NULL);

	return [NSData dataWithBytesNoCopy:bytebuf length:numbytes freeWhenDone:YES];
}

+(NSArray *)availableEncodingNames
{
	NSMutableArray *array=[NSMutableArray array];
	NSDictionary *namesdictionary=EncodingNamesForWindowsCodePageDictionary();
	NSDictionary *descriptiondictionary=DescriptionForWindowsCodePageDictionary();

	NSArray *codepages=[[namesdictionary allKeys] sortedArrayUsingSelector:@selector(compare:)];

	NSEnumerator *enumerator=[codepages objectEnumerator];
	NSNumber *codepage;
	while(codepage=[enumerator nextObject])
	{
		NSArray *names=[namesdictionary objectForKey:codepage];
		NSString *description=[descriptiondictionary objectForKey:codepage];
		NSMutableArray *encodingarray=[NSMutableArray arrayWithObject:description];
		[encodingarray addObjectsFromArray:[names sortedArrayUsingSelector:@selector(compare:)]];
		[encodingarray addObject:[NSString stringWithFormat:@"cp%@",codepage]];
		[array addObject:encodingarray];
	}

	return array;
}

@end




static int EncodingNameToWindowsCodePage(NSString *name)
{
	NSDictionary *dictionary=WindowsCodePageForEncodingNameDictionary();

	name=[name lowercaseString];

	if([name hasPrefix:@"cp"])
	{
		int length=[name length];
		unichar buf[length-1];
		[name getCharacters:buf range:NSMakeRange(2,length-2)];
		buf[length-2]=0;
		return _wtoi(buf);
	}
	else
	{
		NSNumber *encoding=[dictionary objectForKey:[name lowercaseString]];
		if(!encoding) return 0;
		return [encoding unsignedIntValue];
	}
}

static NSDictionary *EncodingNamesForWindowsCodePageDictionary()
{
	static NSDictionary *dictionary=nil;
	if(!dictionary)
	{
		NSMutableDictionary *namesdictionary=[NSMutableDictionary dictionary];
		NSDictionary *codepagedictionary=WindowsCodePageForEncodingNameDictionary();

		NSEnumerator *enumerator=[codepagedictionary keyEnumerator];
		NSString *name;
		while(name=[enumerator nextObject])
		{
			NSNumber *codepage=[codepagedictionary objectForKey:name];

			NSMutableArray *names=[namesdictionary objectForKey:codepage];
			if(!names)
			{
				names=[NSMutableArray array];
				[namesdictionary setObject:names forKey:codepage];
			}

			[names addObject:name];
		}

		dictionary=[namesdictionary copy];
	}
	return dictionary;
}

static NSDictionary *WindowsCodePageForEncodingNameDictionary()
{
	static NSDictionary *dictionary=nil;
	if(!dictionary) dictionary=[[NSDictionary alloc] initWithObjectsAndKeys:
	[NSNumber numberWithInt:37],@"ibm037", // IBM EBCDIC US-Canada
	[NSNumber numberWithInt:437],@"ibm437", // OEM United States
	[NSNumber numberWithInt:500],@"ibm500", // IBM EBCDIC International
	[NSNumber numberWithInt:708],@"asmo-708", // Arabic (ASMO 708)
	//[NSNumber numberWithInt:709],@"", // Arabic (ASMO-449+, BCON V4)
	//[NSNumber numberWithInt:710],@"", // Arabic - Transparent Arabic
	[NSNumber numberWithInt:720],@"dos-720", // Arabic (Transparent ASMO); Arabic (DOS)
	[NSNumber numberWithInt:737],@"ibm737", // OEM Greek (formerly 437G); Greek (DOS)
	[NSNumber numberWithInt:775],@"ibm775", // OEM Baltic; Baltic (DOS)
	[NSNumber numberWithInt:850],@"ibm850", // OEM Multilingual Latin 1; Western European (DOS)
	[NSNumber numberWithInt:852],@"ibm852", // OEM Latin 2; Central European (DOS)
	[NSNumber numberWithInt:855],@"ibm855", // OEM Cyrillic (primarily Russian)
	[NSNumber numberWithInt:857],@"ibm857", // OEM Turkish; Turkish (DOS)
	[NSNumber numberWithInt:858],@"ibm00858", // OEM Multilingual Latin 1 + Euro symbol
	[NSNumber numberWithInt:860],@"ibm860", // OEM Portuguese; Portuguese (DOS)
	[NSNumber numberWithInt:861],@"ibm861", // OEM Icelandic; Icelandic (DOS)
	[NSNumber numberWithInt:862],@"dos-862", // OEM Hebrew; Hebrew (DOS)
	[NSNumber numberWithInt:863],@"ibm863", // OEM French Canadian; French Canadian (DOS)
	[NSNumber numberWithInt:864],@"ibm864", // OEM Arabic; Arabic (864)
	[NSNumber numberWithInt:865],@"ibm865", // OEM Nordic; Nordic (DOS)
	[NSNumber numberWithInt:866],@"ibm866", // OEM Russian; Cyrillic (DOS)
	[NSNumber numberWithInt:869],@"ibm869", // OEM Modern Greek; Greek, Modern (DOS)
	[NSNumber numberWithInt:870],@"ibm870", // IBM EBCDIC Multilingual/ROECE (Latin 2); IBM EBCDIC Multilingual Latin 2
	[NSNumber numberWithInt:874],@"windows-874", // ANSI/OEM Thai (same as 28605, ISO 8859-15); Thai (Windows)
	//[NSNumber numberWithInt:875],@"cp875", // IBM EBCDIC Greek Modern
	[NSNumber numberWithInt:932],@"shift_jis", // ANSI/OEM Japanese; Japanese (Shift-JIS)
	[NSNumber numberWithInt:932],@"shift-jis", // ANSI/OEM Japanese; Japanese (Shift-JIS)
	[NSNumber numberWithInt:936],@"gb2312", // ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
	[NSNumber numberWithInt:936],@"euc-cn", // ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
	[NSNumber numberWithInt:936],@"euc_cn", // ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
	[NSNumber numberWithInt:936],@"euccn", // ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
	[NSNumber numberWithInt:936],@"cn-gb", // ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
	[NSNumber numberWithInt:949],@"ks_c_5601-1987", // ANSI/OEM Korean (Unified Hangul Code)
	[NSNumber numberWithInt:950],@"big5", // ANSI/OEM Traditional Chinese (Taiwan; Hong Kong SAR, PRC); Chinese Traditional (Big5)
	[NSNumber numberWithInt:1026],@"ibm1026", // IBM EBCDIC Turkish (Latin 5)
	[NSNumber numberWithInt:1047],@"ibm01047", // IBM EBCDIC Latin 1/Open System
	[NSNumber numberWithInt:1140],@"ibm01140", // IBM EBCDIC US-Canada (037 + Euro symbol); IBM EBCDIC (US-Canada-Euro)
	[NSNumber numberWithInt:1141],@"ibm01141", // IBM EBCDIC Germany (20273 + Euro symbol); IBM EBCDIC (Germany-Euro)
	[NSNumber numberWithInt:1142],@"ibm01142", // IBM EBCDIC Denmark-Norway (20277 + Euro symbol); IBM EBCDIC (Denmark-Norway-Euro)
	[NSNumber numberWithInt:1143],@"ibm01143", // IBM EBCDIC Finland-Sweden (20278 + Euro symbol); IBM EBCDIC (Finland-Sweden-Euro)
	[NSNumber numberWithInt:1144],@"ibm01144", // IBM EBCDIC Italy (20280 + Euro symbol); IBM EBCDIC (Italy-Euro)
	[NSNumber numberWithInt:1145],@"ibm01145", // IBM EBCDIC Latin America-Spain (20284 + Euro symbol); IBM EBCDIC (Spain-Euro)
	[NSNumber numberWithInt:1146],@"ibm01146", // IBM EBCDIC United Kingdom (20285 + Euro symbol); IBM EBCDIC (UK-Euro)
	[NSNumber numberWithInt:1147],@"ibm01147", // IBM EBCDIC France (20297 + Euro symbol); IBM EBCDIC (France-Euro)
	[NSNumber numberWithInt:1148],@"ibm01148", // IBM EBCDIC International (500 + Euro symbol); IBM EBCDIC (International-Euro)
	[NSNumber numberWithInt:1149],@"ibm01149", // IBM EBCDIC Icelandic (20871 + Euro symbol); IBM EBCDIC (Icelandic-Euro)
	[NSNumber numberWithInt:1200],@"utf-16", // Unicode UTF-16, little endian byte order (BMP of ISO 10646); available only to managed applications
	[NSNumber numberWithInt:1200],@"utf-16le", // Unicode UTF-16, little endian byte order (BMP of ISO 10646); available only to managed applications
	[NSNumber numberWithInt:1201],@"unicodefffe", // Unicode UTF-16, big endian byte order; available only to managed applications
	[NSNumber numberWithInt:1201],@"utf-16be", // Unicode UTF-16, big endian byte order; available only to managed applications
	[NSNumber numberWithInt:1250],@"windows-1250", // ANSI Central European; Central European (Windows)
	[NSNumber numberWithInt:1251],@"windows-1251", // ANSI Cyrillic; Cyrillic (Windows)
	[NSNumber numberWithInt:1252],@"windows-1252", // ANSI Latin 1; Western European (Windows)
	[NSNumber numberWithInt:1253],@"windows-1253", // ANSI Greek; Greek (Windows)
	[NSNumber numberWithInt:1254],@"windows-1254", // ANSI Turkish; Turkish (Windows)
	[NSNumber numberWithInt:1255],@"windows-1255", // ANSI Hebrew; Hebrew (Windows)
	[NSNumber numberWithInt:1256],@"windows-1256", // ANSI Arabic; Arabic (Windows)
	[NSNumber numberWithInt:1257],@"windows-1257", // ANSI Baltic; Baltic (Windows)
	[NSNumber numberWithInt:1258],@"windows-1258", // ANSI/OEM Vietnamese; Vietnamese (Windows)
	[NSNumber numberWithInt:1361],@"johab", // Korean (Johab)
	[NSNumber numberWithInt:10000],@"mac", // MAC Roman; Western European (Mac)
	[NSNumber numberWithInt:10000],@"macintosh", // MAC Roman; Western European (Mac)
	[NSNumber numberWithInt:10000],@"macroman", // MAC Roman; Western European (Mac)
	[NSNumber numberWithInt:10001],@"x-mac-japanese", // Japanese (Mac)
	[NSNumber numberWithInt:10001],@"macjapanese", // Japanese (Mac)
	[NSNumber numberWithInt:10002],@"x-mac-chinesetrad", // MAC Traditional Chinese (Big5); Chinese Traditional (Mac)
	[NSNumber numberWithInt:10002],@"macchinesetrad", // MAC Traditional Chinese (Big5); Chinese Traditional (Mac)
	[NSNumber numberWithInt:10003],@"x-mac-korean", // Korean (Mac)
	[NSNumber numberWithInt:10003],@"mackorean", // Korean (Mac)
	[NSNumber numberWithInt:10004],@"x-mac-arabic", // Arabic (Mac)
	[NSNumber numberWithInt:10004],@"macarabic", // Arabic (Mac)
	[NSNumber numberWithInt:10005],@"x-mac-hebrew", // Hebrew (Mac)
	[NSNumber numberWithInt:10005],@"machebrew", // Hebrew (Mac)
	[NSNumber numberWithInt:10006],@"x-mac-greek", // Greek (Mac)
	[NSNumber numberWithInt:10006],@"macgreek", // Greek (Mac)
	[NSNumber numberWithInt:10007],@"x-mac-cyrillic", // Cyrillic (Mac)
	[NSNumber numberWithInt:10007],@"maccyrillic", // Cyrillic (Mac)
	[NSNumber numberWithInt:10008],@"x-mac-chinesesimp", // MAC Simplified Chinese (GB 2312); Chinese Simplified (Mac)
	[NSNumber numberWithInt:10008],@"macchinesesimp", // MAC Simplified Chinese (GB 2312); Chinese Simplified (Mac)
	[NSNumber numberWithInt:10010],@"x-mac-romanian", // Romanian (Mac)
	[NSNumber numberWithInt:10010],@"macromanian", // Romanian (Mac)
	[NSNumber numberWithInt:10017],@"x-mac-ukrainian", // Ukrainian (Mac)
	[NSNumber numberWithInt:10017],@"macukrainian", // Ukrainian (Mac)
	[NSNumber numberWithInt:10021],@"x-mac-thai", // Thai (Mac)
	[NSNumber numberWithInt:10021],@"macthai", // Thai (Mac)
	[NSNumber numberWithInt:10029],@"x-mac-centraleurroman", // MAC Latin 2; Central European (Mac)
	[NSNumber numberWithInt:10029],@"macceentraleurope", // MAC Latin 2; Central European (Mac)
	[NSNumber numberWithInt:10029],@"x-mac-ce", // MAC Latin 2; Central European (Mac)
	[NSNumber numberWithInt:10079],@"x-mac-icelandic", // Icelandic (Mac)
	[NSNumber numberWithInt:10079],@"macicelandic", // Icelandic (Mac)
	[NSNumber numberWithInt:10081],@"x-mac-turkish", // Turkish (Mac)
	[NSNumber numberWithInt:10081],@"macturkish", // Turkish (Mac)
	[NSNumber numberWithInt:10082],@"x-mac-croatian", // Croatian (Mac)
	[NSNumber numberWithInt:10082],@"maccroatian", // Croatian (Mac)
	[NSNumber numberWithInt:12000],@"utf-32", // Unicode UTF-32, little endian byte order; available only to managed applications
	[NSNumber numberWithInt:12000],@"utf-32le", // Unicode UTF-32, little endian byte order; available only to managed applications
	[NSNumber numberWithInt:12001],@"utf-32be", // Unicode UTF-32, big endian byte order; available only to managed applications
	[NSNumber numberWithInt:20000],@"x-chinese_cns", // CNS Taiwan; Chinese Traditional (CNS)
	[NSNumber numberWithInt:20001],@"x-cp20001", // TCA Taiwan
	[NSNumber numberWithInt:20002],@"x_chinese-eten", // Eten Taiwan; Chinese Traditional (Eten)
	[NSNumber numberWithInt:20003],@"x-cp20003", // IBM5550 Taiwan
	[NSNumber numberWithInt:20004],@"x-cp20004", // TeleText Taiwan
	[NSNumber numberWithInt:20005],@"x-cp20005", // Wang Taiwan
	[NSNumber numberWithInt:20105],@"x-ia5", // IA5 (IRV International Alphabet No. 5, 7-bit); Western European (IA5)
	[NSNumber numberWithInt:20106],@"x-ia5-german", // IA5 German (7-bit)
	[NSNumber numberWithInt:20107],@"x-ia5-swedish", // IA5 Swedish (7-bit)
	[NSNumber numberWithInt:20108],@"x-ia5-norwegian", // IA5 Norwegian (7-bit)
	[NSNumber numberWithInt:20127],@"us-ascii", // US-ASCII (7-bit)
	[NSNumber numberWithInt:20261],@"x-cp20261", // T.61
	[NSNumber numberWithInt:20269],@"x-cp20269", // ISO 6937 Non-Spacing Accent
	[NSNumber numberWithInt:20273],@"ibm273", // IBM EBCDIC Germany
	[NSNumber numberWithInt:20277],@"ibm277", // IBM EBCDIC Denmark-Norway
	[NSNumber numberWithInt:20278],@"ibm278", // IBM EBCDIC Finland-Sweden
	[NSNumber numberWithInt:20280],@"ibm280", // IBM EBCDIC Italy
	[NSNumber numberWithInt:20284],@"ibm284", // IBM EBCDIC Latin America-Spain
	[NSNumber numberWithInt:20285],@"ibm285", // IBM EBCDIC United Kingdom
	[NSNumber numberWithInt:20290],@"ibm290", // IBM EBCDIC Japanese Katakana Extended
	[NSNumber numberWithInt:20297],@"ibm297", // IBM EBCDIC France
	[NSNumber numberWithInt:20420],@"ibm420", // IBM EBCDIC Arabic
	[NSNumber numberWithInt:20423],@"ibm423", // IBM EBCDIC Greek
	[NSNumber numberWithInt:20424],@"ibm424", // IBM EBCDIC Hebrew
	[NSNumber numberWithInt:20833],@"x-ebcdic-koreanextended", // IBM EBCDIC Korean Extended
	[NSNumber numberWithInt:20838],@"ibm-thai", // IBM EBCDIC Thai
	[NSNumber numberWithInt:20866],@"koi8-r", // Russian (KOI8-R); Cyrillic (KOI8-R)
	[NSNumber numberWithInt:20871],@"ibm871", // IBM EBCDIC Icelandic
	[NSNumber numberWithInt:20880],@"ibm880", // IBM EBCDIC Cyrillic Russian
	[NSNumber numberWithInt:20905],@"ibm905", // IBM EBCDIC Turkish
	[NSNumber numberWithInt:20924],@"ibm00924", // IBM EBCDIC Latin 1/Open System (1047 + Euro symbol)
	//[NSNumber numberWithInt:20932],@"euc-jp", // Japanese (JIS 0208-1990 and 0121-1990)
	[NSNumber numberWithInt:20936],@"x-cp20936", // Simplified Chinese (GB2312); Chinese Simplified (GB2312-80)
	[NSNumber numberWithInt:20949],@"x-cp20949", // Korean Wansung
	//[NSNumber numberWithInt:21025],@"cp1025", // IBM EBCDIC Cyrillic Serbian-Bulgarian
	//[NSNumber numberWithInt:21027],@"", // (deprecated)
	[NSNumber numberWithInt:21866],@"koi8-u", // Ukrainian (KOI8-U); Cyrillic (KOI8-U)
	[NSNumber numberWithInt:28591],@"iso-8859-1", // ISO 8859-1 Latin 1; Western European (ISO)
	[NSNumber numberWithInt:28592],@"iso-8859-2", // ISO 8859-2 Central European; Central European (ISO)
	[NSNumber numberWithInt:28593],@"iso-8859-3", // ISO 8859-3 Latin 3
	[NSNumber numberWithInt:28594],@"iso-8859-4", // ISO 8859-4 Baltic
	[NSNumber numberWithInt:28595],@"iso-8859-5", // ISO 8859-5 Cyrillic
	[NSNumber numberWithInt:28596],@"iso-8859-6", // ISO 8859-6 Arabic
	[NSNumber numberWithInt:28597],@"iso-8859-7", // ISO 8859-7 Greek
	[NSNumber numberWithInt:28598],@"iso-8859-8", // ISO 8859-8 Hebrew; Hebrew (ISO-Visual)
	[NSNumber numberWithInt:28599],@"iso-8859-9", // ISO 8859-9 Turkish
	[NSNumber numberWithInt:28603],@"iso-8859-13", // ISO 8859-13 Estonian
	[NSNumber numberWithInt:28605],@"iso-8859-15", // ISO 8859-15 Latin 9
	[NSNumber numberWithInt:29001],@"x-europa", // Europa 3
	[NSNumber numberWithInt:38598],@"iso-8859-8-i", // ISO 8859-8 Hebrew; Hebrew (ISO-Logical)
	//[NSNumber numberWithInt:50220],@"iso-2022-jp", // ISO 2022 Japanese with no halfwidth Katakana; Japanese (JIS)
	//[NSNumber numberWithInt:50221],@"csiso2022jp", // ISO 2022 Japanese with halfwidth Katakana; Japanese (JIS-Allow 1 byte Kana)
	[NSNumber numberWithInt:50222],@"iso-2022-jp", // ISO 2022 Japanese JIS X 0201-1989; Japanese (JIS-Allow 1 byte Kana - SO/SI)
	[NSNumber numberWithInt:50225],@"iso-2022-kr", // ISO 2022 Korean
	[NSNumber numberWithInt:50227],@"x-cp50227", // ISO 2022 Simplified Chinese; Chinese Simplified (ISO 2022)
	//[NSNumber numberWithInt:50229],@"", // ISO 2022 Traditional Chinese
	//[NSNumber numberWithInt:50930],@"", // EBCDIC Japanese (Katakana) Extended
	//[NSNumber numberWithInt:50931],@"", // EBCDIC US-Canada and Japanese
	//[NSNumber numberWithInt:50933],@"", // EBCDIC Korean Extended and Korean
	//[NSNumber numberWithInt:50935],@"", // EBCDIC Simplified Chinese Extended and Simplified Chinese
	//[NSNumber numberWithInt:50936],@"", // EBCDIC Simplified Chinese
	//[NSNumber numberWithInt:50937],@"", // EBCDIC US-Canada and Traditional Chinese
	//[NSNumber numberWithInt:50939],@"", // EBCDIC Japanese (Latin) Extended and Japanese
	[NSNumber numberWithInt:51932],@"euc-jp", // EUC Japanese
	[NSNumber numberWithInt:51932],@"euc_jp", // EUC Japanese
	[NSNumber numberWithInt:51932],@"eucjp", // EUC Japanese
	[NSNumber numberWithInt:51936],@"euc-cn", // EUC Simplified Chinese; Chinese Simplified (EUC)
	[NSNumber numberWithInt:51936],@"euc_cn", // EUC Simplified Chinese; Chinese Simplified (EUC)
	[NSNumber numberWithInt:51936],@"euccn", // EUC Simplified Chinese; Chinese Simplified (EUC)
	[NSNumber numberWithInt:51949],@"euc-kr", // EUC Korean
	[NSNumber numberWithInt:51949],@"euc_kr", // EUC Korean
	[NSNumber numberWithInt:51949],@"euckr", // EUC Korean
	//[NSNumber numberWithInt:51950],@"", // EUC Traditional Chinese
	[NSNumber numberWithInt:52936],@"hz-gb-2312", // HZ-GB2312 Simplified Chinese; Chinese Simplified (HZ)
	[NSNumber numberWithInt:54936],@"gb18030", // Windows XP and later: GB18030 Simplified Chinese (4 byte); Chinese Simplified (GB18030)
	[NSNumber numberWithInt:57002],@"x-iscii-de", // ISCII Devanagari
	[NSNumber numberWithInt:57003],@"x-iscii-be", // ISCII Bengali
	[NSNumber numberWithInt:57004],@"x-iscii-ta", // ISCII Tamil
	[NSNumber numberWithInt:57005],@"x-iscii-te", // ISCII Telugu
	[NSNumber numberWithInt:57006],@"x-iscii-as", // ISCII Assamese
	[NSNumber numberWithInt:57007],@"x-iscii-or", // ISCII Oriya
	[NSNumber numberWithInt:57008],@"x-iscii-ka", // ISCII Kannada
	[NSNumber numberWithInt:57009],@"x-iscii-ma", // ISCII Malayalam
	[NSNumber numberWithInt:57010],@"x-iscii-gu", // ISCII Gujarati
	[NSNumber numberWithInt:57011],@"x-iscii-pa", // ISCII Punjabi
	[NSNumber numberWithInt:65000],@"utf-7", // Unicode (UTF-7)
	[NSNumber numberWithInt:65001],@"utf-8", // Unicode (UTF-8)
	[NSNumber numberWithInt:65001],@"utf8", // Unicode (UTF-8)
	//[NSNumber numberWithInt:],@"x-euc-tw", // Unsupported.
	//[NSNumber numberWithInt:],@"ISO-2022-CN", // Unsupported.
	//[NSNumber numberWithInt:],@"TIS-620", // Unsupported, mostly same as iso-8859-11.
	//[NSNumber numberWithInt:],@"X-ISO-10646-UCS-4-2143", // Unsupported.
	//[NSNumber numberWithInt:],@"X-ISO-10646-UCS-4-3412", // Unsupported.
	nil];

	return dictionary;
}

static NSDictionary *DescriptionForWindowsCodePageDictionary()
{
	static NSDictionary *dictionary=nil;
	if(!dictionary) dictionary=[[NSDictionary alloc] initWithObjectsAndKeys:
	@"IBM EBCDIC US-Canada",[NSNumber numberWithInt:37],
	@"OEM United States",[NSNumber numberWithInt:437],
	@"IBM EBCDIC International",[NSNumber numberWithInt:500],
	@"Arabic (ASMO 708)",[NSNumber numberWithInt:708],
	@"Arabic (ASMO-449+, BCON V4)",[NSNumber numberWithInt:709],
	@"Arabic - Transparent Arabic",[NSNumber numberWithInt:710],
	@"Arabic (Transparent ASMO); Arabic (DOS)",[NSNumber numberWithInt:720],
	@"OEM Greek (formerly 437G); Greek (DOS)",[NSNumber numberWithInt:737],
	@"OEM Baltic; Baltic (DOS)",[NSNumber numberWithInt:775],
	@"OEM Multilingual Latin 1; Western European (DOS)",[NSNumber numberWithInt:850],
	@"OEM Latin 2; Central European (DOS)",[NSNumber numberWithInt:852],
	@"OEM Cyrillic (primarily Russian)",[NSNumber numberWithInt:855],
	@"OEM Turkish; Turkish (DOS)",[NSNumber numberWithInt:857],
	@"OEM Multilingual Latin 1 + Euro symbol",[NSNumber numberWithInt:858],
	@"OEM Portuguese; Portuguese (DOS)",[NSNumber numberWithInt:860],
	@"OEM Icelandic; Icelandic (DOS)",[NSNumber numberWithInt:861],
	@"OEM Hebrew; Hebrew (DOS)",[NSNumber numberWithInt:862],
	@"OEM French Canadian; French Canadian (DOS)",[NSNumber numberWithInt:863],
	@"OEM Arabic; Arabic (864)",[NSNumber numberWithInt:864],
	@"OEM Nordic; Nordic (DOS)",[NSNumber numberWithInt:865],
	@"OEM Russian; Cyrillic (DOS)",[NSNumber numberWithInt:866],
	@"OEM Modern Greek; Greek, Modern (DOS)",[NSNumber numberWithInt:869],
	@"IBM EBCDIC Multilingual/ROECE (Latin 2); IBM EBCDIC Multilingual Latin 2",[NSNumber numberWithInt:870],
	@"ANSI/OEM Thai (same as 28605, ISO 8859-15); Thai (Windows)",[NSNumber numberWithInt:874],
	@"IBM EBCDIC Greek Modern",[NSNumber numberWithInt:875],
	@"ANSI/OEM Japanese; Japanese (Shift-JIS)",[NSNumber numberWithInt:932],
	@"ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)",[NSNumber numberWithInt:936],
	@"ANSI/OEM Korean (Unified Hangul Code)",[NSNumber numberWithInt:949],
	@"ANSI/OEM Traditional Chinese (Taiwan; Hong Kong SAR, PRC); Chinese Traditional (Big5)",[NSNumber numberWithInt:950],
	@"IBM EBCDIC Turkish (Latin 5)",[NSNumber numberWithInt:1026],
	@"IBM EBCDIC Latin 1/Open System",[NSNumber numberWithInt:1047],
	@"IBM EBCDIC US-Canada (037 + Euro symbol); IBM EBCDIC (US-Canada-Euro)",[NSNumber numberWithInt:1140],
	@"IBM EBCDIC Germany (20273 + Euro symbol); IBM EBCDIC (Germany-Euro)",[NSNumber numberWithInt:1141],
	@"IBM EBCDIC Denmark-Norway (20277 + Euro symbol); IBM EBCDIC (Denmark-Norway-Euro)",[NSNumber numberWithInt:1142],
	@"IBM EBCDIC Finland-Sweden (20278 + Euro symbol); IBM EBCDIC (Finland-Sweden-Euro)",[NSNumber numberWithInt:1143],
	@"IBM EBCDIC Italy (20280 + Euro symbol); IBM EBCDIC (Italy-Euro)",[NSNumber numberWithInt:1144],
	@"IBM EBCDIC Latin America-Spain (20284 + Euro symbol); IBM EBCDIC (Spain-Euro)",[NSNumber numberWithInt:1145],
	@"IBM EBCDIC United Kingdom (20285 + Euro symbol); IBM EBCDIC (UK-Euro)",[NSNumber numberWithInt:1146],
	@"IBM EBCDIC France (20297 + Euro symbol); IBM EBCDIC (France-Euro)",[NSNumber numberWithInt:1147],
	@"IBM EBCDIC International (500 + Euro symbol); IBM EBCDIC (International-Euro)",[NSNumber numberWithInt:1148],
	@"IBM EBCDIC Icelandic (20871 + Euro symbol); IBM EBCDIC (Icelandic-Euro)",[NSNumber numberWithInt:1149],
	@"Unicode UTF-16, little endian byte order (BMP of ISO 10646); available only to managed applications",[NSNumber numberWithInt:1200],
	@"Unicode UTF-16, big endian byte order; available only to managed applications",[NSNumber numberWithInt:1201],
	@"ANSI Central European; Central European (Windows)",[NSNumber numberWithInt:1250],
	@"ANSI Cyrillic; Cyrillic (Windows)",[NSNumber numberWithInt:1251],
	@"ANSI Latin 1; Western European (Windows)",[NSNumber numberWithInt:1252],
	@"ANSI Greek; Greek (Windows)",[NSNumber numberWithInt:1253],
	@"ANSI Turkish; Turkish (Windows)",[NSNumber numberWithInt:1254],
	@"ANSI Hebrew; Hebrew (Windows)",[NSNumber numberWithInt:1255],
	@"ANSI Arabic; Arabic (Windows)",[NSNumber numberWithInt:1256],
	@"ANSI Baltic; Baltic (Windows)",[NSNumber numberWithInt:1257],
	@"ANSI/OEM Vietnamese; Vietnamese (Windows)",[NSNumber numberWithInt:1258],
	@"Korean (Johab)",[NSNumber numberWithInt:1361],
	@"MAC Roman; Western European (Mac)",[NSNumber numberWithInt:10000],
	@"Japanese (Mac)",[NSNumber numberWithInt:10001],
	@"MAC Traditional Chinese (Big5); Chinese Traditional (Mac)",[NSNumber numberWithInt:10002],
	@"Korean (Mac)",[NSNumber numberWithInt:10003],
	@"Arabic (Mac)",[NSNumber numberWithInt:10004],
	@"Hebrew (Mac)",[NSNumber numberWithInt:10005],
	@"Greek (Mac)",[NSNumber numberWithInt:10006],
	@"Cyrillic (Mac)",[NSNumber numberWithInt:10007],
	@"MAC Simplified Chinese (GB 2312); Chinese Simplified (Mac)",[NSNumber numberWithInt:10008],
	@"Romanian (Mac)",[NSNumber numberWithInt:10010],
	@"Ukrainian (Mac)",[NSNumber numberWithInt:10017],
	@"Thai (Mac)",[NSNumber numberWithInt:10021],
	@"MAC Latin 2; Central European (Mac)",[NSNumber numberWithInt:10029],
	@"Icelandic (Mac)",[NSNumber numberWithInt:10079],
	@"Turkish (Mac)",[NSNumber numberWithInt:10081],
	@"Croatian (Mac)",[NSNumber numberWithInt:10082],
	@"Unicode UTF-32, little endian byte order; available only to managed applications",[NSNumber numberWithInt:12000],
	@"Unicode UTF-32, big endian byte order; available only to managed applications",[NSNumber numberWithInt:12001],
	@"CNS Taiwan; Chinese Traditional (CNS)",[NSNumber numberWithInt:20000],
	@"TCA Taiwan",[NSNumber numberWithInt:20001],
	@"Eten Taiwan; Chinese Traditional (Eten)",[NSNumber numberWithInt:20002],
	@"IBM5550 Taiwan",[NSNumber numberWithInt:20003],
	@"TeleText Taiwan",[NSNumber numberWithInt:20004],
	@"Wang Taiwan",[NSNumber numberWithInt:20005],
	@"IA5 (IRV International Alphabet No. 5, 7-bit); Western European (IA5)",[NSNumber numberWithInt:20105],
	@"IA5 German (7-bit)",[NSNumber numberWithInt:20106],
	@"IA5 Swedish (7-bit)",[NSNumber numberWithInt:20107],
	@"IA5 Norwegian (7-bit)",[NSNumber numberWithInt:20108],
	@"US-ASCII (7-bit)",[NSNumber numberWithInt:20127],
	@"T.61",[NSNumber numberWithInt:20261],
	@"ISO 6937 Non-Spacing Accent",[NSNumber numberWithInt:20269],
	@"IBM EBCDIC Germany",[NSNumber numberWithInt:20273],
	@"IBM EBCDIC Denmark-Norway",[NSNumber numberWithInt:20277],
	@"IBM EBCDIC Finland-Sweden",[NSNumber numberWithInt:20278],
	@"IBM EBCDIC Italy",[NSNumber numberWithInt:20280],
	@"IBM EBCDIC Latin America-Spain",[NSNumber numberWithInt:20284],
	@"IBM EBCDIC United Kingdom",[NSNumber numberWithInt:20285],
	@"IBM EBCDIC Japanese Katakana Extended",[NSNumber numberWithInt:20290],
	@"IBM EBCDIC France",[NSNumber numberWithInt:20297],
	@"IBM EBCDIC Arabic",[NSNumber numberWithInt:20420],
	@"IBM EBCDIC Greek",[NSNumber numberWithInt:20423],
	@"IBM EBCDIC Hebrew",[NSNumber numberWithInt:20424],
	@"IBM EBCDIC Korean Extended",[NSNumber numberWithInt:20833],
	@"IBM EBCDIC Thai",[NSNumber numberWithInt:20838],
	@"Russian (KOI8-R); Cyrillic (KOI8-R)",[NSNumber numberWithInt:20866],
	@"IBM EBCDIC Icelandic",[NSNumber numberWithInt:20871],
	@"IBM EBCDIC Cyrillic Russian",[NSNumber numberWithInt:20880],
	@"IBM EBCDIC Turkish",[NSNumber numberWithInt:20905],
	@"IBM EBCDIC Latin 1/Open System (1047 + Euro symbol)",[NSNumber numberWithInt:20924],
	@"Japanese (JIS 0208-1990 and 0121-1990)",[NSNumber numberWithInt:20932],
	@"Simplified Chinese (GB2312); Chinese Simplified (GB2312-80)",[NSNumber numberWithInt:20936],
	@"Korean Wansung",[NSNumber numberWithInt:20949],
	@"IBM EBCDIC Cyrillic Serbian-Bulgarian",[NSNumber numberWithInt:21025],
	@"(deprecated)",[NSNumber numberWithInt:21027],
	@"Ukrainian (KOI8-U); Cyrillic (KOI8-U)",[NSNumber numberWithInt:21866],
	@"ISO 8859-1 Latin 1; Western European (ISO)",[NSNumber numberWithInt:28591],
	@"ISO 8859-2 Central European; Central European (ISO)",[NSNumber numberWithInt:28592],
	@"ISO 8859-3 Latin 3",[NSNumber numberWithInt:28593],
	@"ISO 8859-4 Baltic",[NSNumber numberWithInt:28594],
	@"ISO 8859-5 Cyrillic",[NSNumber numberWithInt:28595],
	@"ISO 8859-6 Arabic",[NSNumber numberWithInt:28596],
	@"ISO 8859-7 Greek",[NSNumber numberWithInt:28597],
	@"ISO 8859-8 Hebrew; Hebrew (ISO-Visual)",[NSNumber numberWithInt:28598],
	@"ISO 8859-9 Turkish",[NSNumber numberWithInt:28599],
	@"ISO 8859-13 Estonian",[NSNumber numberWithInt:28603],
	@"ISO 8859-15 Latin 9",[NSNumber numberWithInt:28605],
	@"Europa 3",[NSNumber numberWithInt:29001],
	@"ISO 8859-8 Hebrew; Hebrew (ISO-Logical)",[NSNumber numberWithInt:38598],
	@"ISO 2022 Japanese with no halfwidth Katakana; Japanese (JIS)",[NSNumber numberWithInt:50220],
	@"ISO 2022 Japanese with halfwidth Katakana; Japanese (JIS-Allow 1 byte Kana)",[NSNumber numberWithInt:50221],
	@"ISO 2022 Japanese JIS X 0201-1989; Japanese (JIS-Allow 1 byte Kana - SO/SI)",[NSNumber numberWithInt:50222],
	@"ISO 2022 Korean",[NSNumber numberWithInt:50225],
	@"ISO 2022 Simplified Chinese; Chinese Simplified (ISO 2022)",[NSNumber numberWithInt:50227],
	@"ISO 2022 Traditional Chinese",[NSNumber numberWithInt:50229],
	@"EBCDIC Japanese (Katakana) Extended",[NSNumber numberWithInt:50930],
	@"EBCDIC US-Canada and Japanese",[NSNumber numberWithInt:50931],
	@"EBCDIC Korean Extended and Korean",[NSNumber numberWithInt:50933],
	@"EBCDIC Simplified Chinese Extended and Simplified Chinese",[NSNumber numberWithInt:50935],
	@"EBCDIC Simplified Chinese",[NSNumber numberWithInt:50936],
	@"EBCDIC US-Canada and Traditional Chinese",[NSNumber numberWithInt:50937],
	@"EBCDIC Japanese (Latin) Extended and Japanese",[NSNumber numberWithInt:50939],
	@"EUC Japanese",[NSNumber numberWithInt:51932],
	@"EUC Simplified Chinese; Chinese Simplified (EUC)",[NSNumber numberWithInt:51936],
	@"EUC Korean",[NSNumber numberWithInt:51949],
	@"EUC Traditional Chinese",[NSNumber numberWithInt:51950],
	@"HZ-GB2312 Simplified Chinese; Chinese Simplified (HZ)",[NSNumber numberWithInt:52936],
	@"Windows XP and later: GB18030 Simplified Chinese (4 byte); Chinese Simplified (GB18030)",[NSNumber numberWithInt:54936],
	@"ISCII Devanagari",[NSNumber numberWithInt:57002],
	@"ISCII Bengali",[NSNumber numberWithInt:57003],
	@"ISCII Tamil",[NSNumber numberWithInt:57004],
	@"ISCII Telugu",[NSNumber numberWithInt:57005],
	@"ISCII Assamese",[NSNumber numberWithInt:57006],
	@"ISCII Oriya",[NSNumber numberWithInt:57007],
	@"ISCII Kannada",[NSNumber numberWithInt:57008],
	@"ISCII Malayalam",[NSNumber numberWithInt:57009],
	@"ISCII Gujarati",[NSNumber numberWithInt:57010],
	@"ISCII Punjabi",[NSNumber numberWithInt:57011],
	@"Unicode (UTF-7)",[NSNumber numberWithInt:65000],
	@"Unicode (UTF-8)",[NSNumber numberWithInt:65001],
	nil];

	return dictionary;
}
