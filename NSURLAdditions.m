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
	[scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@"@/"] intoString:&login];
	if([scanner scanString:@"@" intoString:NULL]) [URL appendFormat:@"%@@", login];
	else [scanner setScanLocation:schemeEnd];

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
			if(![subdomain length] || [subdomain hasPrefix:@"-"] || [subdomain hasSuffix:@"-"]) return nil;
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
	[URL appendString:path];
	return [self URLWithString:[URL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

#pragma mark Instance Methods

- (NSImage *)AE_icon
{
	if(![self isFileURL]) return [NSImage imageNamed:@"URL"];
	NSImage *const icon = [[NSWorkspace sharedWorkspace] iconForFile:[self path]];
	[icon setDataRetained:YES];
	if(!PGIsLeopardOrLater()) [icon setSize:NSMakeSize(128, 128)];
	return icon;
}

@end
