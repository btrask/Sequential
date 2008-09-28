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
#import "PGXMLParser.h"

@implementation PGXMLParser

#pragma mark Class Methods

+ (id)parserWithData:(NSData *)data
{
	PGXMLParser *const p = [[[self alloc] init] autorelease];
	[p parseWithData:data];
	return p;
}

#pragma mark Instance Methods

- (void)parseWithData:(NSData *)data
{
	_tagPath = [@"/" copy];
	NSXMLParser *const p = [[[NSXMLParser alloc] initWithData:data] autorelease];
	[p setDelegate:self];
	[p parse];
}

#pragma mark -

- (void)beganTagPath:(NSString *)p attributes:(NSDictionary *)attrs {}
- (NSMutableString *)contentStringForTagPath:(NSString *)p
{
	return nil;
}
- (void)endedTagPath:(NSString *)p {}

#pragma mark NSXMLParserDelegateEventAdditions Protocol

- (void)parser:(NSXMLParser *)parser
        didStartElement:(NSString *)elementName
        namespaceURI:(NSString *)namespaceURI
        qualifiedName:(NSString *)qName
        attributes:(NSDictionary *)attributeDict
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	[_tagPath autorelease];
	_tagPath = [[_tagPath stringByAppendingPathComponent:elementName] copy];
	[[self contentStringForTagPath:_tagPath] setString:@""];
	[self beganTagPath:_tagPath attributes:attributeDict];
	[pool release];
}
- (void)parser:(NSXMLParser *)parser
        foundCharacters:(NSString *)string
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	[[self contentStringForTagPath:_tagPath] appendString:string];
	[pool release];
}
- (void)parser:(NSXMLParser *)parser
        didEndElement:(NSString *)elementName
        namespaceURI:(NSString *)namespaceURI
        qualifiedName:(NSString *)qName
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	[self endedTagPath:_tagPath];
	[_tagPath autorelease];
	_tagPath = [[_tagPath stringByDeletingLastPathComponent] copy];
	[pool release];
}

#pragma mark NSObject

- (void)dealloc
{
	[_tagPath release];
	[super dealloc];
}

@end
