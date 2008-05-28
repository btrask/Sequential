#import "NSStringAdditions.h"
#import <fcntl.h>
#import <sys/time.h>
#import <sys/resource.h>

@implementation NSString (AEAdditions)

- (NSComparisonResult)AE_localizedCaseInsensitiveNumericCompare:(NSString *)aString
{
	static UniChar *str1 = NULL;
	static UniChar *str2 = NULL;
	static UniCharCount max1 = 0;
	static UniCharCount max2 = 0;
	UniCharCount const length1 = [self length], length2 = [aString length];
	if(max1 < length1) {
		max1 = length1;
		str1 = str1 ? realloc(str1, max1 * sizeof(UniChar)) : malloc(max1 * sizeof(UniChar));
	}
	if(max2 < length2) {
		max2 = length2;
		str2 = str2 ? realloc(str2, max2 * sizeof(UniChar)) : malloc(max2 * sizeof(UniChar));
	}
	NSAssert(str1 && str2, @"Couldn't allocate.");
	[self getCharacters:str1];
	[aString getCharacters:str2];
	SInt32 result;
	UCCompareTextDefault(kUCCollateComposeInsensitiveMask | kUCCollateWidthInsensitiveMask | kUCCollateCaseInsensitiveMask | kUCCollateDigitsOverrideMask | kUCCollateDigitsAsNumberMask | kUCCollatePunctuationSignificantMask, str1, length1, str2, length2, NULL, &result);
	return (NSComparisonResult)result;
}
- (int)AE_fileDescriptor
{
	char const *const rep = [self fileSystemRepresentation];
	int fd = open(rep, O_EVTONLY);
	if(-1 != fd) return fd;
	struct rlimit limit;
	if(getrlimit(RLIMIT_NOFILE, &limit)) return -1; // Couldn't get limit.
	limit.rlim_cur = MIN(limit.rlim_cur * 2, limit.rlim_max);
	if(setrlimit(RLIMIT_NOFILE, &limit)) return -1; // Couldn't change limit.
	return open(rep, O_EVTONLY);
}
- (NSString *)AE_firstPathComponent
{
	NSString *component;
	NSEnumerator *const componentEnum = [[self pathComponents] objectEnumerator];
	while((component = [componentEnum nextObject])) if(![component isEqualToString:@"/"]) return component;
	return @"";
}

- (NSURL *)AE_fileURL
{
	return [NSURL fileURLWithPath:self];
}
- (NSString *)AE_displayName
{
	NSString *displayName = nil;
	if(LSCopyDisplayNameForURL((CFURLRef)[self AE_fileURL], (CFStringRef *)&displayName) == noErr && displayName) return [displayName autorelease];
	return [[NSFileManager defaultManager] displayNameAtPath:self];
}

- (NSArray *)AE_searchTerms
{
	NSMutableArray *const terms = [[[self componentsSeparatedByString:@" "] mutableCopy] autorelease];
	[terms removeObject:@""];
	return terms;
}
- (BOOL)AE_matchesSearchTerms:(NSArray *)terms
{
	NSString *term;
	NSEnumerator *const termEnum = [terms objectEnumerator];
	while((term = [termEnum nextObject])) if([self rangeOfString:term options:NSCaseInsensitiveSearch].location == NSNotFound) return NO;
	return YES;
}

@end
