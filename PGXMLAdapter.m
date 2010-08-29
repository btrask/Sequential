/* Copyright © 2010, The Sequential Project
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
#import "PGXMLAdapter.h"

// Models
#import "PGResourceIdentifier.h"

// Other Sources
#import "PGFoundationAdditions.h"

@implementation PGXMLAdapter

#pragma mark -PGXMLAdapter

- (NSXMLDocument *)XMLDocument
{
	if(!_XMLDocument) _XMLDocument = [[NSXMLDocument alloc] initWithData:[self data] options:NSXMLNodeOptionsNone error:NULL];
	return [[_XMLDocument retain] autorelease];
}

#pragma mark -PGContainerAdapter

- (PGRecursionPolicy)descendantRecursionPolicy
{
	return PGRecurseNoFurther;
}

#pragma mark -NSObject

- (void)dealloc
{
	[_XMLDocument release];
	[super dealloc];
}

@end

@interface PGMediaRSSAdapter(Private)

- (BOOL)_createChildren;

@end

@implementation PGMediaRSSAdapter

#pragma mark -PGMediaRSSAdapter(Private)

- (BOOL)_createChildren
{
	NSXMLElement *const RSS = [[self XMLDocument] rootElement];
	if(!PGEqualObjects(@"rss", [RSS name])) return NO;
	if(![RSS resolvePrefixForNamespaceURI:@"http://search.yahoo.com/mrss"]) return NO;
	if(1 != [RSS childCount]) return NO;
	NSXMLElement *const channel = [[RSS children] lastObject];
	if(!PGEqualObjects(@"channel", [channel name])) return NO;
	NSArray *const titles = [channel elementsForName:@"title"];
	if([titles count]) [[[self node] identifier] setCustomDisplayName:[[titles lastObject] stringValue]];

	NSMutableArray *const items = [NSMutableArray array];
	for(NSXMLElement *const item in [channel elementsForName:@"item"]) {
		NSString *const title = [[[item elementsForName:@"title"] lastObject] stringValue];
		NSString *const URLString = [[[[item elementsForLocalName:@"content" URI:@"http://search.yahoo.com/mrss"] lastObject] attributeForName:@"url"] stringValue];

		PGDisplayableIdentifier *const ident = [[NSURL URLWithString:URLString] PG_displayableIdentifier];
		[ident setCustomDisplayName:title];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:ident] autorelease];
		if(!node) continue;
		[node setDataProvider:[PGDataProvider providerWithResourceIdentifier:ident]];
		[items addObject:node];
	}
	[self setUnsortedChildren:items presortedOrder:PGSortInnateOrder];

	return YES;
}

#pragma mark -PGResourceAdapter

- (void)load
{
	if([self _createChildren]) [[self node] loadFinishedForAdapter:self];
	else [[self node] fallbackFromFailedAdapter:self];
}

@end
