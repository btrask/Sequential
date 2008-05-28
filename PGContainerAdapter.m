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
	[_sortedChildren release];
	_sortedChildren = nil;
	[[[self node] menuItem] setSubmenu:([[self unsortedChildren] count] ? [[[NSMenu alloc] init] autorelease] : nil)];
	[[self document] noteSortedNodesDidChange];
}

#pragma mark -

- (PGNode *)childForURL:(NSURL *)aURL
{
	PGNode *child;
	NSEnumerator *const childEnum = [_unsortedChildren objectEnumerator];
	while((child = [childEnum nextObject])) if([aURL isEqual:[[child identifier] URLByFollowingAliases:YES]]) return child;
	return nil;
}
- (unsigned)viewableIndexOfNode:(PGNode *)aNode
{
	unsigned index = 0;
	id node;
	NSEnumerator *const nodeEnum = [[self sortedChildren] objectEnumerator];
	while((node = [nodeEnum nextObject]) && node != aNode) index += [node viewableNodeCount];
	return index + [[self parentAdapter] viewableIndexOfNode:[self node]];
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
	PGNode *const node = [self isViewable] ? nil : [self sortedViewableNodeFirst:YES];
	return node ? node : [super sortedViewableNodeNext:next];
}
- (PGNode *)nodeEquivalentToNode:(PGNode *)aNode
{
	PGNode *child;
	NSEnumerator *const childEnum = [[self sortedChildren] reverseObjectEnumerator];
	while((child = [childEnum nextObject])) {
		PGNode *const node = [child nodeEquivalentToNode:aNode];
		if(node) return node;
	}
	return [super nodeEquivalentToNode:aNode];
}
- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident
{
	PGNode *child;
	NSEnumerator *const childEnum = [_unsortedChildren reverseObjectEnumerator];
	while((child = [childEnum nextObject])) {
		PGNode *const node = [child nodeForIdentifier:ident];
		if(node) return node;
	}
	return [super nodeForIdentifier:ident];
}
- (PGNode *)nodeForBookmark:(PGBookmark *)aBookmark
{
	PGNode *child;
	NSEnumerator *childEnum = [_unsortedChildren objectEnumerator];
	while((child = [childEnum nextObject])) {
		PGNode *const target = [child nodeForBookmark:aBookmark];
		if(target) return target;
	}
	return nil;
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
	NSString *error = nil;
	if([self needsPassword]) error = PGPasswordError;
	else if([self needsEncoding]) error = PGEncodingError;
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
