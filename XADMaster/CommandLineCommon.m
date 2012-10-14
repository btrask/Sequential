#import "CommandLineCommon.h"

#import "XADArchiveParser.h"
#import "XADArchiveParserDescriptions.h"
#import "XADString.h"
#import "NSStringPrinting.h"

#include <time.h>

#ifndef __MINGW32__
#import <unistd.h>
#endif

BOOL IsListRequest(NSString *encoding)
{
	if(!encoding) return NO;
	if([encoding caseInsensitiveCompare:@"list"]==NSOrderedSame) return YES;
	if([encoding caseInsensitiveCompare:@"help"]==NSOrderedSame) return YES;
	return NO;
}

void PrintEncodingList()
{
	NSEnumerator *enumerator=[[XADString availableEncodingNames] objectEnumerator];
	NSArray *encodingarray;
	while((encodingarray=[enumerator nextObject]))
	{
		NSString *description=[encodingarray objectAtIndex:0];
		if((id)description==[NSNull null]||[description length]==0) description=nil;

		NSString *encoding=[encodingarray objectAtIndex:1];

		NSString *aliases=nil;
		if([encodingarray count]>2) aliases=[[encodingarray subarrayWithRange:
		NSMakeRange(2,[encodingarray count]-2)] componentsJoinedByString:@", "];

		[@"  * " print];

		[encoding print];

		if(aliases)
		{
			[@" (" print];
			[aliases print];
			[@")" print];
		}

		if(description)
		{
			[@": " print];
			[description print];
		}

		[@"\n" print];
	}
}




NSString *ShortInfoLineForEntryWithDictionary(NSDictionary *dict)
{
	NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
	BOOL isdir=dirnum && [dirnum boolValue];

	NSString *name=[[dict objectForKey:XADFileNameKey] string];
	name=[name stringByEscapingControlCharacters];

	if(isdir) return [name stringByAppendingString:@"/"]; // TODO: What about Windows?
	else return name;
}

NSString *MediumInfoLineForEntryWithDictionary(NSDictionary *dict)
{
	NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *linknum=[dict objectForKey:XADIsLinkKey];
	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	NSNumber *corruptednum=[dict objectForKey:XADIsCorruptedKey];
	NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
//	NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];

	BOOL isdir=dirnum && [dirnum boolValue];
	BOOL islink=linknum && [linknum boolValue];
	BOOL isres=resnum && [resnum boolValue];
	BOOL iscorrupted=corruptednum && [corruptednum boolValue];
	BOOL hassize=(sizenum!=nil);

	NSString *name=[[dict objectForKey:XADFileNameKey] string];
	name=[name stringByEscapingControlCharacters];

	NSMutableString *string=[NSMutableString stringWithString:name];

	if(isdir) [string appendString:@"/"]; // TODO: What about Windows?

	NSMutableArray *tags=[NSMutableArray array];

	if(isdir) [tags addObject:@"dir"];
	else if(islink) [tags addObject:@"link"];
	else if(hassize) [tags addObject:[NSString stringWithFormat:@"%lld B",[sizenum longLongValue]]];

	if(isres) [tags addObject:@"rsrc"];

	if(iscorrupted) [tags addObject:@"corrupted"];

	if([tags count])
	{
		[string appendString:@"  ("];
		[string appendString:[tags componentsJoinedByString:@", "]];
		[string appendString:@")"];
	}

	return string;
}

static NSString *CodeForCompressionName(NSString *compname);

