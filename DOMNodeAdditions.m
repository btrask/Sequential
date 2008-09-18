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
#import "DOMNodeAdditions.h"

// Models
#import "PGResourceIdentifier.h"

@implementation DOMHTMLDocument (AEAdditions)

- (NSURL *)AE_oEmbedURL
{
	DOMNodeList *const elements = [self getElementsByTagName:@"LINK"];
	unsigned i = 0;
	for(; i < [elements length]; i++) {
		DOMHTMLLinkElement *const link = (DOMHTMLLinkElement *)[elements item:i];
		if(![@"alternate" isEqualToString:[[link rel] lowercaseString]] || ![@"text/xml+oembed" isEqualToString:[[link type] lowercaseString]]) continue;
		NSString *const href = [link href];
		if(href && ![@"" isEqualToString:href]) return [NSURL URLWithString:[link href]];
	}
	return nil;
}
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
		if((schemes && ![schemes containsObject:[URL scheme]]) || (exts && ![exts containsObject:[[URL path] pathExtension]])) continue;
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
