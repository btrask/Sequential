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
#import "PGXMLAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

@implementation PGXMLAdapter

- (void)loadWithURLResponse:(NSURLResponse *)response
{
	NSData *data;
	if([self getData:&data] != PGDataReturned) return [[self node] loadFailedWithError:nil];
	NSXMLParser *const parser = [[[NSXMLParser alloc] initWithData:data] autorelease];
	[parser setDelegate:self];
	_tagPath = [@"/" copy];
	_children = [[NSMutableArray alloc] init];
	(void)[parser parse];
	[_tagPath release];
	_tagPath = nil;
	[self setUnsortedChildren:_children presortedOrder:PGUnsorted];
	[_children release];
	_children = nil;
	[[self node] loadSucceeded];
}

- (void)parser:(NSXMLParser *)parser
        didStartElement:(NSString *)elementName
        namespaceURI:(NSString *)namespaceURI
        qualifiedName:(NSString *)qName
        attributes:(NSDictionary *)attributeDict
{
	NSString *const oldTagPath = _tagPath;
	_tagPath = [[_tagPath stringByAppendingPathComponent:elementName] copy];
	[oldTagPath release];
	if([@"/oembed/version" isEqualToString:_tagPath]) {
		[_.oEmbed.version release];
		_.oEmbed.version = [[NSMutableString alloc] init];
	} else if([@"/oembed/type" isEqualToString:_tagPath]) {
		[_.oEmbed.type release];
		_.oEmbed.type = [[NSMutableString alloc] init];
	} else if([@"/oembed/title" isEqualToString:_tagPath]) {
		[_.oEmbed.title release];
		_.oEmbed.title = [[NSMutableString alloc] init];
	} else if([@"/oembed/url" isEqualToString:_tagPath]) {
		[_.oEmbed.URL release];
		_.oEmbed.URL = [[NSMutableString alloc] init];
	} else if([@"/rsp/sizes/size" isEqualToString:_tagPath]) {
		NSString *const label = [attributeDict objectForKey:@"label"];
		static NSArray *sizes = nil;
		if(!sizes) sizes = [[NSArray alloc] initWithObjects:@"square", @"thumbnail", @"small", @"medium", @"large", @"original", nil];
		unsigned const size = label ? [sizes indexOfObject:[label lowercaseString]] + 1 : NSNotFound;
		if(NSNotFound != size && size > _.flickr.size) {
			_.flickr.size = size;
			[_.flickr.URL release];
			_.flickr.URL = [[attributeDict objectForKey:@"source"] copy];
		}
	} else if([@"/rsp/err" isEqualToString:_tagPath]) {
		[parser abortParsing];
		_.flickr.size = 0;
		[_.flickr.URL release];
		_.flickr.URL = nil;
		//[[self node] loadWithURLResponse:nil];
	}
}
- (void)parser:(NSXMLParser *)parser
        foundCharacters:(NSString *)string
{
	NSMutableString *dest = nil;
	if([@"/oembed/version" isEqualToString:_tagPath]) dest = _.oEmbed.version;
	else if([@"/oembed/type" isEqualToString:_tagPath]) dest = _.oEmbed.type;
	else if([@"/oembed/title" isEqualToString:_tagPath]) dest = _.oEmbed.title;
	else if([@"/oembed/url" isEqualToString:_tagPath]) dest = _.oEmbed.URL;
	[dest appendString:string];
}
- (void)parser:(NSXMLParser *)parser
        didEndElement:(NSString *)elementName
        namespaceURI:(NSString *)namespaceURI
        qualifiedName:(NSString *)qName
{
	if(([@"/oembed/version" isEqualToString:_tagPath] && ![@"1.0" isEqualToString:_.oEmbed.version]) || ([@"/oembed/type" isEqualToString:_tagPath] && ![@"photo" isEqualToString:_.oEmbed.type])) {
		[_.oEmbed.version release];
		_.oEmbed.version = nil;
		[_.oEmbed.type release];
		_.oEmbed.type = nil;
		[_.oEmbed.title release];
		_.oEmbed.title = nil;
		[_.oEmbed.URL release];
		_.oEmbed.URL = nil;
	}
	if(([@"/oembed/version" isEqualToString:_tagPath] || [@"/oembed/title" isEqualToString:_tagPath]) && _.oEmbed.version && _.oEmbed.title) [[self identifier] setCustomDisplayName:_.oEmbed.title notify:YES];
	if([@"/oembed" isEqualToString:_tagPath]) {
		if(_.oEmbed.version && _.oEmbed.title && _.oEmbed.type && _.oEmbed.URL) {
			PGResourceIdentifier *const ident = [PGResourceIdentifier resourceIdentifierWithURL:[NSURL URLWithString:_.oEmbed.URL]];
			[ident setCustomDisplayName:_.oEmbed.title notify:NO];
			PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:ident] autorelease];
			[node loadWithURLResponse:nil];
			[_children addObject:node];
		}
		[_.oEmbed.version release];
		_.oEmbed.version = nil;
		[_.oEmbed.type release];
		_.oEmbed.type = nil;
		[_.oEmbed.title release];
		_.oEmbed.title = nil;
		[_.oEmbed.URL release];
		_.oEmbed.URL = nil;
	} else if([@"/rsp" isEqualToString:_tagPath]) {
		if(_.flickr.URL) {
			PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:[PGResourceIdentifier resourceIdentifierWithURL:[NSURL URLWithString:_.flickr.URL]]] autorelease];
			[node loadWithURLResponse:nil];
			[_children addObject:node];
		}
		_.flickr.size = 0;
		[_.flickr.URL release];
		_.flickr.URL = nil;
	}
	NSString *const oldTagPath = _tagPath;
	_tagPath = [[_tagPath stringByDeletingLastPathComponent] copy];
	[oldTagPath release];
}

@end
