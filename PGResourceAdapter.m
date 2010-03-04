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
#import "PGResourceAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGDataProvider.h"

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGCFMutableArray.h"
#import "PGDebug.h"
#import "PGFoundationAdditions.h"
#import "PGGeometry.h"

NSString *const PGPasswordKey = @"PGPassword";

static NSString *const PGBundleTypeFourCCsKey = @"PGBundleTypeFourCCs";
static NSString *const PGLSItemContentTypes = @"LSItemContentTypes";
static NSString *const PGCFBundleTypeMIMETypesKey = @"CFBundleTypeMIMETypes";
static NSString *const PGCFBundleTypeOSTypesKey = @"CFBundleTypeOSTypes";
static NSString *const PGCFBundleTypeExtensionsKey = @"CFBundleTypeExtensions";

static NSString *const PGOrientationKey = @"PGOrientation";

#define PGThumbnailSize 128.0f

@interface PGThumbnailGenerationOperation : NSOperation
{
	@private
	PGResourceAdapter *_adapter;
	PGOrientation _baseOrientation;
}

- (id)initWithResourceAdapter:(PGResourceAdapter *)adapter baseOrientation:(PGOrientation)baseOrientation;

@end

@implementation PGResourceAdapter

#pragma mark +PGResourceAdapter

+ (NSDictionary *)typesDictionary
{
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"PGResourceAdapterClasses"];
}
+ (NSArray *)supportedTypes
{
	NSMutableArray *const exts = [NSMutableArray array];
	NSDictionary *const types = [self typesDictionary];
	for(NSString *const classString in types) {
		id const adapterClass = NSClassFromString(classString);
		if(!adapterClass) continue;
		NSDictionary *const typeDict = [types objectForKey:classString];
		[exts addObjectsFromArray:[typeDict objectForKey:PGCFBundleTypeExtensionsKey]];
		for(NSString *const type in [typeDict objectForKey:PGCFBundleTypeOSTypesKey]) [exts addObject:PGOSTypeToStringQuoted(PGOSTypeFromString(type), YES)];
	}
	return exts;
}

#pragma mark -PGResourceAdapter

- (id)initWithNode:(PGNode *)node dataProvider:(PGDataProvider *)provider
{
	if((self = [super init])) {
		_node = node;
		_dataProvider = [provider retain];
		_activity = [[PGActivity alloc] initWithOwner:self];
	}
	return self;
}
@synthesize node = _node;
@synthesize dataProvider = _dataProvider;

#pragma mark -

- (PGContainerAdapter *)containerAdapter
{
	return [self parentAdapter];
}
- (PGContainerAdapter *)rootContainerAdapter
{
	return [[self parentAdapter] rootContainerAdapter];
}
- (NSUInteger)depth
{
	return [[self parentAdapter] depth] + 1;
}
- (PGRecursionPolicy)recursionPolicy
{
	PGContainerAdapter *const p = [self parentAdapter];
	return p ? [p descendantRecursionPolicy] : PGRecurseToMaxDepth;
}
- (BOOL)shouldRecursivelyCreateChildren
{
	switch([self recursionPolicy]) {
		case PGRecurseToMaxDepth: return [self depth] <= [[[NSUserDefaults standardUserDefaults] objectForKey:PGMaxDepthKey] unsignedIntegerValue] + 1;
		case PGRecurseToAnyDepth: return YES;
		case PGRecurseNoFurther: return NO;
	}
	PGAssertNotReached(@"Invalid recursion policy.");
	return NO;
}

#pragma mark -

- (NSData *)data
{
	return [[self dataProvider] data];
}
- (BOOL)canGetData
{
	return [[self dataProvider] hasData];
}
- (BOOL)hasNodesWithData
{
	return [self canGetData];
}

#pragma mark -

- (BOOL)isContainer
{
	return NO;
}
- (BOOL)hasChildren
{
	return NO;
}
- (BOOL)isSortedFirstViewableNodeOfFolder
{
	PGContainerAdapter *const container = [self containerAdapter];
	return !container || [container sortedFirstViewableNodeInFolderFirst:YES] == [self node];
}
- (BOOL)hasRealThumbnail
{
	return !!_realThumbnail;
}
- (BOOL)isResolutionIndependent
{
	return NO;
}
- (BOOL)canSaveData
{
	return NO;
}
- (BOOL)hasSavableChildren
{
	return NO;
}

#pragma mark -

- (NSUInteger)viewableNodeIndex
{
	return [[self parentAdapter] viewableIndexOfChild:[self node]];
}
- (NSUInteger)viewableNodeCount
{
	return [[self node] isViewable] ? 1 : 0;
}
- (BOOL)hasViewableNodeCountGreaterThan:(NSUInteger)anInt
{
	return [self viewableNodeCount] > anInt;
}

#pragma mark -

