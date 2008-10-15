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
#import "PGResourceAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"

// Categories
#import "NSMenuItemAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGSubstitutedClassKey = @"PGSubstitutedClass";

NSString *const PGBundleTypeFourCCsKey      = @"PGBundleTypeFourCCs";
NSString *const PGCFBundleTypeMIMETypesKey  = @"CFBundleTypeMIMETypes";
NSString *const PGCFBundleTypeOSTypesKey    = @"CFBundleTypeOSTypes";
NSString *const PGCFBundleTypeExtensionsKey = @"CFBundleTypeExtensions";

@interface PGResourceAdapter (Private)

- (id)_initWithPriority:(PGMatchPriority)priority info:(NSDictionary *)info;
- (NSComparisonResult)_matchPriorityCompare:(PGResourceAdapter *)adapter;

@end

@implementation PGResourceAdapter

#pragma mark Class Methods

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
	NSString *classString;
	NSEnumerator *const classStringEnum = [types keyEnumerator];
	while((classString = [classStringEnum nextObject])) {
		id const adapterClass = NSClassFromString(classString);
		if(!adapterClass || (flag && ![adapterClass alwaysLoads])) continue;
		NSDictionary *const typeDict = [types objectForKey:classString];
		[exts addObjectsFromArray:[typeDict objectForKey:PGCFBundleTypeExtensionsKey]];
		NSArray *const OSTypes = [typeDict objectForKey:PGCFBundleTypeOSTypesKey];
		if(!OSTypes || ![OSTypes count]) continue;
		NSString *type;
		NSEnumerator *const typeEnum = [OSTypes objectEnumerator];
		while((type = [typeEnum nextObject])) [exts addObject:NSFileTypeForHFSTypeCode(PGHFSTypeCodeForPseudoFileType(type))];
	}
	return exts;
}
+ (NSArray *)adapterClassesInstantiated:(BOOL)flag
             forNode:(PGNode *)node
             withInfoDicts:(NSArray *)dicts
{
	NSParameterAssert(node);
	NSParameterAssert(dicts);
	NSMutableArray *const adapters = [NSMutableArray array];
	NSDictionary *const types = [self typesDictionary];
	NSDictionary *info;
	NSEnumerator *const infoEnum = [dicts objectEnumerator];
	while((info = [infoEnum nextObject])) {
		Class const agreedClass = [info objectForKey:PGAdapterClassKey];
		if(agreedClass) {
			[adapters addObject:(flag ? [[[agreedClass alloc] _initWithPriority:PGMatchByPriorAgreement info:info] autorelease] : agreedClass)];
			continue;
		}
		NSString *classString;
		NSEnumerator *const classStringEnum = [types keyEnumerator];
		while((classString = [classStringEnum nextObject])) {
			Class const class = NSClassFromString(classString);
			if(![node shouldLoadAdapterClass:class]) continue;
			NSMutableDictionary *const mutableInfo = [[info mutableCopy] autorelease];
			PGMatchPriority const p = [class matchPriorityForNode:node withInfo:mutableInfo];
			if(!p) continue;
			Class altClass = [mutableInfo objectForKey:PGSubstitutedClassKey];
			if(!altClass) altClass = class;
			[adapters addObject:(flag ? [[[altClass alloc] _initWithPriority:p info:mutableInfo] autorelease] : altClass)];
		}
	}
	if(flag) [adapters sortUsingSelector:@selector(_matchPriorityCompare:)];
	return adapters;
}
+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	if([[info objectForKey:PGDataExistenceKey] intValue] == PGDoesNotExist) return PGNotAMatch;
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

#pragma mark Instance Methods

