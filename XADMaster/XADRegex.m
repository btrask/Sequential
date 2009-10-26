#import "XADRegex.h"

static NSString *nullstring=nil;

@implementation XADRegex

+(XADRegex *)regexWithPattern:(NSString *)pattern options:(int)options
{ return [[[XADRegex alloc] initWithPattern:pattern options:options] autorelease]; }

+(XADRegex *)regexWithPattern:(NSString *)pattern
{ return [[[XADRegex alloc] initWithPattern:pattern options:0] autorelease]; }

+(NSString *)null { return nullstring; }

+(void)initialize
{
	if(!nullstring) nullstring=[NSMutableString stringWithString:@""];
}

-(id)initWithPattern:(NSString *)pattern options:(int)options
{
	if(self=[super init])
	{
		patternstring=[patternstring retain];
		currdata=nil;
		matches=NULL;

		int err=regcomp(&preg,[pattern UTF8String],options|REG_EXTENDED);
		if(err)
		{
			[self autorelease];
			char errbuf[256];
			regerror(err,&preg,errbuf,sizeof(errbuf));
			[NSException raise:@"XADRegexException" format:@"Could not compile regex \"%@\": %s",pattern,errbuf];
		}

		matches=calloc(sizeof(regmatch_t),preg.re_nsub+1);
		if(!matches)
		{
			[self autorelease];
			[NSException raise:NSMallocException format:@"Out of memory when creating regex \"%@\"",pattern];
		}
	}
	return self;
}

-(void)dealloc
{
	[patternstring release];
	regfree(&preg);
	[currdata release];
	[super dealloc];
}

-(void)beginMatchingString:(NSString *)string { [self beginMatchingData:[string dataUsingEncoding:NSUTF8StringEncoding]]; }

-(void)beginMatchingData:(NSData *)data { [self beginMatchingData:data range:NSMakeRange(0,[data length])]; }

-(void)beginMatchingData:(NSData *)data range:(NSRange)range
{
	matchrange=range;
	if(data==currdata) return;
	[currdata release];
	currdata=[data retain];
}

-(void)finishMatching { [currdata release]; currdata=nil; }

-(BOOL)matchNext
{
	matches[0].rm_so=matchrange.location;
	matches[0].rm_eo=matchrange.location+matchrange.length;
	if(regexec(&preg,[currdata bytes],preg.re_nsub+1,matches,REG_STARTEND)==0)
	{
		matchrange.length-=matches[0].rm_eo-matchrange.location;
		matchrange.location=matches[0].rm_eo;
		return YES;
	}
	[self finishMatching];
	return NO;
}

-(NSString *)stringForMatch:(int)n
{
	if(n>preg.re_nsub||n<0) [NSException raise:NSRangeException format:@"Index %d out of range for regex \"%@\"",n,self];
 	if(matches[n].rm_so==-1&&matches[n].rm_eo==-1) return nil;
	return [[[NSString alloc] initWithBytes:[currdata bytes]+matches[n].rm_so
	length:matches[n].rm_eo-matches[n].rm_so encoding:NSUTF8StringEncoding] autorelease];
}

-(NSArray *)allMatches
{
	NSMutableArray *array=[NSMutableArray arrayWithCapacity:preg.re_nsub+1];
	for(int i=0;i<=preg.re_nsub;i++)
	{
		NSString *str=[self stringForMatch:i];
		[array addObject:str?str:nullstring];
	}
	return [NSArray arrayWithArray:array];
}



-(BOOL)matchesString:(NSString *)string
{
	[self beginMatchingString:string];
	BOOL res=[self matchNext];
	[self finishMatching];
	return res;
}

-(NSString *)matchedSubstringOfString:(NSString *)string
{
	[self beginMatchingString:string];
	NSString *res=nil;
	if([self matchNext]) res=[self stringForMatch:0];
	[self finishMatching];
	return res;
}

-(NSArray *)capturedSubstringsOfString:(NSString *)string
{
	[self beginMatchingString:string];
	NSArray *res=nil;
	if([self matchNext]) res=[self allMatches];
	[self finishMatching];
	return res;
}

