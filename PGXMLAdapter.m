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
#import <WebKit/WebKit.h>

// Models
#import "PGNode.h"
#import "PGWebAdapter.h"
#import "PGHTMLAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGXMLParser.h"

@interface PGOEmbedParser : PGXMLParser
{
	@private
	NSMutableString *_version;
	NSMutableString *_type;
	NSMutableString *_title;
	NSMutableString *_URLString;
}

@end

@implementation PGXMLAdapter

#pragma mark PGResourceAdapter

+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	PGMatchPriority const p = [super matchPriorityForNode:node withInfo:info];
	if(p) return p;
	do {
		if([[info objectForKey:PGDataExistenceKey] intValue] != PGDoesNotExist) break;
		NSURL *const URL = [info objectForKey:PGURLKey];
		if(![[URL host] isEqualToString:@"flickr.com"] && ![[URL host] hasSuffix:@".flickr.com"]) break;
		if(![[URL path] hasPrefix:@"/photos"]) break;
		[info setObject:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.flickr.com/services/oembed/?url=%@&format=xml", [URL absoluteString]]] forKey:PGURLKey];
		[info setObject:[PGWebAdapter class] forKey:PGSubstitutedClassKey];
		return PGMatchByIntrinsicAttribute + 300;
	} while(NO);
	do {
		DOMHTMLDocument *const doc = [info objectForKey:PGDOMDocumentKey];
		if(!doc || ![doc isKindOfClass:[DOMHTMLDocument class]]) break;
		DOMNodeList *const elements = [doc getElementsByTagName:@"LINK"];
		unsigned i = 0;
		for(; i < [elements length]; i++) {
			DOMHTMLLinkElement *const link = (DOMHTMLLinkElement *)[elements item:i];
			if(![@"alternate" isEqualToString:[[link rel] lowercaseString]]) continue;
			if(![[[self typeDictionary] objectForKey:PGCFBundleTypeMIMETypesKey] containsObject:[[link type] lowercaseString]]) continue;
			NSURL *const linkURL = [link absoluteLinkURL];
			if(!linkURL) continue;
			[info setObject:linkURL forKey:PGURLKey];
			[info setObject:[PGWebAdapter class] forKey:PGSubstitutedClassKey];
			return PGMatchByIntrinsicAttribute + 300;
		}
	} while(NO);
	return PGNotAMatch;
}

#pragma mark PGResourceAdapter

- (void)load
{
	NSData *const data = [self data];
	if(!data) return [[self node] loadFinished];
	_triedLoading = YES;
	PGXMLParser *const p = [PGXMLParser parserWithData:data baseURL:[[self info] objectForKey:PGURLKey]];
	NSString *const title = [p title];
	if(title) [[self identifier] setCustomDisplayName:title notify:YES];
	if(![p createsMultipleNodes]) {
		id const info = [p info];
		if(info) return [[self node] continueLoadWithInfo:info];
		return [[self node] loadFinished];
	}
	NSArray *const nodes = [p nodesWithParentAdapter:self];
	if(![nodes count]) return [[self node] setError:[p error]];
	[self setUnsortedChildren:nodes presortedOrder:PGSortInnateOrder];
	[[self node] loadFinished];
}
- (void)fallbackLoad
{
	if(_triedLoading) [[self node] setError:nil];
	else [self load];
}

@end

@implementation PGOEmbedParser

#pragma mark PGXMLParser

+ (BOOL)canParseTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	return [p hasPrefix:@"/oembed"];
}

#pragma mark PGXMLParserNodeCreation Protocol

- (NSString *)title
{
	return [@"1.0" isEqualToString:_version] && [@"photo" isEqualToString:_type] ? _title : nil;
}
- (NSString *)URLString
{
	return [@"1.0" isEqualToString:_version] && [@"photo" isEqualToString:_type] ? _URLString : nil;
}

#pragma mark PGXMLParser

- (NSMutableString *)contentStringForTagPath:(NSString *)p
{
	if([@"/oembed/version" isEqualToString:p]) return _version;
	if([@"/oembed/type" isEqualToString:p]) return _type;
	if([@"/oembed/title" isEqualToString:p]) return _title;
	if([@"/oembed/url" isEqualToString:p]) return _URLString;
	return [super contentStringForTagPath:p];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_version = [[NSMutableString alloc] init];
		_type = [[NSMutableString alloc] init];
		_title = [[NSMutableString alloc] init];
		_URLString = [[NSMutableString alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[_version release];
	[_type release];
	[_title release];
	[_URLString release];
	[super dealloc];
}

@end

@interface PGMediaRSSParser : PGXMLParser
{
	@private
	NSMutableString *_title;
}

@end

@interface PGMediaRSSItemParser : PGXMLParser
{
	@private
	NSMutableString *_title;
}

@end

@interface PGMediaRSSItemContentParser : PGXMLParser
{
	@private
	NSString *_URLString;
	NSString *_MIMEType;
}

@end

@implementation PGMediaRSSParser

#pragma mark PGXMLParser

+ (BOOL)canParseTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	return [p hasPrefix:@"/rss"] && [[attrs objectForKey:@"xmlns:media"] hasPrefix:@"http://search.yahoo.com/mrss"];
}

#pragma mark PGXMLParserNodeCreation Protocol

- (BOOL)createsMultipleNodes
{
	return YES;
}
- (NSString *)title
{
	return [[_title copy] autorelease];
}

#pragma mark PGXMLParser

- (void)beganTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	if([@"/rss/channel/item" isEqualToString:p]) [self useSubparser:[[[PGMediaRSSItemParser alloc] init] autorelease]];
}
- (NSMutableString *)contentStringForTagPath:(NSString *)p
{
	return [@"/rss/channel/title" isEqualToString:p] ? _title : nil;
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_title = [[NSMutableString alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[_title release];
	[super dealloc];
}

@end

@implementation PGMediaRSSItemParser

#pragma mark PGXMLParserNodeCreation Protocol

- (BOOL)createsMultipleNodes
{
	return NO;
}
- (NSString *)title
{
	return [[_title copy] autorelease];
}
- (NSURL *)URL
{
	NSArray *const subparsers = [self subparsers];
	return [subparsers count] ? [[subparsers objectAtIndex:0] URL] : nil;
}

#pragma mark PGXMLParser

- (void)beganTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	if([@"/rss/channel/item/media:content" isEqualToString:p] || [@"rss/channel/item/media:group/media:content" isEqualToString:p]) [self useSubparser:[[[PGMediaRSSItemContentParser alloc] init] autorelease]];
}
- (NSMutableString *)contentStringForTagPath:(NSString *)p
{
	if([@"/rss/channel/item/title" isEqualToString:p]) return _title;
	return nil;
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_title = [[NSMutableString alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[_title release];
	[super dealloc];
}

@end

@implementation PGMediaRSSItemContentParser

#pragma mark PGXMLParserNodeCreation Protocol

- (BOOL)createsMultipleNodes
{
	return NO;
}
- (NSString *)URLString
{
	return [[_URLString retain] autorelease];
}
- (id)info
{
	return [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:PGDoesNotExist], PGDataExistenceKey, [self URL], PGURLKey, _MIMEType, PGMIMETypeKey, nil];
}

#pragma mark PGXMLParser

- (void)beganTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	[_URLString autorelease];
	_URLString = [[attrs objectForKey:@"url"] copy];
	[_MIMEType autorelease];
	_MIMEType = [[attrs objectForKey:@"type"] copy];
}

#pragma mark NSObject

- (void)dealloc
{
	[_URLString release];
	[_MIMEType release];
	[super dealloc];
}

@end

