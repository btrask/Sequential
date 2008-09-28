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
#import "PGWebAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGXMLParser.h"

static NSString *const PGShouldLoadInWebAdapterKey = @"PGShouldLoadInWebAdapter";

@interface PGOEmbedParser : PGXMLParser
{
	@private
	NSMutableString *_version;
	NSMutableString *_type;
	NSMutableString *_title;
	NSMutableString *_URL;
}

- (NSString *)title;
- (NSURL *)URL;

@end

@implementation PGXMLAdapter

#pragma mark PGResourceAdapter

+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	PGMatchPriority const p = [super matchPriorityForNode:node withInfo:info];
	if(p) return p;
	if([[info objectForKey:PGHasDataKey] boolValue]) return PGNotAMatch;
	NSURL *const URL = [info objectForKey:PGURLKey];
	if(![[URL host] isEqualToString:@"flickr.com"] && ![[URL host] hasSuffix:@".flickr.com"]) return PGNotAMatch;
	if(![[URL path] hasPrefix:@"/photos"]) return PGNotAMatch;
	[info setObject:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.flickr.com/services/oembed/?url=%@&format=xml", [URL absoluteString]]] forKey:PGURLKey];
	[info setObject:[NSNumber numberWithBool:YES] forKey:PGShouldLoadInWebAdapterKey];
	return PGMatchByIntrinsicAttribute + 300;
}
+ (Class)adapterClassForInfo:(NSDictionary *)info
{
	return [[info objectForKey:PGShouldLoadInWebAdapterKey] boolValue] ? [PGWebAdapter class] : self;
}

#pragma mark PGResourceAdapter

- (void)load
{
	NSData *const data = [self data];
	if(!data) return [[self node] loadFinished];
	PGOEmbedParser *const p = [PGOEmbedParser parserWithData:data];
	PGResourceIdentifier *const ident = [[p URL] AE_resourceIdentifier];
	[ident setCustomDisplayName:[p title] notify:NO];
	PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:ident] autorelease];
	[node startLoadWithInfo:nil];
	if(node) [self setUnsortedChildren:[NSArray arrayWithObject:node] presortedOrder:PGUnsorted];
	[[self node] loadFinished];
}

@end

@implementation PGOEmbedParser

#pragma mark Instance Methods

- (NSString *)title
{
	return [@"1.0" isEqualToString:_version] && [@"photo" isEqualToString:_type] ? _title : nil;
}
- (NSURL *)URL
{
	if(![@"1.0" isEqualToString:_version] || ![@"photo" isEqualToString:_type]) return nil;
	return _URL ? [NSURL URLWithString:_URL] : nil;
}

#pragma mark PGXMLParser

- (NSMutableString *)contentStringForTagPath:(NSString *)p
{
	if([@"/oembed/version" isEqualToString:p]) return _version;
	if([@"/oembed/type" isEqualToString:p]) return _type;
	if([@"/oembed/title" isEqualToString:p]) return _title;
	if([@"/oembed/url" isEqualToString:p]) return _URL;
	return [super contentStringForTagPath:p];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_version = [[NSMutableString alloc] init];
		_type = [[NSMutableString alloc] init];
		_title = [[NSMutableString alloc] init];
		_URL = [[NSMutableString alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[_version release];
	[_type release];
	[_title release];
	[_URL release];
	[super dealloc];
}

@end
