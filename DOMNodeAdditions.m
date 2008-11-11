/* Copyright © 2007-2008, The Sequential Project
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

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "DOMNodeAdditions.h"

// Models
#import "PGResourceIdentifier.h"

@implementation DOMHTMLDocument (AEAdditions)

- (NSArray *)AE_linkHrefIdentifiersWithSchemes:(NSArray *)schemes
             extensions:(NSArray *)exts
{
	NSMutableArray *const results = [NSMutableArray array];
	DOMHTMLCollection *const links = [self links];
	unsigned i = 0;
	unsigned const count = [links length];
	for(; i < count; i++) {
		DOMHTMLAnchorElement *const a = (DOMHTMLAnchorElement *)[links item:i];
		NSString *href = [a href];
		unsigned anchorStart = [href rangeOfString:@"#" options:NSBackwardsSearch].location;
		if(NSNotFound != anchorStart) href = [href substringToIndex:anchorStart];
		if(!href || [@"" isEqualToString:href]) continue;
		NSURL *const URL = [NSURL URLWithString:href];
		if((schemes && ![schemes containsObject:[[URL scheme] lowercaseString]]) || (exts && ![exts containsObject:[[[URL path] pathExtension] lowercaseString]])) continue;
		PGResourceIdentifier *const ident = [URL AE_resourceIdentifier];
		if([results containsObject:ident]) continue;
		[ident setCustomDisplayName:[a innerText] notify:NO];
		[results addObject:ident];
	}
	return results;
}
- (NSArray *)AE_imageSrcIdentifiers
{
	NSMutableArray *const results = [NSMutableArray array];
	DOMHTMLCollection *const images = [self images];
	unsigned i = 0;
	unsigned const count = [images length];
	for(; i < count; i++) {
		DOMHTMLImageElement *const img = (DOMHTMLImageElement *)[images item:i];
		if([img AE_hasAncestorWithNodeName:@"A"]) continue;
		PGResourceIdentifier *const ident = [[NSURL URLWithString:[img src]] AE_resourceIdentifier];
		if([results containsObject:ident]) continue; // I have a hypothesis that images within links are rarely interesting in and of themselves, so don't load them.
		NSString *const title = [img title]; // Prefer the title to the alt attribute.
		[ident setCustomDisplayName:(title && ![@"" isEqualToString:title] ? title : [img alt]) notify:NO];
		[results addObject:ident];
	}
	return results;
}

@end

@implementation DOMNode (AEAdditions)

- (BOOL)AE_hasAncestorWithNodeName:(NSString *)string
{
	return [[self nodeName] isEqualToString:string] ? YES : [[self parentNode] AE_hasAncestorWithNodeName:string];
}

@end