- (BOOL)adapterIsViewable
{
	return NO;
}
- (void)loadIfNecessary
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init]; // We load recursively, so memory use can be a problem.
	[self load];
	[pool release];
}
- (void)load
{
	[[self node] loadSucceededForAdapter:self];
}
- (void)fallbackLoad
{
	[self load];
}
- (BOOL)shouldFallbackOnError
{
	return YES;
}
- (void)read
{
	[[self node] readFinishedWithImageRep:nil];
}

#pragma mark -

- (NSImage *)thumbnail
{
	NSImage *const realThumbnail = [self realThumbnail];
	if(realThumbnail) return realThumbnail;
	if([self canGenerateRealThumbnail] && !_thumbnailGenerationOperation) {
		_thumbnailGenerationOperation = [[PGThumbnailGenerationOperation alloc] initWithResourceAdapter:self baseOrientation:[[self document] baseOrientation]];
		[[self document] addOperation:_thumbnailGenerationOperation];
	}
	return [self fastThumbnail];
}
- (NSImage *)fastThumbnail
{
	NSImage *const thumbnail = [[self dataProvider] icon];
	[thumbnail setSize:NSMakeSize(PGThumbnailSize, PGThumbnailSize)];
	return thumbnail;
}
- (NSImage *)realThumbnail
{
	return [[_realThumbnail retain] autorelease];
}
- (void)setRealThumbnail:(NSImage *)anImage
{
	if(anImage != _realThumbnail) {
		[_realThumbnail release];
		_realThumbnail = [anImage retain];
		[[self document] noteNodeThumbnailDidChange:[self node] recursively:NO];
	}
	[_thumbnailGenerationOperation cancel];
	[_thumbnailGenerationOperation release];
	_thumbnailGenerationOperation = nil;
}
- (BOOL)canGenerateRealThumbnail
{
	return NO;
}
- (void)invalidateThumbnail
{
	if(![self canGenerateRealThumbnail]) return;
	[_realThumbnail release];
	_realThumbnail = nil;
	[_thumbnailGenerationOperation cancel];
	[_thumbnailGenerationOperation release];
	_thumbnailGenerationOperation = nil;
	(void)[self thumbnail];
}

#pragma mark -

- (NSDictionary *)imageProperties
{
	return nil;
}
- (PGOrientation)orientationWithBase:(BOOL)flag
{
	return flag ? [[self document] baseOrientation] : PGUpright;
}
- (void)clearCache {}
- (void)addChildrenToMenu:(NSMenu *)menu {}

#pragma mark -

- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident
{
	return PGEqualObjects(ident, [[self node] identifier]) ? [self node] : nil;
}

- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
{
	return [self sortedViewableNodeFirst:flag stopAtNode:nil includeSelf:YES];
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag stopAtNode:(PGNode *)descendent includeSelf:(BOOL)includeSelf
{
	return includeSelf && [[self node] isViewable] && [self node] != descendent ? [self node] : nil;
}

- (PGNode *)sortedViewableNodeNext:(BOOL)flag
{
	return [self sortedViewableNodeNext:flag includeChildren:YES];
}
- (PGNode *)sortedViewableNodeNext:(BOOL)flag includeChildren:(BOOL)children
{
	return [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] inclusive:NO withSelector:@selector(sortedViewableNodeFirst:) context:nil];
}
- (PGNode *)sortedViewableNodeNext:(BOOL)flag afterRemovalOfChildren:(NSArray *)removedChildren fromNode:(PGNode *)changedNode
{
	if(!removedChildren) return [self node];
	PGNode *const potentiallyRemovedAncestor = [[self node] ancestorThatIsChildOfNode:changedNode];
	if(!potentiallyRemovedAncestor || NSNotFound == [removedChildren indexOfObjectIdenticalTo:potentiallyRemovedAncestor]) return [self node];
	return [[[self sortedViewableNodeNext:flag] resourceAdapter] sortedViewableNodeNext:flag afterRemovalOfChildren:removedChildren fromNode:changedNode];
}

- (PGNode *)sortedFirstViewableNodeInFolderNext:(BOOL)forward inclusive:(BOOL)inclusive
{
	PGNode *const node = [[self parentAdapter] outwardSearchForward:forward fromChild:[self node] inclusive:inclusive withSelector:@selector(sortedFirstViewableNodeInFolderFirst:) context:nil];
	return node || forward ? node : [[self rootContainerAdapter] sortedViewableNodeFirst:YES stopAtNode:[self node] includeSelf:YES];
}
- (PGNode *)sortedFirstViewableNodeInFolderFirst:(BOOL)flag
{
	return nil;
}
- (PGNode *)sortedViewableNodeInFolderFirst:(BOOL)flag
{
	PGContainerAdapter *ancestor = [self parentAdapter];
	while(ancestor) {
		PGNode *const node = [ancestor sortedViewableNodeFirst:flag];
		if([self node] != node) return node;
		ancestor = [ancestor parentAdapter];
	}
	return nil;
}