NSString *LongInfoLineForEntryWithDictionary(NSDictionary *dict,XADArchiveParser *parser)
{
	NSNumber *indexnum=[dict objectForKey:XADIndexKey];
	NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *linknum=[dict objectForKey:XADIsLinkKey];
	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	NSNumber *encryptednum=[dict objectForKey:XADIsEncryptedKey];
	//NSNumber *corruptednum=[dict objectForKey:XADIsCorruptedKey];
	BOOL isdir=dirnum && [dirnum boolValue];
	BOOL islink=linknum && [linknum boolValue];
	BOOL isres=resnum && [resnum boolValue];
	BOOL isencrypted=encryptednum && [encryptednum boolValue];
	//BOOL iscorrupted=corruptednum && [corruptednum boolValue];

	NSObject *extattrs=[dict objectForKey:XADExtendedAttributesKey];
	// TODO: check for non-empty finder info &c
	BOOL hasextattrs=extattrs?YES:NO;

	NSNumber *sizenum=[dict objectForKey:XADFileSizeKey];
	NSNumber *compsizenum=[dict objectForKey:XADCompressedSizeKey];
	off_t size=sizenum?[sizenum longLongValue]:0;
	off_t compsize=compsizenum?[compsizenum longLongValue]:0;

	NSString *sizestr;
	if(sizenum)
	{
		sizestr=[NSString stringWithFormat:@"%11lld",[sizenum longLongValue]];
	}
	else
	{
		sizestr=@" ----------";
	}

	NSString *compstr;
	if(size&&compsize)
	{
		double compression=100*(1-(double)compsize/(double)size);
		if(compression<=-100) compstr=[NSString stringWithFormat:@"%5.0f%%",compression];
		else compstr=[NSString stringWithFormat:@"%5.1f%%",compression];
	}
	else
	{
		compstr=@" -----";
	}

	XADString *compname=[dict objectForKey:XADCompressionNameKey];
	NSString *compcode;
	if(compname)
	{
		compcode=CodeForCompressionName([compname string]);
		if([compcode length]<4) compcode=[NSString stringWithFormat:@"%@%s",compcode,"    "+[compcode length]];
	}
	else
	{
		compcode=@"----";
	}

	NSDate *date=[dict objectForKey:XADLastModificationDateKey];
	if(!date) date=[dict objectForKey:XADCreationDateKey];
	if(!date) date=[dict objectForKey:XADLastAccessDateKey];

	NSString *datestr;
	if(date)
	{
		#ifndef __COCOTRON__
		NSDateFormatter *formatter=[[NSDateFormatter new] autorelease];
		[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
		[formatter setDateFormat:@"yyyy-MM-dd HH:mm"];
		datestr=[formatter stringFromDate:date];
		#else
		NSDateFormatter *formatter=[[NSDateFormatter new] autorelease];
		[formatter setDateFormat:@"%Y-%m-%d %H:%M"];
		datestr=[formatter stringFromDate:date];
		#endif
	}
	else
	{
		datestr=@"----------------";
	}

	NSString *name=[[dict objectForKey:XADFileNameKey] string];
	name=[name stringByEscapingControlCharacters];

	NSString *linkstr=@"";
	if(islink)
	{
		XADError error;
		XADString *link=[parser linkDestinationForDictionary:dict error:&error];
		if(link) linkstr=[NSString stringWithFormat:@" -> %@",link];
	}

	return [NSString stringWithFormat:
	@"%3d. %c%c%c%c%c %@ %@  %@  %@  %@%s%@",
	[indexnum intValue],
	isdir?'D':'-',
	isres?'R':'-',
	islink?'L':'-',
	isencrypted?'E':'-',
	hasextattrs?'@':'-',
	sizestr,
	compstr,
	compcode,
	datestr,
	name,
	isdir?"/":"",
	linkstr];
}

static NSMutableDictionary *codeforname=nil;
static NSMutableSet *usedcodes;
static NSDictionary *abbreviations=nil;

static NSString *CodeForCompressionName(NSString *compname)
{
	if(!codeforname) codeforname=[NSMutableDictionary new];
	NSString *cachedcode=[codeforname objectForKey:compname];
	if(cachedcode) return cachedcode;

	if(!usedcodes) usedcodes=[NSMutableSet new];
	if(!abbreviations) abbreviations=[[NSDictionary alloc] initWithObjectsAndKeys:
		@"Df64",@"Deflate64",
		@"LZBC",@"LZMA+BCJ",
		@"LZB2",@"LZMA+BCJ2",
		@"PPBC",@"PPMd+BCJ",
		@"PPB2",@"PPMd+BCJ2",
		@"Ftst",@"Fastest",
		@"MSZP",@"MSZIP",
		@"Qua0",@"Quantum:0",@"Qua1",@"Quantum:1",@"Qua2",@"Quantum:2",@"Qua3",@"Quantum:3",
		@"Qua4",@"Quantum:4",@"Qua5",@"Quantum:5",@"Qua6",@"Quantum:6",@"Qua7",@"Quantum:7",
		@"Qua8",@"Quantum:8",@"Qua9",@"Quantum:9",@"Qu10",@"Quantum:10",@"Qu11",@"Quantum:11",
		@"Qu12",@"Quantum:12",@"Qu13",@"Quantum:13",@"Qu14",@"Quantum:14",@"Qu15",@"Quantum:15",
		@"Qu16",@"Quantum:16",@"Qu17",@"Quantum:17",@"Qu18",@"Quantum:18",@"Qu19",@"Quantum:19",
		@"Qu20",@"Quantum:20",@"Qu21",@"Quantum:21",@"Qu22",@"Quantum:22",@"Qu23",@"Quantum:23",
		@"Qu24",@"Quantum:24",@"Qu25",@"Quantum:25",@"Qu26",@"Quantum:26",@"Qu27",@"Quantum:27",
		@"Qu28",@"Quantum:28",@"Qu29",@"Quantum:29",@"Qu30",@"Quantum:30",@"Qu31",@"Quantum:31",
		@"LZX0",@"LZX:0",@"LZX1",@"LZX:1",@"LZX2",@"LZX:2",@"LZX3",@"LZX:3",
		@"LZX4",@"LZX:4",@"LZX5",@"LZX:5",@"LZX6",@"LZX:6",@"LZX7",@"LZX:7",
		@"LZX8",@"LZX:8",@"LZX9",@"LZX:9",@"LZ10",@"LZX:10",@"LZ11",@"LZX:11",
		@"LZ12",@"LZX:12",@"LZ13",@"LZX:13",@"LZ14",@"LZX:14",@"LZ15",@"LZX:15",
		@"LZ16",@"LZX:16",@"LZ17",@"LZX:17",@"LZ18",@"LZX:18",@"LZ19",@"LZX:19",
		@"LZ20",@"LZX:20",@"LZ21",@"LZX:21",@"LZ22",@"LZX:22",@"LZ23",@"LZX:23",
		@"LZ24",@"LZX:24",@"LZ25",@"LZX:25",@"LZ26",@"LZX:26",@"LZ27",@"LZX:27",
		@"LZ28",@"LZX:28",@"LZ29",@"LZX:29",@"LZ30",@"LZX:30",@"LZ31",@"LZX:31",
		@"Mth1",@"Method 1",@"Mth2",@"Method 2",@"Mth3",@"Method 3",@"Mth4",@"Method 4",
		@"Mth5",@"Method 5",@"Mth6",@"Method 6",@"Mth7",@"Method 7",@"Mth8",@"Method 8",
		@"Mth9",@"Method 9",@"Mt10",@"Method 10",@"Mt11",@"Method 11",@"Mt12",@"Method 12",
		@"Mt13",@"Method 13",@"Mt14",@"Method 14",@"Mt15",@"Method 15",@"Mt16",@"Method 16",
		@"AD2",@"ADS/AD2",
		@"CPT",@"Compact Pro",
		@"AD1",@"AD/AD1",
		@"None",@"-lh0-",
		@"lh1",@"-lh1-",
		@"lh2",@"-lh2-",
		@"lh3",@"-lh3-",
		@"lh4",@"-lh4-",
		@"lh5",@"-lh5-",
		@"lh6",@"-lh6-",
		@"lh7",@"-lh7-",
		@"lzs",@"-lzs-",
		@"lz4",@"-lz4-",
		@"lz5",@"-lz5-",
		@"None",@"-pm0-",
		@"pm2",@"-pm2-",
		@"PPck",@"PowerPacker",
		@"Ft15",@"Fastest v1.5",@"Ft20",@"Fastest v2.0",@"Ft29",@"Fastest v2.9",
		@"Fs15",@"Fast v1.5",@"Fs20",@"Fast v2.0",@"Fs29",@"Fast v2.9",
		@"Nr15",@"Normal v1.5",@"Nr20",@"Normal v2.0",@"Nr29",@"Normal v2.9",
		@"Gd15",@"Good v1.5",@"Gd20",@"Good v2.0",@"Gd29",@"Good v2.9",
		@"Bs15",@"Best v1.5",@"Bs20",@"Best v2.0",@"Bs29",@"Best v2.9",
	nil];

	NSString *code=[abbreviations objectForKey:compname];
	if(!code)
	{
		if([compname length]<=4) code=compname;
		else code=[compname substringWithRange:NSMakeRange(0,4)];
	}

	if([usedcodes containsObject:code])
	{
		int i=2;
		do
		{
			unichar c[4];

			c[3]=i%10;
			if(i>=10) c[2]=(i/10)%10;
			else c[2]=[code characterAtIndex:2];
			if(i>=100) c[1]=(i/100)%10;
			else c[1]=[code characterAtIndex:1];
			if(i>=1000) c[0]=(i/1000)%10;
			else c[0]=[code characterAtIndex:0];
			if(i>=10000) return @"@@@@";
			i++;

			code=[NSString stringWithCharacters:c length:4];
		}
		while([usedcodes containsObject:code]);
	}

	[usedcodes addObject:code];
	[codeforname setObject:code forKey:compname];

	return code;
}

NSString *CompressionNameExplanationForLongInfo()
{
	NSMutableString *res=nil;

	NSEnumerator *enumerator=[[[codeforname allKeys] sortedArrayUsingSelector:@selector(compare:)] objectEnumerator];
	NSString *compname;
	while((compname=[enumerator nextObject]))
	{
		NSString *code=[codeforname objectForKey:compname];
		if([code isEqualToString:compname]) continue;

		if(res) [res appendFormat:@", %@=%@",code,compname];
		else res=[NSMutableString stringWithFormat:@"%@=%@",code,compname];
	}

	return res;
}




BOOL IsInteractive()
{
//	#ifdef __MINGW32__
//	return isatty(fileno(stdin))&&isatty(fileno(stdout));
//	#else
	return isatty(fileno(stdin))&&isatty(fileno(stdout));
//	#endif
}

int GetPromptCharacter()
{
	#ifdef __APPLE__
	fpurge(stdin);
	int c=getc(stdin);
	fpurge(stdin);
	#else
	// TODO: Handle purging.
	char c;
	if(scanf("%c%*c",&c)<1) return -1;
	#endif
	return c;
}

NSString *AskForPassword(NSString *prompt)
{
	[prompt print];
	fflush(stdout); // getpass() doesn't print its prompt to stdout.

	#ifdef __MINGW32__

	[@"Password (will be shown): " print];
	fflush(stdout);

	char pass[1024];
	fgets(pass,sizeof(pass),stdin);

	int length=strlen(pass);
	if(pass[length-1]=='\n')
	{
		pass[length-1]=0;
		if(pass[length-2]=='\r') pass[length-2]=0;
	}

	#else

	char *pass=getpass("Password (will not be shown): ");
	if(!pass) return nil;

	#endif

	return [NSString stringWithUTF8String:pass];
}
