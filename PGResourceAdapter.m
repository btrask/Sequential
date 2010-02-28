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

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGCFMutableArray.h"
#import "PGFoundationAdditions.h"
#import "PGGeometry.h"

NSString *const PGSubstitutedClassKey = @"PGSubstitutedClass";

NSString *const PGBundleTypeFourCCsKey      = @"PGBundleTypeFourCCs";
NSString *const PGCFBundleTypeMIMETypesKey  = @"CFBundleTypeMIMETypes";
NSString *const PGCFBundleTypeOSTypesKey    = @"CFBundleTypeOSTypes";
NSString *const PGCFBundleTypeExtensionsKey = @"CFBundleTypeExtensions";

NSString *const PGOrientationKey = @"PGOrientation";
NSString *const PGDateKey        = @"PGDate";

#define PGThumbnailSize 128

@interface PGThumbnailGenerationOperation : NSOperation
{
	@private
	PGResourceAdapter *_adapter;
	NSDictionary *_info;
}

- (id)initWithResourceAdapter:(PGResourceAdapter *)adapter info:(NSDictionary *)info;

@end

@interface PGResourceAdapter(Private)

- (id)_initWithPriority:(PGMatchPriority)priority info:(NSDictionary *)info;
- (NSComparisonResult)_matchPriorityCompare:(PGResourceAdapter *)adapter;

- (void)_setRealThumbnailWithDictionary:(NSDictionary *)aDict;

@end

@implementation PGResourceAdapter

#pragma mark +PGResourceAdapter

+ (NSDictionary *)typesDictionary
{
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"PGResourceAdapterClasses"];
}
+ (NSDictionary *)typeDictionary
{
	return [[self typesDictionary] objectForKey:NSStringFromClass(self)];
}
+ (NSArray *)supportedExtensionsWhichMustAlwaysLoad:(BOOL)flag
{
	NSMutableArray *const exts = [NSMutableArray array];
	NSDictionary *const types = [self typesDictionary];
	for(NSString *const classString in types) {
		id const adapterClass = NSClassFromString(classString);
		if(!adapterClass || (flag && ![adapterClass alwaysLoads])) continue;
		NSDictionary *const typeDict = [types objectForKey:classString];
		[exts addObjectsFromArray:[typeDict objectForKey:PGCFBundleTypeExtensionsKey]];
		for(NSString *const type in [typeDict objectForKey:PGCFBundleTypeOSTypesKey]) [exts addObject:PGOSTypeToStringQuoted(PGOSTypeFromString(type), YES)];
	}
	return exts;
}
+ (NSArray *)adapterClassesInstantiated:(BOOL)flag forNode:(PGNode *)node withInfoDicts:(NSArray *)dicts
{
	NSParameterAssert(node);
	NSParameterAssert(dicts);
	NSMutableArray *const adapters = [NSMutableArray array];
	NSDictionary *const types = [self typesDictionary];
	for(NSDictionary *const info in dicts) {
		Class const agreedClass = [info objectForKey:PGAdapterClassKey];
		if(agreedClass) {
			[adapters addObject:flag ? [[[agreedClass alloc] _initWithPriority:PGMatchByPriorAgreement info:info] autorelease] : agreedClass];
			continue;
		}
		for(NSString *const classString in types) {
			Class const class = NSClassFromString(classString);
			if(![node shouldLoadAdapterClass:class]) continue;
			NSMutableDictionary *const mutableInfo = [[info mutableCopy] autorelease];
			PGMatchPriority const p = [class matchPriorityForNode:node withInfo:mutableInfo];
			if(!p) continue;
			Class altClass = [mutableInfo objectForKey:PGSubstitutedClassKey];
			if(!altClass) altClass = class;
			[adapters addObject:flag ? [[[altClass alloc] _initWithPriority:p info:mutableInfo] autorelease] : altClass];
		}
	}
	if(flag) [adapters sortUsingSelector:@selector(_matchPriorityCompare:)];
	return adapters;
}
+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node withInfo:(NSMutableDictionary *)info
{
	if([[info objectForKey:PGDataExistenceKey] integerValue] == PGDoesNotExist) return PGNotAMatch;
	NSDictionary *const type = [self typeDictionary];
	if([[type objectForKey:PGBundleTypeFourCCsKey] containsObject:[info objectForKey:PGFourCCDataKey]]) return PGMatchByFourCC;
	if([[type objectForKey:PGCFBundleTypeMIMETypesKey] containsObject:[info objectForKey:PGMIMETypeKey]]) return PGMatchByMIMEType;
	if([[type objectForKey:PGCFBundleTypeOSTypesKey] containsObject:[info objectForKey:PGOSTypeKey]]) return PGMatchByOSType;
	if([[type objectForKey:PGCFBundleTypeExtensionsKey] containsObject:[[info objectForKey:PGExtensionKey] lowercaseString]]) return PGMatchByExtension;
	return PGNotAMatch;
}
+ (BOOL)alwaysLoads
{
	return [PGResourceAdapter class] != self;
}

