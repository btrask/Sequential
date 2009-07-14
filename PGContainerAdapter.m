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
#import "PGContainerAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGResourceIdentifier.h"

NSString *const PGMaxDepthKey = @"PGMaxDepth";

@interface PGContainerAdapter(Private)

- (PGNode *)_nodeForSelectorOrSelfIfViewable:(SEL)sel forward:(BOOL)flag;

@end

@implementation PGContainerAdapter

#pragma mark +PGResourceAdapter

+ (BOOL)alwaysLoads
{
	return NO;
}

#pragma mark -PGContainerAdapter

- (NSArray *)sortedChildren
{
	if(!_sortedChildren) {
		PGSortOrder const order = [[self document] sortOrder];
		PGSortOrder const maskedUnsortedOrder = PGSortOrderMask & _unsortedOrder;
		if((PGSortOrderMask & order) == maskedUnsortedOrder || PGSortInnateOrder == maskedUnsortedOrder) {
			if((PGSortDescendingMask & order) == (PGSortDescendingMask & _unsortedOrder)) _sortedChildren = [_unsortedChildren retain];
			else _sortedChildren = [[[_unsortedChildren reverseObjectEnumerator] allObjects] retain];
		} else _sortedChildren = [[_unsortedChildren sortedArrayUsingSelector:@selector(compare:)] retain];
	}
	return [[_sortedChildren retain] autorelease];
}
- (NSArray *)unsortedChildren
{
	return [[_unsortedChildren retain] autorelease];
}
- (void)setUnsortedChildren:(NSArray *)anArray
        presortedOrder:(PGSortOrder)anOrder
{
	if(anArray == _unsortedChildren) return;
	NSMutableArray *const removedChildren = [[_unsortedChildren mutableCopy] autorelease];
	PGNode *newChild;
	NSEnumerator *const newChildEnum = [anArray objectEnumerator];
	while((newChild = [newChildEnum nextObject])) [removedChildren removeObjectIdenticalTo:newChild];
	if([removedChildren count]) {
		[[self document] noteNode:[self node] willRemoveNodes:removedChildren];
		[removedChildren makeObjectsPerformSelector:@selector(detachFromTree)];
	}
	[_unsortedChildren release];
	_unsortedChildren = [anArray copy];
	_unsortedOrder = anOrder;
	[_sortedChildren release];
	_sortedChildren = nil;
	[[[self node] menuItem] setSubmenu:([[self unsortedChildren] count] ? [[[NSMenu alloc] init] autorelease] : nil)];
	[[self document] noteSortedChildrenDidChange];
}
- (void)removeChild:(PGNode *)node
{
	NSMutableArray *const unsortedChildren = [[_unsortedChildren mutableCopy] autorelease];
	[unsortedChildren removeObjectIdenticalTo:node];
	[self setUnsortedChildren:unsortedChildren presortedOrder:_unsortedOrder];
}

#pragma mark -

- (PGNode *)childForIdentifier:(PGResourceIdentifier *)anIdent
{
	PGNode *child;
	NSEnumerator *const childEnum = [_unsortedChildren objectEnumerator];
	while((child = [childEnum nextObject])) if([anIdent isEqual:[child identifier]]) return child;
	return nil;
}
- (unsigned)viewableIndexOfChild:(PGNode *)aNode
{
	unsigned index = [[self node] isViewable] ? 1 : 0;
	id child;
	NSEnumerator *const childEnum = [[self sortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) {
		if(child == aNode) return index + [[self parentAdapter] viewableIndexOfChild:[self node]];
		index += [[child resourceAdapter] viewableNodeCount];
	}
	return 0;
}
- (PGNode *)outwardSearchForward:(BOOL)forward fromChild:(PGNode *)start inclusive:(BOOL)inclusive withSelector:(SEL)sel context:(id)context
{
	NSArray *const children = [self sortedChildren];
	NSUInteger i = [children indexOfObjectIdenticalTo:start];
	if(NSNotFound == i) return nil;
	NSInteger const increment = forward ? 1 : -1;
	NSRange const range = NSMakeRange(0, [children count]);
	if(!inclusive) i += increment;
	for(; NSLocationInRange(i, range); i += increment) {
		PGNode *const child = [children objectAtIndex:i];
		PGNode *const node = [child methodForSelector:sel](child, sel, forward, context, nil);
		if(node) return node;
	}
	return [[self parentAdapter] outwardSearchForward:forward fromChild:[self node] inclusive:inclusive withSelector:sel context:context];
}
- (void)noteChild:(PGNode *)child
        didChangeForSortOrder:(PGSortOrder)order
{
	if([_unsortedChildren indexOfObjectIdenticalTo:child] == NSNotFound) return;
	if((PGSortOrderMask & order) != (PGSortOrderMask & [[self document] sortOrder])) return;
	[_sortedChildren release];
	_sortedChildren = nil;
	[[self document] noteSortedChildrenDidChange];
}

#pragma mark -PGResourceAdapter

- (void)setNode:(PGNode *)aNode
{
	[[[self node] menuItem] setSubmenu:nil];
	[super setNode:aNode];
	[[[self node] menuItem] setSubmenu:([[self unsortedChildren] count] ? [[[NSMenu alloc] init] autorelease] : nil)];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_unsortedChildren makeObjectsPerformSelector:@selector(detachFromTree)];
	[_sortedChildren release];
	[_unsortedChildren release];
	[super dealloc];
}

#pragma mark -<PGResourceAdapting>

