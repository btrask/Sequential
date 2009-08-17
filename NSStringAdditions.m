/* Copyright © 2007-2009, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "NSStringAdditions.h"

@implementation NSString(AEAdditions)

#pragma mark -NSString(AEAdditions)

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
	SInt32 result = NSOrderedSame;
	(void)UCCompareTextDefault(kUCCollateComposeInsensitiveMask | kUCCollateWidthInsensitiveMask | kUCCollateCaseInsensitiveMask | kUCCollateDigitsOverrideMask | kUCCollateDigitsAsNumberMask | kUCCollatePunctuationSignificantMask, str1, length1, str2, length2, NULL, &result);
	return (NSComparisonResult)result;
}
- (NSString *)AE_stringByReplacingOccurrencesOfCharactersInSet:(NSCharacterSet *)set withString:(NSString *)replacement
{
	NSMutableString *const result = [NSMutableString string];
	NSScanner *const scanner = [NSScanner scannerWithString:self];
	[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@""]];
	while(![scanner isAtEnd]) {
		NSString *substring = nil;
		if([scanner scanUpToCharactersFromSet:set intoString:&substring] && substring) [result appendString:substring];
		if([scanner scanCharactersFromSet:set intoString:NULL] && replacement) [result appendString:replacement];
	}
	return result;
}

#pragma mark -

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

#pragma mark -

- (NSArray *)AE_searchTerms
{
	NSArray *const components = [self componentsSeparatedByString:@" "];
	NSMutableArray *const terms = [NSMutableArray arrayWithCapacity:[components count]];
	NSString *component;
	NSEnumerator *const componentEnum = [components objectEnumerator];
	while((component = [componentEnum nextObject])) {
		if([component isEqualToString:@""]) continue;
		NSScanner *const scanner = [NSScanner localizedScannerWithString:component];
		int index;
		if([scanner scanInt:&index] && [scanner isAtEnd] && index != INT_MAX && index != INT_MIN) [terms addObject:[NSNumber numberWithInt:index]];
		else [terms addObject:component];
	}
	return terms;
}
- (BOOL)AE_matchesSearchTerms:(NSArray *)terms
{
	NSScanner *const scanner = [NSScanner localizedScannerWithString:self];
	[scanner setCharactersToBeSkipped:[[NSCharacterSet decimalDigitCharacterSet] invertedSet]];
	id term;
	NSEnumerator *const termEnum = [terms objectEnumerator];
	while((term = [termEnum nextObject])) {
		if([term isKindOfClass:[NSNumber class]]) {
			[scanner setScanLocation:0];
			BOOL foundNumber = NO;
			while(!foundNumber && ![scanner isAtEnd]) {
				int index;
				if(![scanner scanInt:&index]) return NO;
				if([term intValue] == index) foundNumber = YES;
			}
			if(!foundNumber) return NO;
		} else {
			if([self rangeOfString:term options:NSCaseInsensitiveSearch].location == NSNotFound) return NO;
		}
	}
	return YES;
}

@end