#pragma mark -PGResourceAdapter

- (PGNode *)node
{
	return _node;
}
- (void)setNode:(PGNode *)aNode
{
	@synchronized(self) {
		if(aNode == _node) return;
		_node = aNode;
	}
	PGResourceAdapter *const parent = [self parentAdapter];
	[_activity setParentActivity:parent ? [parent activity] : [[self document] activity]];
	[[self node] noteIsViewableDidChange];
}

#pragma mark -

- (PGContainerAdapter *)containerAdapter
{
	return [self parentAdapter];
}
- (PGContainerAdapter *)rootContainerAdapter
{
	return [[self parentAdapter] rootContainerAdapter];
}

#pragma mark -

- (PGDisplayableIdentifier *)identifier
{
	return [[self node] identifier];
}
- (NSMutableDictionary *)info
{
	return [[_info retain] autorelease];
}
- (NSData *)data
{
	return [[self node] dataWithInfo:_info fast:NO];
}
- (BOOL)canGetData
{
	return [[self node] canGetDataWithInfo:_info];
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

- (NSArray *)exifEntries
{
	return nil;
}
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
- (BOOL)shouldLoad
{
	return [[self node] shouldLoadAdapterClass:[self class]];
}
- (PGLoadPolicy)descendentLoadPolicy
{
	return PGLoadToMaxDepth;
}
- (void)loadIfNecessary
{
	if(![self shouldLoad]) return [[self node] loadFinished];
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init]; // We load recursively, so memory use can be a problem.
	[self load];
	[pool release];
}
- (void)load
{
	[[self node] loadFinished];
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
	[[self node] readFinishedWithImageRep:nil error:nil];
}

#pragma mark -

