/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "DOMNodeAdditions.h"

// Models
#import "PGResourceIdentifier.h"

@implementation DOMNode (AEAdditions)

- (void)AE_getLinkedResourceIdentifiers:(NSMutableArray *)array
        validSchemes:(NSArray *)schemes
        extensions:(NSArray *)exts
{
	DOMNodeList *const list = [self childNodes];
	unsigned i = 0;
	unsigned const count = [list length];
	for(; i < count; i++) [[list item:i] AE_getLinkedResourceIdentifiers:array validSchemes:schemes extensions:exts];
}
- (void)AE_getEmbeddedImageIdentifiers:(NSMutableArray *)array
{
	DOMNodeList *const list = [self childNodes];
	unsigned i = 0;
	unsigned const count = [list length];
	for(; i < count; i++) [[list item:i] AE_getEmbeddedImageIdentifiers:array];
}
- (NSString *)AE_stringValue
{
	AEWhitespace trailing = AENoWhitespace;
	return [self AE_stringValue:&trailing];
}
- (id)AE_ancestorThatRespondsTo:(SEL)aSelector
{
	return [self respondsToSelector:aSelector] ? self : [[self parentNode] AE_ancestorThatRespondsTo:aSelector];
}
- (BOOL)AE_pre
{
	if([[self nodeName] isEqual:@"PRE"]) return YES;
	return [[self parentNode] AE_pre];
}
- (NSString *)AE_stringValue:(inout AEWhitespace *)trailing
{
	return [self AE_stringValueOfChildren:trailing];
}
- (NSString *)AE_stringValueOfChildren:(inout AEWhitespace *)trailing
{
	NSMutableString *result = [NSMutableString string];
	unsigned i = 0;
	for(; i < [[self childNodes] length]; i++) [result appendString:[[[self childNodes] item:i] AE_stringValue:trailing]];
	return result;
}

@end

@implementation DOMHTMLAnchorElement (AEAdditions)

- (void)AE_getLinkedResourceIdentifiers:(NSMutableArray *)array
        validSchemes:(NSArray *)schemes
        extensions:(NSArray *)exts
{
	NSString *href = [self href];
	unsigned anchorStart = [href rangeOfString:@"#" options:NSBackwardsSearch].location;
	if(NSNotFound != anchorStart) href = [href substringToIndex:anchorStart];
	if(href && ![@"" isEqualToString:href]) {
		NSURL *const URL = [NSURL URLWithString:href];
		if((!schemes || [schemes containsObject:[URL scheme]]) && (!exts || [exts containsObject:[[URL path] pathExtension]])) {
			PGResourceIdentifier *const ident = [URL AE_resourceIdentifier];
			if(![array containsObject:ident]) {
				[ident setDisplayName:[self AE_stringValue] notify:NO];
				[array addObject:ident];
			}
		}
	}
	[super AE_getLinkedResourceIdentifiers:array validSchemes:schemes extensions:exts];
}

@end

@implementation DOMHTMLImageElement (AEAdditions)

- (void)AE_getEmbeddedImageIdentifiers:(NSMutableArray *)array
{
	PGResourceIdentifier *const ident = [[NSURL URLWithString:[self src]] AE_resourceIdentifier];
	if(![array containsObject:ident]) {
		[ident setDisplayName:[self alt] notify:NO];
		[array addObject:ident];
	}
	[super AE_getEmbeddedImageIdentifiers:array];
}

@end

@implementation DOMElement (AEAdditions)

- (BOOL)isNonCollapsingNewlineTag
{
	return [@"BR" isEqualToString:[self tagName]];
}
- (BOOL)isCollapsingNewlineTag
{
	return [[NSArray arrayWithObjects:@"OL", @"UL", @"BLOCKQUOTE", @"DD", @"DIV", @"DL", @"DT", @"HR", @"LISTING", @"PRE", @"TD", @"TH", @"H1", @"H2", @"H3", @"H4", @"H5", @"H6", @"P", @"TR", nil] containsObject:[self tagName]];
}
- (NSString *)AE_computedStylePropertyValue:(NSString *)aString
{
	return [[[self ownerDocument] getComputedStyle:self :@""] getPropertyValue:aString];
}
- (NSString *)AE_stringValue:(inout AEWhitespace *)trailing
{
	NSParameterAssert(trailing);
	NSMutableString *result = [NSMutableString string];
	if([self isNonCollapsingNewlineTag]) {
		[result appendString:@"\n"];
		*trailing = AENewline;
	}
	if([self isCollapsingNewlineTag]) *trailing = AENewline;
	[result appendString:[self AE_stringValueOfChildren:trailing]];
	if([self isCollapsingNewlineTag]) *trailing = AENewline;
	return result;
}

@end

@implementation DOMCharacterData (AEAdditions)

- (NSString *)AE_stringValue
{
	if([self AE_pre] || [[[[self AE_ancestorThatRespondsTo:@selector(AE_computedStylePropertyValue:)] AE_computedStylePropertyValue:@"white-space"] lowercaseString] isEqualToString:@"pre"]) return [self data];
	NSScanner *const scanner = [NSScanner scannerWithString:[self data]];
	NSCharacterSet *const whitespaceCharacters = [NSCharacterSet whitespaceAndNewlineCharacterSet];
	[scanner setCharactersToBeSkipped:whitespaceCharacters];
	NSCharacterSet *const goodCharacters = [whitespaceCharacters invertedSet];
	NSMutableString *const collapsed = [NSMutableString string];
	NSString *substring;
	while([scanner scanCharactersFromSet:goodCharacters intoString:&substring]) {
		[collapsed appendString:substring];
		if(![scanner isAtEnd]) [collapsed appendString:@" "];
	}
	return collapsed;
}
- (NSString *)AE_stringValue:(inout AEWhitespace *)trailing
{
	NSParameterAssert(trailing);
	NSString *result = [self AE_stringValue];
	unsigned whitespace;
	for(whitespace = 0; whitespace < [result length] && [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[result characterAtIndex:whitespace]]; whitespace++);
	if(whitespace) {
		if(AENoWhitespace == *trailing) *trailing = AESpace;
		if(whitespace == [result length]) return @"";
		result = [result substringFromIndex:whitespace];
	}
	if(AENoWhitespace != *trailing) result = [(AESpace == *trailing ? @" " : @"\n") stringByAppendingString:result];
	for(whitespace = [result length]; whitespace-- && [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[result characterAtIndex:whitespace]];);
	if(whitespace != [result length] - 1) {
		result = [result substringToIndex:whitespace];
		*trailing = AESpace;
	} else *trailing = AENoWhitespace;
	return result;
}

@end