- (PGNode *)node
{
	return _node;
}
- (void)setNode:(PGNode *)aNode
{
	@synchronized(self) {
		if(aNode == _node) return;
		_node = aNode;
		[self noteIsViewableDidChange];
	}
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
- (void)read
{
	[[self node] readFinishedWithImageRep:nil error:nil];
}

- (NSImage *)thumbnail
{
	return [[self identifier] icon];
}

#pragma mark -

- (void)noteResourceDidChange {}

#pragma mark Private Protocol

- (id)_initWithPriority:(PGMatchPriority)priority
      info:(NSDictionary *)info
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

#pragma mark PGResourceAdapting Protocol

- (PGNode *)parentNode
{
	return [[self parentAdapter] node];
}
- (PGContainerAdapter *)parentAdapter
{
	return [_node parentAdapter];
}
- (PGContainerAdapter *)containerAdapter
{
	return [self parentAdapter];
}
- (PGNode *)rootNode
{
	return [[self node] rootNode];
}
- (PGContainerAdapter *)rootContainerAdapter
{
	return [[self parentAdapter] rootContainerAdapter];
}
- (PGDocument *)document
{
	return [_node document];
}

#pragma mark -

- (PGResourceIdentifier *)identifier
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
- (BOOL)canExtractData
{
	return NO;
}

#pragma mark -

- (BOOL)isContainer
{
	return NO;
}
- (NSArray *)exifEntries
{
	return nil;
}
- (PGOrientation)orientation
{
	return [[self document] baseOrientation];
}
- (BOOL)isResolutionIndependent
{
	return NO;
}
- (void)clearCache {}

#pragma mark -

- (BOOL)hasViewableNodes
{
	return [[self node] isViewable];
}
- (BOOL)hasDataNodes
{
	return [[self node] canGetData];
}
- (unsigned)viewableNodeIndex
{
	return [[self parentAdapter] viewableIndexOfChild:[self node]];
}
- (unsigned)viewableNodeCount
{
	return [[self node] isViewable] ? 1 : 0;
}

#pragma mark -

- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
{
	return [self sortedViewableNodeFirst:flag stopAtNode:nil includeSelf:YES];
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
            stopAtNode:(PGNode *)descendent
            includeSelf:(BOOL)includeSelf
{
	return includeSelf && [[self node] isViewable] && [self node] != descendent ? [self node] : nil;
}

- (PGNode *)sortedViewableNodeNext:(BOOL)flag
{
	return [self sortedViewableNodeNext:flag includeChildren:YES];
}
- (PGNode *)sortedViewableNodeNext:(BOOL)flag
            includeChildren:(BOOL)children
{
	return [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] withSelector:@selector(sortedViewableNodeFirst:) context:nil];
}
- (PGNode *)sortedViewableNodeNext:(BOOL)flag
            afterRemovalOfChildren:(NSArray *)removedChildren
            fromNode:(PGNode *)changedNode
{
	if(!removedChildren) return [self node];
	PGNode *const potentiallyRemovedAncestor = [[self node] ancestorThatIsChildOfNode:changedNode];
	if(!potentiallyRemovedAncestor || NSNotFound == [removedChildren indexOfObjectIdenticalTo:potentiallyRemovedAncestor]) return [self node];
	return [[self sortedViewableNodeNext:flag] sortedViewableNodeNext:flag afterRemovalOfChildren:removedChildren fromNode:changedNode];
}

- (PGNode *)sotedFirstViewableNodeInFolderNext:(BOOL)flag
{
	PGNode *const node = [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] withSelector:@selector(sortedFirstViewableNodeInFolderFirst:) context:nil];
	return node || flag ? node : [[self rootContainerAdapter] sortedViewableNodeFirst:YES stopAtNode:[self node] includeSelf:YES];
}
- (PGNode *)sortedFirstViewableNodeInFolderFirst:(BOOL)flag
{
	return nil;
}

- (PGNode *)sortedViewableNodeNext:(BOOL)flag
	    matchSearchTerms:(NSArray *)terms
{
	PGNode *const node = [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] withSelector:@selector(sortedViewableNodeFirst:matchSearchTerms:stopAtNode:) context:terms];
	return node ? node : [[self rootContainerAdapter] sortedViewableNodeFirst:flag matchSearchTerms:terms stopAtNode:[self node]];
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
            matchSearchTerms:(NSArray *)terms
            stopAtNode:(PGNode *)descendent
{
	return [[self node] isViewable] && [self node] != descendent && [[[self identifier] displayName] AE_matchesSearchTerms:terms] ? [self node] : nil;
}

#pragma mark -

- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident
{
	return ident && [[self identifier] isEqual:ident] ? [self node] : nil;
}
- (PGNode *)ancestorThatIsChildOfNode:(PGNode *)aNode
{
	PGNode *const parent = [self parentNode];
	return aNode == parent ? [self node] : [parent ancestorThatIsChildOfNode:aNode];
}
- (BOOL)isDescendantOfNode:(PGNode *)aNode
{
	return [self ancestorThatIsChildOfNode:aNode] != nil;
}

#pragma mark -

- (void)addMenuItemsToMenu:(NSMenu *)aMenu
{
	[[[self node] menuItem] AE_removeFromMenu];
	[aMenu addItem:[[self node] menuItem]];
}

#pragma mark -

- (void)noteFileEventDidOccurDirect:(BOOL)flag
{
	[[self node] startLoadWithInfo:nil];
}
- (void)noteSortOrderDidChange {}
- (void)noteIsViewableDidChange
{
	[[self node] noteIsViewableDidChange];
}

#pragma mark PGLoading Protocol

- (NSString *)loadDescription
{
	return [[self identifier] displayName];
}
- (float)loadProgress
{
	return 0;
}
- (id<PGLoading>)parentLoad
{
	return [self parentAdapter] ? [self parentAdapter] : [PGLoadManager sharedLoadManager];
}
- (NSArray *)subloads
{
	return [[_subloads retain] autorelease];
}
- (void)setSubload:(id<PGLoading>)obj
        isLoading:(BOOL)flag
{
	if(!flag) [_subloads removeObjectIdenticalTo:obj];
	else if([_subloads indexOfObjectIdenticalTo:obj] == NSNotFound) [_subloads addObject:obj];
	[[self parentLoad] setSubload:[self node] isLoading:[_subloads count] != 0];
}
- (void)prioritizeSubload:(id<PGLoading>)obj
{
	unsigned const i = [_subloads indexOfObjectIdenticalTo:[[obj retain] autorelease]];
	if(NSNotFound == i) return;
	[_subloads removeObjectAtIndex:i];
	[_subloads insertObject:obj atIndex:0];
	[[self parentLoad] prioritizeSubload:[self node]];
}
- (void)cancelLoad
{
	[_subloads makeObjectsPerformSelector:@selector(cancelLoad)];
}

#pragma mark NSObject Protocol

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p: %@>", [self class], self, [self identifier]];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_info = [[NSMutableDictionary alloc] init];
		_subloads = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
	}
	return self;
}
- (void)dealloc
{
	[_info release];
	[_thumbnail release];
	[_subloads release];
	[super dealloc];
}

@end
