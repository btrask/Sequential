/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGContainerAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGResourceIdentifier.h"

@implementation PGContainerAdapter

#pragma mark Instance Methods

- (NSArray *)sortedChildren
{
	if(!_sortedChildren) {
		PGSortOrder const order = [[self document] sortOrder];
		_sortedChildren = [(order == _unsortedOrder ? _unsortedChildren : [_unsortedChildren sortedArrayUsingSelector:@selector(compare:)]) retain];
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
	[_unsortedChildren release];
	_unsortedChildren = [anArray copy];
	_unsortedOrder = anOrder;
	NSArray *const oldSortedChildren = [self sortedChildren];
	[_sortedChildren release];
	_sortedChildren = nil;
	[[[self node] menuItem] setSubmenu:([[self unsortedChildren] count] ? [[[NSMenu alloc] init] autorelease] : nil)];
	[[self document] noteSortedChildrenOfNodeDidChange:[self node] oldSortedChildren:oldSortedChildren];
}

#pragma mark -

- (PGNode *)childForURL:(NSURL *)aURL
{
	PGNode *child;
	NSEnumerator *const childEnum = [_unsortedChildren objectEnumerator];
	while((child = [childEnum nextObject])) if([aURL isEqual:[[child identifier] URLByFollowingAliases:YES]]) return child;
	return nil;
}
- (unsigned)viewableIndexOfChild:(PGNode *)aNode
{
	unsigned index = 0;
	id child;
	NSEnumerator *const childEnum = [[self sortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) {
		if(child == aNode) return index + [[self parentAdapter] viewableIndexOfChild:[self node]];
		index += [child viewableNodeCount];
	}
	return 0;
}
- (PGNode *)next:(BOOL)next
            sortedViewableNodeBeyond:(PGNode *)node
{
	NSArray *const children = [self sortedChildren];
	int i = [children indexOfObjectIdenticalTo:node];
	if(NSNotFound == i) return nil;
	int const increment = (next ? 1 : -1), max = [children count];
	for(i += increment; i >= 0 && i < max; i += increment) {
		PGNode *const node = [[children objectAtIndex:i] sortedViewableNodeFirst:next];
		if(node) return node;
	}
	return [[self parentAdapter] next:next sortedViewableNodeBeyond:[self node]];
}
- (void)noteChild:(PGNode *)child
        didChangeForSortOrder:(PGSortOrder)order
{
	if([_unsortedChildren indexOfObjectIdenticalTo:child] == NSNotFound) return;
	if((PGSortOrderMask & order) != (PGSortOrderMask & [[self document] sortOrder])) return;
	[_sortedChildren release];
	_sortedChildren = nil;
	[[self document] noteSortedChildrenOfNodeDidChange:[self node] oldSortedChildren:nil];
}

#pragma mark PGResourceAdapting Protocol

- (BOOL)isContainer
{
	return YES;
}
- (void)setNode:(PGNode *)aNode
{
	[[[self node] menuItem] setSubmenu:nil];
	[super setNode:aNode];
	[[[self node] menuItem] setSubmenu:([[self unsortedChildren] count] ? [[[NSMenu alloc] init] autorelease] : nil)];
}

- (BOOL)hasViewableNodes
{
	if([self isViewable]) return YES;
	PGNode *child;
	NSEnumerator *const childEnum = [[self unsortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) if([child hasViewableNodes]) return YES;
	return NO;
}
- (BOOL)hasImageDataNodes
{
	if([self canGetImageData]) return YES;
	PGNode *child;
	NSEnumerator *const childEnum = [[self unsortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) if([child hasImageDataNodes]) return YES;
	return NO;
}
- (unsigned)viewableNodeCount
{
	if([self isViewable]) return 1;
	unsigned count = 0;
	PGNode *child;
	NSEnumerator *const childEnum = [[self unsortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) count += [child viewableNodeCount];
	return count;
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)first
{
	if([self isViewable]) return [self node];
	PGNode *child;
	NSArray *const children = [self sortedChildren];
	NSEnumerator *const childEnum = first ? [children objectEnumerator] : [children reverseObjectEnumerator];
	while((child = [childEnum nextObject])) {
		PGNode *const node = [child sortedViewableNodeFirst:first];
		if(node) return node;
	}
	return nil;
}
- (PGNode *)sortedViewableNodeNext:(BOOL)next
{
	PGNode *const subnode = next ? [self sortedViewableNodeFirst:YES] : nil;
	return subnode ? subnode : [super sortedViewableNodeNext:next];
}
- (PGNode *)sortedViewableNodeAfterFolder:(BOOL)after
{
	return [super sortedViewableNodeNext:after];
}
- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident
{
	PGNode *child;
	NSEnumerator *const childEnum = [_unsortedChildren objectEnumerator];
	while((child = [childEnum nextObject])) {
		PGNode *const node = [child nodeForIdentifier:ident];
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
	} else {
		menu = aMenu;
	}
	PGNode *child;
	NSEnumerator *const childEnum = [[self sortedChildren] objectEnumerator];
	while((child = [childEnum nextObject])) [child addMenuItemsToMenu:menu];
}
- (void)sortOrderDidChange
{
	[_sortedChildren release];
	_sortedChildren = nil;
	PGNode *child;
	NSEnumerator *childEnum = [_unsortedChildren objectEnumerator];
	while((child = [childEnum nextObject])) [child sortOrderDidChange];
}

#pragma mark PGResourceAdapter

- (BOOL)shouldRead
{
	return [[self parentAdapter] shouldReadAllDescendants] || [[self node] depth] != 2;
}
- (void)readContents
{
	[self setHasReadContents];
	if([self needsPassword]) [self readFromData:nil URLResponse:nil];
	NSError *error = nil;
	if([self needsPassword]) error = [NSError errorWithDomain:PGNodeErrorDomain code:PGPasswordError userInfo:nil];
	else if([self needsEncoding]) error = [NSError errorWithDomain:PGNodeErrorDomain code:PGEncodingError userInfo:nil];
	[self returnImage:nil error:error];
}

#pragma mark NSObject

- (void)dealloc
{
	[_sortedChildren release];
	[_unsortedChildren release];
	[super dealloc];
}

@end
