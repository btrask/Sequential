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

@interface PGPDFAdapter(Private)

@property(readonly) NSPDFImageRep *_rep;
@property(readonly) NSPDFImageRep *_threaded_rep;

@end

@implementation PGPDFAdapter

#pragma mark Private Protocol

- (NSPDFImageRep *)_rep
{
	return [[_rep retain] autorelease];
}
- (NSPDFImageRep *)_threaded_rep
{
	@synchronized(self) {
		return [[_threadedRep retain] autorelease];
	}
	return nil;
}

#pragma mark PGResourceAdapter

- (BOOL)canSaveData
{
	return YES;
}
- (BOOL)hasSavableChildren
{
	return NO;
}

#pragma mark -

- (PGLoadPolicy)descendentLoadPolicy
{
	return PGLoadAll;
}
- (void)load
{
	NSData *const data = [self data];
	if(!data) return [[self node] loadFinished];
	if(![NSPDFImageRep canInitWithData:data]) return [[self node] loadFinished];
	_rep = [[NSPDFImageRep alloc] initWithData:data];
	if(!_rep) return [[self node] loadFinished];
	_threadedRep = [_rep copy];

	NSDictionary *const localeDict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
	NSMutableArray *const nodes = [NSMutableArray array];
	NSInteger i = 0;
	for(; i < [_rep pageCount]; i++) {
		PGDisplayableIdentifier *const identifier = [[[[self node] identifier] subidentifierWithIndex:i] displayableIdentifier];
		[identifier setNaturalDisplayName:[[NSNumber numberWithUnsignedInteger:i + 1] descriptionWithLocale:localeDict]];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:identifier dataSource:nil] autorelease];
		if(!node) continue;
		[node startLoadWithInfo:[NSDictionary dictionaryWithObjectsAndKeys:[PGPDFPageAdapter class], PGAdapterClassKey, nil]];
		[nodes addObject:node];
	}
	[self setUnsortedChildren:nodes presortedOrder:PGSortInnateOrder];
	[[self node] loadFinished];
}

#pragma mark NSObject

- (void)dealloc
{
	[_rep release];
	@synchronized(self) {
		[_threadedRep release];
		_threadedRep = nil;
	}
	[super dealloc];
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
	NSInteger const index = [[[self node] identifier] index];
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
	NSPDFImageRep *const rep = [(PGPDFAdapter *)[self parentAdapter] _rep];
	[rep setCurrentPage:[[[self node] identifier] index]];
	[[self node] readFinishedWithImageRep:rep error:nil];
}

#pragma mark -

- (BOOL)canGenerateRealThumbnail
{
	return YES;
}

#pragma mark -PGResourceAdapter(PGAbstract)

- (NSImageRep *)threaded_thumbnailRepOfSize:(NSSize)size withInfo:(NSDictionary *)info
{
	NSPDFImageRep *rep = nil;
	@synchronized(self) {
		rep = [(PGPDFAdapter *)[self parentAdapter] _threaded_rep];
	}
	if(rep) @synchronized(rep) {
		[rep setCurrentPage:[[[self node] identifier] index]];
		return [rep PG_thumbnailWithMaxSize:size orientation:[[info objectForKey:PGOrientationKey] unsignedIntegerValue] opaque:YES];
	}
	return nil;
}

@end
