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
#import "NSURLAdditions.h"

// Categories
#import "NSStringAdditions.h"

@implementation NSURL (AEAdditions)

#pragma mark Class Methods

+ (NSURL *)AE_URLWithString:(NSString *)aString
{
	NSMutableString *const URL = [NSMutableString string];
	NSScanner *const scanner = [NSScanner scannerWithString:aString];
	[scanner setCharactersToBeSkipped:[NSCharacterSet characterSetWithCharactersInString:@"\n\r\t"]];
	NSString *scheme = nil;
	if(![scanner scanUpToString:@"://" intoString:&scheme]) return nil;
	if([scanner isAtEnd]) {
		[scanner setScanLocation:0];
		scheme = [scanner scanString:@"/" intoString:NULL] || [scanner scanString:@"~" intoString:NULL] ? @"file" : @"http";
		[scanner setScanLocation:0];
	} else {
		NSMutableCharacterSet *const schemeCharacters = [[[NSCharacterSet letterCharacterSet] mutableCopy] autorelease];
		[schemeCharacters addCharactersInString:@"+-."];
		if([scheme rangeOfCharacterFromSet:[schemeCharacters invertedSet]].location != NSNotFound) return nil;
		[scanner scanString:@"://" intoString:NULL];
	}
	[URL appendFormat:@"%@://", scheme];

	unsigned const schemeEnd = [scanner scanLocation];
	NSString *login = nil;
	[scanner scanUpToString:@"@" intoString:&login];
	if([scanner isAtEnd]) [scanner setScanLocation:schemeEnd];
	else [URL appendString:login];

	NSString *host = @"";
	if(![scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@":/"] intoString:&host]) {
		if(![@"file" isEqualToString:scheme] || [scanner isAtEnd]) return nil;
	} else if([@"~" isEqualToString:host]) {
		host = NSHomeDirectory();
	} else if(![@"localhost" isEqual:host]) {
		NSCharacterSet *const subdomainDelimitingCharacters = [NSCharacterSet characterSetWithCharactersInString:@".-"];
		NSScanner *const hostScanner = [NSScanner scannerWithString:host];
		do {
			NSString *subdomain = nil;
			[hostScanner scanUpToCharactersFromSet:subdomainDelimitingCharacters intoString:&subdomain];
			if(![subdomain length]) return nil;
			if([@"-" isEqual:[subdomain substringToIndex:1]]) return nil;
			if([@"-" isEqual:[subdomain substringFromIndex:[subdomain length] - 1]]) return nil;
			if([subdomain rangeOfCharacterFromSet:[[NSCharacterSet alphanumericCharacterSet] invertedSet]].location != NSNotFound) return nil;
		} while([hostScanner scanString:@"." intoString:NULL] || [hostScanner scanString:@"-" intoString:NULL]);
		if([host rangeOfString:@"."].location == NSNotFound) host = [NSString stringWithFormat:@"www.%@.com", host];
	}
	[URL appendString:host];

	if([scanner scanString:@":" intoString:NULL]) {
		if([@"file" isEqualToString:scheme]) return nil;
		int port;
		if(![scanner scanInt:&port]) return nil;
		[URL appendFormat:@":%d", port];
	}

	NSMutableString *const path = [NSMutableString string];
	[scanner scanString:@"/" intoString:NULL];
	[path appendString:@"/"];
	NSCharacterSet *const hexCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
	NSMutableData *const hexData = [NSMutableData data];
	while(YES) {
		NSString *pathPart;
		if([scanner scanUpToString:@"%" intoString:&pathPart]) {
			[hexData setLength:0];
			[path appendString:pathPart];
		}
		if(![scanner scanString:@"%" intoString:NULL]) break;
		unsigned const percentLoc = [scanner scanLocation];
		NSString *hex = nil;
		if(![scanner scanCharactersFromSet:hexCharacterSet intoString:&hex] || [hex length] < 2) {
			[hexData setLength:0];
			[scanner setScanLocation:percentLoc];
			[path appendString:@"%"];
			continue;
		}
		[scanner setScanLocation:percentLoc + 2];
		NSScanner *const hexScanner = [NSScanner scannerWithString:[hex substringToIndex:2]];
		unsigned character;
		if([hexScanner scanHexInt:&character]) {
			[hexData appendBytes:&character length:1];
			NSString *const hexEncodedString = [[[NSString alloc] initWithData:hexData encoding:NSUTF8StringEncoding] autorelease];
			if(hexEncodedString) {
				[path appendString:hexEncodedString];
				[hexData setLength:0];
			}
		}
	}
	if([path rangeOfString:@"//"].location != NSNotFound) return nil;
	[URL appendString:path];
	return [self URLWithString:[URL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

#pragma mark Instance Methods

- (NSImage *)AE_icon
{
	return [self isFileURL] ? [[NSWorkspace sharedWorkspace] iconForFile:[self path]] : [NSImage imageNamed:@"URL"];
}

@end
