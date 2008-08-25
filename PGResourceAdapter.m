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

@implementation PGResourceAdapter

#pragma mark Class Methods

+ (BOOL)alwaysLoads
{
	return YES;
}

#pragma mark Instance Methods

- (PGNode *)node
{
	return _node;
}
- (void)setNode:(PGNode *)aNode
{
	if(aNode == _node) return;
	_node = aNode;
	[self noteIsViewableDidChange];
}

#pragma mark -

- (BOOL)adapterIsViewable
{
	return [self isImage] || [self needsEncoding] || _temporarilyViewableCount > 0;
}
- (BOOL)isImage
{
	return _isImage;
}
- (void)setIsImage:(BOOL)flag
{
	if(flag == _isImage) return;
	_isImage = flag;
	[self noteIsViewableDidChange];
}
- (BOOL)needsEncoding
{
	return _needsEncoding;
}
- (void)setNeedsEncoding:(BOOL)flag
{
	if(flag == _needsEncoding) return;
	_needsEncoding = flag;
	[self noteIsViewableDidChange];
}
- (void)setIsTemporarilyViewable:(BOOL)flag
{
	if(!flag) NSParameterAssert(_temporarilyViewableCount);
	_temporarilyViewableCount += flag ? 1 : -1;
	[self noteIsViewableDidChange];
}

#pragma mark -

- (PGLoadingPolicy)descendentLoadingPolicy
{
	return MAX(PGLoadToMaxDepth, [[self parentAdapter] descendentLoadingPolicy]);
}

#pragma mark -

- (void)read
{
	[self readReturnedImageRep:nil error:nil];
}

#pragma mark -

- (void)noteResourceDidChange {}

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
- (BOOL)shouldLoad
{
	return [[self node] shouldLoadAdapterClass:[self class]];
}
- (void)loadWithURLResponse:(NSURLResponse *)response {}

#pragma mark -

- (BOOL)isContainer
{
	return NO;
}
- (float)loadingProgress
{
	return 0;
}
- (BOOL)canGetData
{
	return [[self node] canGetData];
}
- (BOOL)canExtractData
{
	return NO;
}
- (PGDataError)getData:(out NSData **)outData
{
	return [[self node] getData:outData];
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

- (void)readIfNecessary
{
	return [[self node] readIfNecessary];
}
- (void)readReturnedImageRep:(NSImageRep *)aRep
        error:(NSError *)error
{
	[[self node] readReturnedImageRep:aRep error:error];
}

#pragma mark -

- (BOOL)hasViewableNodes
{
	return [[self node] isViewable];
}
- (BOOL)hasDataNodes
{
	return [self canGetData];
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
	PGNode *const node = [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] withSelector:@selector(sortedViewableNodeFirst:matchSearchTerms:) context:terms];
	return node ? node : [[self rootContainerAdapter] sortedViewableNodeFirst:flag matchSearchTerms:terms stopAtNode:[self node]];
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
            matchSearchTerms:(NSArray *)terms
{
	return [self sortedViewableNodeFirst:flag matchSearchTerms:terms stopAtNode:nil];
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

- (char const *)unencodedSampleString
{
	return NULL;
}
- (NSStringEncoding)defaultEncoding
{
	return 0;
}
- (void)setEncoding:(NSStringEncoding)encoding {}

#pragma mark -

- (void)noteFileEventDidOccurDirect:(BOOL)flag
{
	[[self node] loadIfNecessaryWithURLResponse:nil];
}
- (void)noteSortOrderDidChange {}
- (void)noteIsViewableDidChange
{
	[[self node] noteIsViewableDidChange];
}

#pragma mark NSObject Protocol

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p: %@>", [self class], self, [self identifier]];
}

@end
