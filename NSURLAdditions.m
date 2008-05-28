#import "NSURLAdditions.h"

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
		[URL appendString:@"http://"];
		[scanner setScanLocation:0];
	} else {
		NSMutableCharacterSet *const schemeCharacters = [[[NSCharacterSet letterCharacterSet] mutableCopy] autorelease];
		[schemeCharacters addCharactersInString:@"+-."];
		if([scheme rangeOfCharacterFromSet:[schemeCharacters invertedSet]].location != NSNotFound) return nil;
		[URL appendFormat:@"%@://", scheme];
		[scanner scanString:@"://" intoString:NULL];
	}

	unsigned const schemeEnd = [scanner scanLocation];
	NSString *login = nil;
	[scanner scanUpToString:@"@" intoString:&login];
	if([scanner isAtEnd]) [scanner setScanLocation:schemeEnd];
	else [URL appendString:login];

	NSString *host = nil;
	if(![scanner scanUpToCharactersFromSet:[NSCharacterSet characterSetWithCharactersInString:@":/"] intoString:&host]) return nil;
	if(![host isEqual:@"localhost"]) {
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
		int port;
		if(![scanner scanInt:&port]) return nil;
		[URL appendFormat:@":%d", port];
	}

	[scanner scanString:@"/" intoString:NULL];
	[URL appendString:@"/"];

	NSCharacterSet *const hexCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
	NSMutableData *const hexData = [NSMutableData data];
	while(YES) {
		NSString *pathPart;
		if([scanner scanUpToString:@"%" intoString:&pathPart]) {
			[hexData setLength:0];
			[URL appendString:pathPart];
		}
		if(![scanner scanString:@"%" intoString:NULL]) break;
		unsigned const percentLoc = [scanner scanLocation];
		NSString *hex = nil;
		if(![scanner scanCharactersFromSet:hexCharacterSet intoString:&hex] || [hex length] < 2) {
			[hexData setLength:0];
			[scanner setScanLocation:percentLoc];
			[URL appendString:@"%"];
			continue;
		}
		[scanner setScanLocation:percentLoc + 2];
		NSScanner *const hexScanner = [NSScanner scannerWithString:[hex substringToIndex:2]];
		unsigned character;
		if([hexScanner scanHexInt:&character]) {
			[hexData appendBytes:&character length:1];
			NSString *const hexEncodedString = [[[NSString alloc] initWithData:hexData encoding:NSUTF8StringEncoding] autorelease];
			if(hexEncodedString) {
				[URL appendString:hexEncodedString];
				[hexData setLength:0];
			}
		}
	}
	return [self URLWithString:[URL stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
}

#pragma mark Instance Methods

- (NSImage *)AE_icon
{
	return [self isFileURL] ? [[NSWorkspace sharedWorkspace] iconForFile:[self path]] : [NSImage imageNamed:@"URL"];
}

@end
