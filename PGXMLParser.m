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

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Categories
#import "NSObjectAdditions.h"

static NSString *const PGXMLParsersKey = @"PGXMLParsers";

@implementation PGXMLParser

#pragma mark Class Methods

+ (id)parserWithData:(NSData *)data
      baseURL:(NSURL *)URL
{
	PGXMLParser *const p = [[[self alloc] init] autorelease];
	[p setBaseURL:URL];
	[p parseWithData:data];
	return p;
}
+ (BOOL)canParseTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	return NO;
}

#pragma mark Instance Methods

- (NSURL *)baseURL
{
	if(!_baseURL) return [_parent baseURL];
	return [[_baseURL retain] autorelease];
}
- (void)setBaseURL:(NSURL *)URL
{
	if(URL == _baseURL) return;
	[_baseURL release];
	_baseURL = [URL copy];
}

#pragma mark -

- (void)parseWithData:(NSData *)data
{
	_tagPath = [@"/" copy];
	_parser = [[NSXMLParser alloc] initWithData:data];
	[_parser setDelegate:self];
	[_parser parse];
	[_parser release];
	_parser = nil;
	[_tagPath release];
	_tagPath = nil;
}

#pragma mark -

- (PGXMLParser *)parentParser
{
	return _parent;
}
- (NSArray *)subparsers
{
	return [[_subparsers copy] autorelease];
}
- (void)useSubparser:(PGXMLParser *)parser
{
	NSParameterAssert([parser isKindOfClass:[PGXMLParser class]]);
	NSParameterAssert(_parser);
	NSParameterAssert(!parser->_parent);
	[_subparsers addObject:parser];
	[_parser setDelegate:parser];
	parser->_parent = self;
	parser->_parser = _parser;
	parser->_initialTagPath = [_tagPath copy];
	parser->_tagPath = [_tagPath copy];
	[parser beganTagPath:_tagPath attributes:_attributes];
}

#pragma mark -

- (void)beganTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	if(![self isMemberOfClass:[PGXMLParser class]]) return;
	if([[p pathComponents] count] != 2) return;
	static NSArray *parserNames = nil;
	if(!parserNames) parserNames = [[[[NSBundle mainBundle] infoDictionary] objectForKey:PGXMLParsersKey] copy];
	NSString *parserName;
	NSEnumerator *const parserNameEnum = [parserNames objectEnumerator];
	while((parserName = [parserNameEnum nextObject])) {
		Class const class = NSClassFromString(parserName);
		if(![class canParseTagPath:p attributes:attrs]) continue;
		[self useSubparser:[[[class alloc] init] autorelease]];
		break;
	}
}
- (NSMutableString *)contentStringForTagPath:(NSString *)p
{
	return nil;
}
- (void)endedTagPath:(NSString *)p {}

#pragma mark PGXMLParserNodeCreation Protocol

- (BOOL)createsMultipleNodes
{
	return YES;
}

#pragma mark -

- (NSString *)title
{
	return nil;
}
- (NSURL *)URL
{
	NSString *const URLString = [self URLString];
	return URLString ? [NSURL URLWithString:URLString relativeToURL:[self baseURL]] : nil;
}
- (NSError *)error
{
	NSString *const errorString = [self errorString];
	return errorString ? [NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:errorString forKey:NSLocalizedDescriptionKey]] : nil;
}
- (id)info
{
	if([self createsMultipleNodes]) return nil;
	NSMutableArray *const dicts = [NSMutableArray array];
	PGXMLParser *parser;
	NSEnumerator *const parserEnum = [[self subparsers] objectEnumerator];
	while((parser = [parserEnum nextObject])) [dicts addObjectsFromArray:[[parser info] AE_asArray]];
	return dicts;
}

#pragma mark -

- (NSString *)URLString
{
	return nil;
}
- (NSString *)errorString
{
	return nil;
}

#pragma mark -

- (NSArray *)nodesWithParentAdapter:(PGContainerAdapter *)parent
{
	if(![self createsMultipleNodes]) {
		PGNode *const node = [self nodeWithParentAdapter:parent];
		return node ? [NSArray arrayWithObject:node] : nil;
	}
	NSMutableArray *const nodes = [NSMutableArray array];
	PGXMLParser *subparser;
	NSEnumerator *const subparserEnum = [[self subparsers] objectEnumerator];
	while((subparser = [subparserEnum nextObject])) [nodes addObjectsFromArray:[subparser nodesWithParentAdapter:parent]];
	return nodes;
}
- (PGNode *)nodeWithParentAdapter:(PGContainerAdapter *)parent
{
	PGResourceIdentifier *const ident = [[self URL] AE_resourceIdentifier];
	if(!ident) return nil;
	[ident setCustomDisplayName:[self title] notify:NO];
	PGNode *const node = [[[PGNode alloc] initWithParentAdapter:parent document:nil identifier:ident] autorelease];
	[node startLoadWithInfo:[self info]];
	return node;
}

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
	[_attributes autorelease];
	_attributes = [attributeDict retain];
	[self beganTagPath:_tagPath attributes:attributeDict];
	[_attributes release];
	_attributes = nil;
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
	if([_initialTagPath isEqualToString:_tagPath]) {
		[_parser setDelegate:_parent];
		[_parent parser:parser didEndElement:elementName namespaceURI:namespaceURI qualifiedName:qName];
	}
	[_tagPath autorelease];
	_tagPath = [[_tagPath stringByDeletingLastPathComponent] copy];
	[pool release];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_subparsers = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[_baseURL release];
	[_subparsers release];
	[_initialTagPath release];
	[_tagPath release];
	[super dealloc];
}

@end