- (PGContainerAdapter *)containerAdapter
{
	return self;
}
- (PGContainerAdapter *)rootContainerAdapter
{
	return [self parentAdapter] ? [[self parentAdapter] rootContainerAdapter] : self;
}

#pragma mark -

- (BOOL)hasNodesWithData
{
	if([self canGetData]) return YES;
	PGNode *child;
	NSEnumerator *const childEnum = [[self unsortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) if([[child resourceAdapter] hasNodesWithData]) return YES;
	return NO;
}
- (BOOL)isContainer
{
	return YES;
}
- (BOOL)hasSavableChildren
{
	PGNode *child;
	NSEnumerator *const childEnum = [[self unsortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) {
		PGResourceAdapter *childAdapter = [child resourceAdapter];
		if([childAdapter canSaveData] || [childAdapter hasSavableChildren]) return YES;
	}
	return NO;
}

#pragma mark -

- (unsigned)viewableNodeCount
{
	unsigned count = [[self node] isViewable] ? 1 : 0;
	PGNode *child;
	NSEnumerator *const childEnum = [[self unsortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) count += [[child resourceAdapter] viewableNodeCount];
	return count;
}
- (BOOL)hasViewableNodeCountGreaterThan:(unsigned)anInt
{
	unsigned count = [[self node] isViewable] ? 1 : 0;
	if(count > anInt) return YES;
	PGNode *child;
	NSEnumerator *const childEnum = [[self unsortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) {
		PGResourceAdapter *const adapter = [child resourceAdapter];
		if([adapter hasViewableNodeCountGreaterThan:anInt - count]) return YES;
		if(![child isViewable]) continue;
		count++;
		if(count > anInt) return YES;
	}
	return NO;
}

#pragma mark -

- (PGNode *)sortedViewableNodeNext:(BOOL)flag
            includeChildren:(BOOL)children
{
	PGNode *const node = children && flag ? [self sortedViewableNodeFirst:YES stopAtNode:nil includeSelf:NO] : nil;
	return node ? node : [super sortedViewableNodeNext:flag includeChildren:children];
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
            stopAtNode:(PGNode *)descendent
            includeSelf:(BOOL)includeSelf
{
	if(descendent == [self node]) return nil;
	PGNode *child = flag ? [super sortedViewableNodeFirst:YES stopAtNode:descendent includeSelf:includeSelf] : nil;
	if(child) return child;
	NSArray *const children = [self sortedChildren];
	NSEnumerator *const childEnum = flag ? [children objectEnumerator] : [children reverseObjectEnumerator];
	while((child = [childEnum nextObject])) {
		PGNode *const node = [[child resourceAdapter] sortedViewableNodeFirst:flag stopAtNode:descendent includeSelf:YES];
		if(node) return node;
		if([descendent ancestorThatIsChildOfNode:[self node]] == child) return nil;
	}
	return flag ? nil : [super sortedViewableNodeFirst:NO stopAtNode:descendent includeSelf:includeSelf];
}
- (PGNode *)sortedFirstViewableNodeInFolderFirst:(BOOL)flag
{
	if(flag) return [self sortedViewableNodeFirst:YES];
	PGNode *child;
	NSArray *const children = [self sortedChildren];
	NSEnumerator *childEnum = [children reverseObjectEnumerator];
	while((child = [childEnum nextObject])) {
		PGNode *const node = [[child resourceAdapter] sortedFirstViewableNodeInFolderFirst:flag];
		if(node) return node;
	}
	childEnum = [children objectEnumerator];
	while((child = [childEnum nextObject])) if([child isViewable]) return child;
	return nil;
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
            matchSearchTerms:(NSArray *)terms
            stopAtNode:(PGNode *)descendent
{
	if(descendent == [self node]) return nil;
	PGNode *child = flag ? [super sortedViewableNodeFirst:YES matchSearchTerms:terms stopAtNode:descendent] : nil;
	if(child) return child;
	NSArray *const children = [self sortedChildren];
	NSEnumerator *const childEnum = flag ? [children objectEnumerator] : [children reverseObjectEnumerator];
	while((child = [childEnum nextObject])) {
		PGNode *const node = [[child resourceAdapter] sortedViewableNodeFirst:flag matchSearchTerms:terms stopAtNode:descendent];
		if(node) return node;
		if([descendent ancestorThatIsChildOfNode:[self node]] == child) return nil;
	}
	return flag ? nil : [super sortedViewableNodeFirst:NO matchSearchTerms:terms stopAtNode:descendent];
}

#pragma mark -

- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident
{
	if(!ident) return nil;
	PGNode *child;
	NSEnumerator *const childEnum = [_unsortedChildren objectEnumerator];
	while((child = [childEnum nextObject])) {
		PGNode *const node = [[child resourceAdapter] nodeForIdentifier:ident];
		if(node) return node;
	}
	return [super nodeForIdentifier:ident];
}
- (void)addMenuItemsToMenu:(NSMenu *)aMenu
{
	NSMenu *menu;
	if([self parentNode]) {
		[super addMenuItemsToMenu:aMenu];
		menu = [[[self node] menuItem] submenu];
	} else menu = aMenu;
	PGNode *child;
	NSEnumerator *const childEnum = [[self sortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) [[child resourceAdapter] addMenuItemsToMenu:menu];
}
- (void)noteSortOrderDidChange
{
	[_sortedChildren release];
	_sortedChildren = nil;
	PGNode *child;
	NSEnumerator *childEnum = [_unsortedChildren objectEnumerator];
	while((child = [childEnum nextObject])) [child noteSortOrderDidChange];
}

@end