-(NSArray *)allMatchedSubstringsOfString:(NSString *)string
{
	[self beginMatchingString:string];
	NSMutableArray *array=[NSMutableArray array];
	while([self matchNext]) [array addObject:[self stringForMatch:0]];
	[self finishMatching];
	return [NSArray arrayWithArray:array];
}

-(NSArray *)allCapturedSubstringsOfString:(NSString *)string
{
	[self beginMatchingString:string];
	NSMutableArray *array=[NSMutableArray array];
	while([self matchNext]) [array addObject:[self allMatches]];
	[self finishMatching];
	return [NSArray arrayWithArray:array];
}

-(NSArray *)componentsOfSeparatedString:(NSString *)string
{
	[self beginMatchingString:string];
	NSMutableArray *array=[NSMutableArray array];

	regoff_t prevstart=0;
	const char *bytes=[currdata bytes];
	while([self matchNext])
	{
		[array addObject:[[[NSString alloc] initWithBytes:bytes+prevstart length:matches[0].rm_so-prevstart
		encoding:NSUTF8StringEncoding] autorelease]];
		prevstart=matches[0].rm_eo;
	}
	[array addObject:[[[NSString alloc] initWithBytes:bytes+prevstart length:[currdata length]-prevstart
	encoding:NSUTF8StringEncoding] autorelease]];

	[self finishMatching];
	return [NSArray arrayWithArray:array];
}

-(NSString *)pattern { return patternstring; }

-(NSString *)description { return patternstring; }

@end



@implementation NSString (XADRegex)

-(BOOL)matchedByPattern:(NSString *)pattern { return [self matchedByPattern:pattern options:0]; }
-(BOOL)matchedByPattern:(NSString *)pattern options:(int)options
{ return [[XADRegex regexWithPattern:pattern options:options] matchesString:self]; }

-(NSString *)substringMatchedByPattern:(NSString *)pattern { return [self substringMatchedByPattern:pattern options:0]; }
-(NSString *)substringMatchedByPattern:(NSString *)pattern options:(int)options
{ return [[XADRegex regexWithPattern:pattern options:options] matchedSubstringOfString:self]; }

-(NSArray *)substringsCapturedByPattern:(NSString *)pattern { return [self substringsCapturedByPattern:pattern options:0]; }
-(NSArray *)substringsCapturedByPattern:(NSString *)pattern options:(int)options
{ return [[XADRegex regexWithPattern:pattern options:options] capturedSubstringsOfString:self]; }

-(NSArray *)allSubstringsMatchedByPattern:(NSString *)pattern { return [self allSubstringsMatchedByPattern:pattern options:0]; }
-(NSArray *)allSubstringsMatchedByPattern:(NSString *)pattern options:(int)options
{ return [[XADRegex regexWithPattern:pattern options:options] allMatchedSubstringsOfString:self]; }

-(NSArray *)allSubstringsCapturedByPattern:(NSString *)pattern { return [self allSubstringsCapturedByPattern:pattern options:0]; }
-(NSArray *)allSubstringsCapturedByPattern:(NSString *)pattern options:(int)options
{ return [[XADRegex regexWithPattern:pattern options:options] allCapturedSubstringsOfString:self]; }

-(NSArray *)componentsSeparatedByPattern:(NSString *)pattern { return [self componentsSeparatedByPattern:pattern options:0]; }
-(NSArray *)componentsSeparatedByPattern:(NSString *)pattern options:(int)options
{ return [[XADRegex regexWithPattern:pattern options:options] componentsOfSeparatedString:self]; }

-(NSString *)escapedPattern
{
	int len=[self length];
	NSMutableString *escaped=[NSMutableString stringWithCapacity:len];

	for(int i=0;i<len;i++)
	{
		unichar c=[self characterAtIndex:i];
		if(c=='^'||c=='.'||c=='['||c=='$'||c=='('||c==')'
		||c=='|'||c=='*'||c=='+'||c=='?'||c=='{'||c=='\\') [escaped appendFormat:@"\\%C",c];
		else [escaped appendFormat:@"%C",c];
	}
	return [NSString stringWithString:escaped];
}

@end