- (NSImage *)thumbnail
{
	NSImage *const realThumbnail = [self realThumbnail];
	if(realThumbnail) return realThumbnail;
	if([self canGenerateRealThumbnail] && !_thumbnailGenerationOperation) {
		NSMutableDictionary *const info = [[[self info] mutableCopy] autorelease];
		[info setObject:[NSNumber numberWithUnsignedInteger:[self orientationWithBase:NO]] forKey:PGOrientationKey];
		[info setObject:[NSDate date] forKey:PGDateKey];
		_thumbnailGenerationOperation = [[PGThumbnailGenerationOperation alloc] initWithResourceAdapter:self info:info];
		[[self document] addOperation:_thumbnailGenerationOperation];
	}
	return [self fastThumbnail];
}
- (NSImage *)fastThumbnail
{
	NSImage *thumbnail = nil;
	do {
		PGResourceIdentifier *const ident = [[self node] identifier];
		if([ident isFileIdentifier]) {
			NSURL *const URL = [ident URL];
			if(URL && [URL isFileURL]) thumbnail = [[NSWorkspace sharedWorkspace] iconForFile:[URL path]];
		}
		if(thumbnail) break;
		NSDictionary *const info = [self info];
		do {
			OSType osType = PGOSTypeFromString([info objectForKey:PGOSTypeKey]);
			NSString *const mimeType = [info objectForKey:PGMIMETypeKey];
			if(!osType && !mimeType) break;
			if('fold' == osType) osType = kGenericFolderIcon;
			IconRef iconRef = NULL;
			if(noErr != GetIconRefFromTypeInfo('????', osType, NULL, (CFStringRef)mimeType, kIconServicesNormalUsageFlag, &iconRef)) break;
			thumbnail = [[[NSImage alloc] initWithIconRef:iconRef] autorelease];
			ReleaseIconRef(iconRef);
		} while(NO);
		if(thumbnail) break;
		NSString *const extension = [info objectForKey:PGExtensionKey];
		if(extension) thumbnail = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
		if(thumbnail) break;
		thumbnail = [[NSWorkspace sharedWorkspace] iconForFileType:@""];
	} while(NO);
	[thumbnail setSize:NSMakeSize(PGThumbnailSize, PGThumbnailSize)]; // -iconForFile: returns images "sized" at 32x32, although they actually contain reps of at least 128x128. Our thumbnail view checks the size and doesn't upscale beyond that, though.
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
- (NSImage *)threaded_thumbnailOfSize:(NSSize)size withInfo:(NSDictionary *)info
{
	NSImageRep *const rep = [self threaded_thumbnailRepOfSize:size withInfo:info];
	if(!rep) return nil;
	NSImage *const image = [[[NSImage alloc] initWithSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])] autorelease];
	[image addRepresentation:rep];
	return image;
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

- (PGOrientation)orientationWithBase:(BOOL)flag
{
	return flag ? [[self document] baseOrientation] : PGUpright;
}
- (void)addMenuItemsToMenu:(NSMenu *)aMenu
{
	[[[self node] menuItem] PG_removeFromMenu];
	[aMenu addItem:[[self node] menuItem]];
}
- (void)clearCache {}

#pragma mark -

- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident
{
	return PGEqualObjects(ident, [self identifier]) ? [self node] : nil;
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
	return [[self node] isViewable] && [self node] != descendent && [[[self identifier] displayName] PG_matchesSearchTerms:terms] ? [self node] : nil;
}

#pragma mark -

- (void)noteResourceDidChange {}

#pragma mark -PGResourceAdapter(Private)

- (id)_initWithPriority:(PGMatchPriority)priority info:(NSDictionary *)info
{
	if((self = [self init])) {
		_priority = priority;
		[[self info] addEntriesFromDictionary:info];
	}
	return self;
}
- (NSComparisonResult)_matchPriorityCompare:(PGResourceAdapter *)adapter
{
	NSParameterAssert([adapter isKindOfClass:[PGResourceAdapter class]]);
	if(_priority < adapter->_priority) return NSOrderedAscending;
	if(_priority > adapter->_priority) return NSOrderedDescending;
	return NSOrderedSame;
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		_info = [[NSMutableDictionary alloc] init];
		_activity = [[PGActivity alloc] initWithOwner:self];
	}
	return self;
}
- (void)dealloc
{
	[_activity invalidate];

	[_info release];
	[_realThumbnail release];
	[_thumbnailGenerationOperation release];
	[_activity release];
	[super dealloc];
}

#pragma mark -<NSObject>

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p: %@>", [self class], self, [[self node] identifier]];
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

- (id)initWithResourceAdapter:(PGResourceAdapter *)adapter info:(NSDictionary *)info
{
	if((self = [super init])) {
		_adapter = [adapter retain];
		_info = [info copy];
	}
	return self;
}

#pragma mark -NSOperation

- (void)main
{
	if([self isCancelled]) return;
	NSImage *const thumbnail = [_adapter threaded_thumbnailOfSize:NSMakeSize(PGThumbnailSize, PGThumbnailSize) withInfo:_info];
	if([self isCancelled]) return;
	[_adapter performSelectorOnMainThread:@selector(setRealThumbnail:) withObject:thumbnail waitUntilDone:NO];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_adapter release];
	[_info release];
	[super dealloc];
}

@end
