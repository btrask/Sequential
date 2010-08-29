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
#import "PGWebKitAdditions.h"

// Models
#import "PGResourceIdentifier.h"
#import "PGDataProvider.h"

// Other Sources
#import "PGFoundationAdditions.h"

@implementation DOMHTMLDocument(PGWebKitAdditions)

- (NSArray *)PG_providersForLinksWithMIMETypes:(NSArray *)MIMETypes
{
	NSMutableArray *const results = [NSMutableArray array];
	NSMutableArray *const hrefs = [NSMutableArray array];
	DOMNodeList *const links = [self getElementsByTagName:@"LINK"];
	NSUInteger i = 0;
	for(; i < [links length]; i++) {
		DOMHTMLLinkElement *const link = (DOMHTMLLinkElement *)[links item:i];
		if(![[[link rel] componentsSeparatedByString:@" "] containsObject:@"alternate"]) continue;
		if(MIMETypes && ![MIMETypes containsObject:[link type]]) continue;
		NSString *const href = [link href];
		if([hrefs containsObject:href]) continue;
		[hrefs addObject:href];
		[results addObject:[PGDataProvider providerWithResourceIdentifier:[[NSURL URLWithString:href] PG_resourceIdentifier] displayableName:[link title]]];
	}
	return results;
}
- (NSArray *)PG_providersForAnchorsWithSchemes:(NSArray *)schemes
{
	NSMutableArray *const results = [NSMutableArray array];
	NSMutableArray *const hrefs = [NSMutableArray array];
	DOMHTMLCollection *const anchors = [self links];
	NSUInteger i = 0;
	NSUInteger const count = [anchors length];
	for(; i < count; i++) {
		DOMHTMLAnchorElement *const anchor = (DOMHTMLAnchorElement *)[anchors item:i];
		NSString *href = [anchor href];
		NSUInteger anchorStart = [href rangeOfString:@"#" options:NSBackwardsSearch].location;
		if(NSNotFound != anchorStart) href = [href substringToIndex:anchorStart];
		if(![href length]) continue;
		if([hrefs containsObject:href]) continue;
		[hrefs addObject:href];

		NSURL *const URL = [NSURL URLWithString:href];
		if(schemes && ![schemes containsObject:[[URL scheme] lowercaseString]]) continue;
		[results addObject:[PGDataProvider providerWithResourceIdentifier:[URL PG_resourceIdentifier] displayableName:[[anchor innerText] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]]];
	}
	return results;
}
- (NSArray *)PG_providersForImages
{
	NSMutableArray *const results = [NSMutableArray array];
	NSMutableArray *const srcs = [NSMutableArray array];
	DOMHTMLCollection *const images = [self images];
	NSUInteger i = 0;
	NSUInteger const count = [images length];
	for(; i < count; i++) {
		DOMHTMLImageElement *const img = (DOMHTMLImageElement *)[images item:i];
		if([img PG_hasAncestorWithNodeName:@"A"]) continue; // I have a hypothesis that images within links are rarely interesting in and of themselves, so don't load them.
		NSString *const src = [img src];
		if([srcs containsObject:src]) continue;
		[srcs addObject:src];
		NSString *const title = [img title]; // Prefer the title to the alt attribute.
		[results addObject:[PGDataProvider providerWithResourceIdentifier:[[NSURL URLWithString:[img src]] PG_resourceIdentifier] displayableName:[title length] ? title : [img alt]]];
	}
	return results;
}

@end

@implementation DOMNode(PGWebKitAdditions)

- (BOOL)PG_hasAncestorWithNodeName:(NSString *)string
{
	return PGEqualObjects([self nodeName], string) ? YES : [[self parentNode] PG_hasAncestorWithNodeName:string];
}

@end
