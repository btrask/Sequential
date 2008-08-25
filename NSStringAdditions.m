/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "NSStringAdditions.h"

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
