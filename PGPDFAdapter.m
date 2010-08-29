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
#import "PGPDFAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGGeometry.h"

@interface PGPDFPageAdapter : PGResourceAdapter

@end

@interface PGPDFDataProvider : PGDataProvider
{
	@private
	NSPDFImageRep *_mainRep;
	NSPDFImageRep *_threadRep;
	NSInteger _pageIndex;
}

- (id)initWithMainRep:(NSPDFImageRep *)mainRep threadRep:(NSPDFImageRep *)threadRep pageIndex:(NSInteger)page;
@property(readonly) NSPDFImageRep *mainRep;
@property(readonly) NSPDFImageRep *threadRep;
@property(readonly) NSInteger pageIndex;

@end

@implementation PGPDFAdapter

#pragma mark -PGContainerAdapter

- (PGRecursionPolicy)descendantRecursionPolicy
{
	return PGRecurseToAnyDepth;
}

#pragma mark -PGResourceAdapter

- (void)load
{
	NSData *const data = [self data];
	if(!data || ![NSPDFImageRep canInitWithData:data]) return [[self node] loadFinishedForAdapter:self];
	NSPDFImageRep *const mainRep = [[[NSPDFImageRep alloc] initWithData:data] autorelease];
	if(!mainRep) return [[self node] fallbackFromFailedAdapter:self];
	NSPDFImageRep *const threadRep = [[mainRep copy] autorelease];

	NSDictionary *const localeDict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
	NSMutableArray *const nodes = [NSMutableArray array];
	NSInteger i = 0;
	for(; i < [mainRep pageCount]; i++) {
		PGDisplayableIdentifier *const identifier = [[[[self node] identifier] subidentifierWithIndex:i] displayableIdentifier];
		[identifier setNaturalDisplayName:[[NSNumber numberWithUnsignedInteger:i + 1] descriptionWithLocale:localeDict]];
		PGNode *const node = [[[PGNode alloc] initWithParent:self identifier:identifier] autorelease];
		if(!node) continue;
		[node setDataProvider:[[[PGPDFDataProvider alloc] initWithMainRep:mainRep threadRep:threadRep pageIndex:i] autorelease]];
		[nodes addObject:node];
	}
	[self setUnsortedChildren:nodes presortedOrder:PGSortInnateOrder];
	[[self node] loadFinishedForAdapter:self];
}

#pragma mark -

- (BOOL)canSaveData
{
	return YES;
}
- (BOOL)hasSavableChildren
{
	return NO;
}

@end

@implementation PGPDFPageAdapter

#pragma mark -PGResourceAdapter

- (BOOL)isResolutionIndependent
{
	return YES;
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag matchSearchTerms:(NSArray *)terms stopAtNode:(PGNode *)descendent
{
	if(![[self node] isViewable] || [self node] == descendent) return nil;
	NSInteger const index = [[self dataProvider] pageIndex];
	if(NSNotFound == index) return nil;
	for(id const term in terms) if(![term isKindOfClass:[NSNumber class]] || [term integerValue] - 1 != index) return nil;
	return [self node];
}

#pragma mark -

- (BOOL)adapterIsViewable
{
	return YES;
}
- (void)read
{
	NSPDFImageRep *const rep = [[self dataProvider] mainRep];
	[rep setCurrentPage:[[self dataProvider] pageIndex]];
	[[self node] readFinishedWithImageRep:rep];
}

#pragma mark -

- (BOOL)canGenerateRealThumbnail
{
	return YES;
}

#pragma mark -PGResourceAdapter(PGAbstract)

- (NSImageRep *)threaded_thumbnailRepWithSize:(NSSize)size
{
	NSPDFImageRep *const rep = [(PGPDFDataProvider *)[self dataProvider] threadRep];
	if(rep) @synchronized(rep) {
		[rep setCurrentPage:[[self dataProvider] pageIndex]];
		return [rep PG_thumbnailWithMaxSize:size orientation:PGUpright opaque:YES];
	}
	return nil;
}

@end

@implementation PGPDFDataProvider

#pragma mark -PGPDFDataProvider

- (id)initWithMainRep:(NSPDFImageRep *)mainRep threadRep:(NSPDFImageRep *)threadRep pageIndex:(NSInteger)page
{
	if((self = [super init])) {
		_mainRep = [mainRep retain];
		_threadRep = [threadRep retain];
		_pageIndex = page;
	}
	return self;
}
@synthesize mainRep = _mainRep;
@synthesize threadRep = _threadRep;
@synthesize pageIndex = _pageIndex;

#pragma mark -PGDataProvider(PGResourceAdapterLoading)

- (NSArray *)adapterClassesForNode:(PGNode *)node
{
	return [NSArray arrayWithObject:[PGPDFPageAdapter class]];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_mainRep release];
	[_threadRep release];
	[super dealloc];
}

@end