- (PGNode *)sortedViewableNodeNext:(BOOL)flag matchSearchTerms:(NSArray *)terms
{
	PGNode *const node = [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] inclusive:NO withSelector:@selector(sortedViewableNodeFirst:matchSearchTerms:stopAtNode:) context:terms];
	return node ? node : [[self rootContainerAdapter] sortedViewableNodeFirst:flag matchSearchTerms:terms stopAtNode:[self node]];
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag matchSearchTerms:(NSArray *)terms stopAtNode:(PGNode *)descendent
{
	return [[self node] isViewable] && [self node] != descendent && [[[[self node] identifier] displayName] PG_matchesSearchTerms:terms] ? [self node] : nil;
}

#pragma mark -

- (void)noteResourceDidChange {}

#pragma mark -NSObject

- (id)init
{
	PGAssertNotReached(@"Invalid initializer, use -initWithNode:dataProvider: instead."); // TODO: Remove this once we've confirmed that nobody is calling it.
	[self release];
	return nil;
}
- (void)dealloc
{
	[_activity invalidate];

	[_dataProvider release];
	[_realThumbnail release];
	[_thumbnailGenerationOperation release];
	[_activity release];
	[super dealloc];
}

#pragma mark -<NSObject>

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p: %@>", [self class], self, [self dataProvider]];
}

#pragma mark -<PGActivityOwner>

- (PGActivity *)activity
{
	return [[_activity retain] autorelease];
}
- (NSString *)descriptionForActivity:(PGActivity *)activity
{
	return [[[self node] identifier] displayName];
}

#pragma mark -<PGResourceAdapting>

- (PGNode *)parentNode
{
	return [[self parentAdapter] node];
}
- (PGContainerAdapter *)parentAdapter
{
	return [_node parentAdapter];
}
- (PGNode *)rootNode
{
	return [[self node] rootNode];
}
- (PGDocument *)document
{
	return [_node document];
}

#pragma mark -

- (void)noteFileEventDidOccurDirect:(BOOL)flag {}
- (void)noteSortOrderDidChange {}

@end

@implementation PGThumbnailGenerationOperation

#pragma mark -PGThumbnailGenerationOperation

- (id)initWithResourceAdapter:(PGResourceAdapter *)adapter baseOrientation:(PGOrientation)baseOrientation
{
	if((self = [super init])) {
		_adapter = [adapter retain];
		_baseOrientation = baseOrientation;
	}
	return self;
}

#pragma mark -NSOperation

- (void)main
{
	if([self isCancelled]) return;
	NSImageRep *const rep = [_adapter threaded_thumbnailRepWithSize:NSMakeSize(PGThumbnailSize, PGThumbnailSize) baseOrientation:_baseOrientation];
	if(!rep || [self isCancelled]) return;
	NSImage *const image = [[[NSImage alloc] initWithSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])] autorelease];
	[image addRepresentation:rep];
	if([self isCancelled]) return;
	[_adapter performSelectorOnMainThread:@selector(setRealThumbnail:) withObject:image waitUntilDone:NO];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_adapter release];
	[super dealloc];
}

@end

@implementation PGDataProvider(PGResourceAdapterLoading)

- (NSArray *)adapterClassesForNode:(PGNode *)node
{
	NSParameterAssert(node);
	NSDictionary *const types = [PGResourceAdapter typesDictionary];
	NSMutableDictionary *const adapterByPriority = [NSMutableDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:0], [PGResourceAdapter class], nil]; // TODO: This conflicts with PGErrorAdapter, which gets inserted afterward and therefore never has a chance to be used.
	for(NSString *const classString in types) {
		Class const class = NSClassFromString(classString);
		if(!class) continue;
		NSDictionary *const typeDict = [types objectForKey:classString];
		NSUInteger const p = [self matchPriorityForTypeDictionary:typeDict];
		if(p) [adapterByPriority setObject:[NSNumber numberWithUnsignedInteger:p] forKey:class];
	}
	return [adapterByPriority keysSortedByValueUsingSelector:@selector(compare:)];
}
- (NSArray *)adaptersForNode:(PGNode *)node
{
	NSMutableArray *const adapters = [NSMutableArray array];
	for(Class const class in [self adapterClassesForNode:node]) [adapters addObject:[[[class alloc] initWithNode:node dataProvider:self] autorelease]];
	return adapters;
}
- (NSUInteger)matchPriorityForTypeDictionary:(NSDictionary *)dict
{
	if([[dict objectForKey:PGBundleTypeFourCCsKey] containsObject:[self fourCCData]]) return 5;
	if([[dict objectForKey:PGLSItemContentTypes] containsObject:[self UTIType]]) return 4;
	if([[dict objectForKey:PGCFBundleTypeMIMETypesKey] containsObject:[self MIMEType]]) return 3;
	if([[dict objectForKey:PGCFBundleTypeOSTypesKey] containsObject:PGOSTypeToStringQuoted([self typeCode], NO)]) return 2;
	if([[dict objectForKey:PGCFBundleTypeExtensionsKey] containsObject:[[self extension] lowercaseString]]) return 1;
	return 0;
}

@end
