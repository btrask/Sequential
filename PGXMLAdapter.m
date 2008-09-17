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
	if([self getData:&data] != PGDataReturned) return;
	NSXMLParser *const parser = [[[NSXMLParser alloc] initWithData:data] autorelease];
	[parser setDelegate:self];
	_tagPath = [@"/" copy];
	(void)[parser parse];
	[_tagPath release];
	_tagPath = nil;
	[_version release];
	_version = nil;
	[_type release];
	_type = nil;
	[_title release];
	_title = nil;
	[_URL release];
	_URL = nil;
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
		[_version release];
		_version = [[NSMutableString alloc] init];
	} else if([@"/oembed/type" isEqualToString:_tagPath]) {
		[_type release];
		_type = [[NSMutableString alloc] init];
	} else if([@"/oembed/title" isEqualToString:_tagPath]) {
		[_title release];
		_title = [[NSMutableString alloc] init];
	} else if([@"/oembed/url" isEqualToString:_tagPath]) {
		[_URL release];
		_URL = [[NSMutableString alloc] init];
	}
}
- (void)parser:(NSXMLParser *)parser
        foundCharacters:(NSString *)string
{
	NSMutableString *dest = nil;
	if([@"/oembed/version" isEqualToString:_tagPath]) dest = _version;
	else if([@"/oembed/type" isEqualToString:_tagPath]) dest = _type;
	else if([@"/oembed/title" isEqualToString:_tagPath]) dest = _title;
	else if([@"/oembed/url" isEqualToString:_tagPath]) dest = _URL;
	[dest appendString:string];
}
- (void)parser:(NSXMLParser *)parser
        didEndElement:(NSString *)elementName
        namespaceURI:(NSString *)namespaceURI
        qualifiedName:(NSString *)qName
{
	if(([@"/oembed/version" isEqualToString:_tagPath] && ![@"1.0" isEqualToString:_version]) || ([@"/oembed/type" isEqualToString:_tagPath] && ![@"photo" isEqualToString:_type])) {
		[_version release];
		_version = nil;
		[_type release];
		_type = nil;
		[_title release];
		_title = nil;
		[_URL release];
		_URL = nil;
	}
	if(_version && _title && ([@"/oembed/version" isEqualToString:_tagPath] || [@"/oembed/title" isEqualToString:_tagPath])) [[self identifier] setCustomDisplayName:_title notify:YES];
	if(_version && _title && _type && _URL) {
		PGResourceIdentifier *const ident = [PGResourceIdentifier resourceIdentifierWithURL:[NSURL URLWithString:_URL]];
		[ident setCustomDisplayName:_title notify:NO];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:ident] autorelease];
		[node loadIfNecessaryWithURLResponse:nil];
		[self setUnsortedChildren:[NSArray arrayWithObject:node] presortedOrder:PGUnsorted];
		return [parser abortParsing];
	}
	NSString *const oldTagPath = _tagPath;
	_tagPath = [[_tagPath stringByDeletingLastPathComponent] copy];
	[oldTagPath release];
}

@end
