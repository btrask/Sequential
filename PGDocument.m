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
#import "PGDocument.h"

// Models
#import "PGNode.h"
#import "PGGenericImageAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGSubscription.h"
#import "PGBookmark.h"

// Views
#import "PGImageView.h"

// Controllers
#import "PGDocumentController.h"
#import "PGBookmarkController.h"
#import "PGDisplayController.h"

// Other
#import "PGGeometry.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGDocumentWillRemoveNodesNotification          = @"PGDocumentWillRemoveNodes";
NSString *const PGDocumentSortedNodesDidChangeNotification     = @"PGDocumentSortedNodesDidChange";
NSString *const PGDocumentNodeIsViewableDidChangeNotification  = @"PGDocumentNodeIsViewableDidChange";
NSString *const PGDocumentNodeThumbnailDidChangeNotification   = @"PGDocumentNodeThumbnailDidChange";
NSString *const PGDocumentNodeDisplayNameDidChangeNotification = @"PGDocumentNodeDisplayNameDidChange";
NSString *const PGDocumentBaseOrientationDidChangeNotification = @"PGDocumentBaseOrientationDidChange";

NSString *const PGDocumentNodeKey            = @"PGDocumentNode";
NSString *const PGDocumentRemovedChildrenKey = @"PGDocumentRemovedChildren";
NSString *const PGDocumentUpdateChildrenKey  = @"PGDocumentUpdateChildren";

#define PGDocumentMaxCachedNodes 3

@interface PGDocument (Private)

- (PGNode *)_initialNode;
- (void)_setInitialIdentifier:(PGResourceIdentifier *)ident;

@end

@implementation PGDocument

#pragma mark Instance Methods

- (id)initWithResourceIdentifier:(PGResourceIdentifier *)ident
{
	if((self = [self init])) {
		_identifier = [ident retain];
		_node = [[PGNode alloc] initWithParentAdapter:nil document:self identifier:ident dataSource:nil];
		[_node startLoadWithInfo:nil];
		PGResourceIdentifier *rootIdentifier = ident;
		if([_identifier isFileIdentifier] && [[_node resourceAdapter] isKindOfClass:[PGGenericImageAdapter class]]) {
			[_node release];
			_node = nil; // Nodes check to see if they already exist, so make sure it doesn't.
			rootIdentifier = [[[[[ident URL] path] stringByDeletingLastPathComponent] AE_fileURL] AE_resourceIdentifier];
			_node = [[PGNode alloc] initWithParentAdapter:nil document:self identifier:rootIdentifier dataSource:nil];
			[_node startLoadWithInfo:nil];
			[self _setInitialIdentifier:ident];
		}
		_subscription = [[rootIdentifier subscriptionWithDescendents:YES] retain];
		[_subscription AE_addObserver:self selector:@selector(subscriptionEventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
		[self noteSortedChildrenDidChange];
	}
	return self;
}
- (id)initWithURL:(NSURL *)aURL
{
	return [self initWithResourceIdentifier:[aURL AE_resourceIdentifier]];
}
- (id)initWithBookmark:(PGBookmark *)aBookmark
{
	if((self = [self initWithResourceIdentifier:[aBookmark documentIdentifier]])) {
		[self openBookmark:aBookmark];
	}
	return self;
}
- (PGResourceIdentifier *)identifier
{
	return [[_identifier retain] autorelease];
}
- (PGNode *)node
{
	return [[_node retain] autorelease];
}
- (void)openBookmark:(PGBookmark *)aBookmark
{
	[self _setInitialIdentifier:[aBookmark fileIdentifier]];
	PGNode *const initialNode = [self _initialNode];
	if([[initialNode identifier] isEqual:[aBookmark fileIdentifier]]) {
		[[self displayController] activateNode:initialNode];
		[[PGBookmarkController sharedBookmarkController] removeBookmark:aBookmark];
	} else NSBeep();
}

#pragma mark -

- (void)getStoredNode:(out PGNode **)outNode
        imageView:(out PGImageView **)outImageView
        offset:(out NSSize *)outOffset
        query:(out NSString **)outQuery
{
	if(_storedNode) {
		*outNode = [_storedNode autorelease];
		_storedNode = nil;
		*outImageView = [_storedImageView autorelease];
		_storedImageView = nil;
		*outOffset = _storedOffset;
		*outQuery = [_storedQuery autorelease];
		_storedQuery = nil;
	} else {
		*outNode = [self _initialNode];
		*outImageView = [[[PGImageView alloc] init] autorelease];
		*outQuery = @"";
	}
}
- (void)storeNode:(PGNode *)node
        imageView:(PGImageView *)imageView
        offset:(NSSize)offset
        query:(NSString *)query
{
	[_storedNode autorelease];
	_storedNode = [node retain];
	[_storedImageView autorelease];
	_storedImageView = [imageView retain];
	_storedOffset = offset;
	[_storedQuery autorelease];
	_storedQuery = [query copy];
}

- (BOOL)getStoredWindowFrame:(out NSRect *)outFrame
{
	if(NSEqualRects(_storedFrame, NSZeroRect)) return NO;
	if(outFrame) *outFrame = _storedFrame;
	_storedFrame = NSZeroRect;
	return YES;
}
- (void)storeWindowFrame:(NSRect)frame
{
	NSParameterAssert(!NSEqualRects(frame, NSZeroRect));
	_storedFrame = frame;
}

#pragma mark -

- (PGDisplayController *)displayController
{
	return [[_displayController retain] autorelease];
}
- (void)setDisplayController:(PGDisplayController *)controller
{
	if(controller == _displayController) return;
	[_displayController setActiveDocument:nil closeIfAppropriate:YES];
	[_displayController release];
	_displayController = [controller retain];
	[_displayController setActiveDocument:self closeIfAppropriate:NO];
	[_displayController synchronizeWindowTitleWithDocumentName];
}

#pragma mark -

- (void)createUI
{
	if(![self displayController]) [self setDisplayController:[[PGDocumentController sharedDocumentController] displayControllerForNewDocument]];
	[[PGDocumentController sharedDocumentController] noteNewRecentDocument:self];
	[[self displayController] showWindow:self];
}
- (void)close
{
	[[PGDocumentController sharedDocumentController] noteNewRecentDocument:self];
	[self setDisplayController:nil];
	[[PGDocumentController sharedDocumentController] removeDocument:self];
}

#pragma mark -

- (BOOL)isOnline
{
	return ![[self identifier] isFileIdentifier];
}
- (NSMenu *)pageMenu
{
	return _pageMenu;
}

#pragma mark -

- (PGOrientation)baseOrientation
{
	return _baseOrientation;
}
- (void)setBaseOrientation:(PGOrientation)anOrientation
{
	if(anOrientation == _baseOrientation) return;
	_baseOrientation = anOrientation;
	[self AE_postNotificationName:PGDocumentBaseOrientationDidChangeNotification];
}

#pragma mark -

- (BOOL)isProcessingNodes
{
	return _processingNodeCount > 0;
}
- (void)setProcessingNodes:(BOOL)flag
{
	NSParameterAssert(flag || _processingNodeCount);
	_processingNodeCount += flag ? 1 : -1;
	if(!_processingNodeCount && _sortedChildrenChanged) [self noteSortedChildrenDidChange];
}

#pragma mark -

- (void)noteNode:(PGNode *)node
        willRemoveNodes:(NSArray *)anArray
{
	PGNode *newStoredNode = [_storedNode sortedViewableNodeNext:YES afterRemovalOfChildren:anArray fromNode:node];
	if(!newStoredNode) newStoredNode = [_storedNode sortedViewableNodeNext:NO afterRemovalOfChildren:anArray fromNode:node];
	if(_storedNode != newStoredNode) {
		[_storedNode release];
		_storedNode = [newStoredNode retain];
		_storedOffset = PGRectEdgeMaskToSizeWithMagnitude(PGReadingDirectionAndLocationToRectEdgeMask([self readingDirection], PGHomeLocation), FLT_MAX);
	}
	[self AE_postNotificationName:PGDocumentWillRemoveNodesNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:node, PGDocumentNodeKey, anArray, PGDocumentRemovedChildrenKey, nil]];
}
- (void)noteSortedChildrenDidChange
{
	if([self isProcessingNodes]) {
		_sortedChildrenChanged = YES;
		return;
	}
	int const numberOfOtherItems = [[[PGDocumentController sharedDocumentController] defaultPageMenu] numberOfItems] + 1;
	if([_pageMenu numberOfItems] < numberOfOtherItems) [_pageMenu addItem:[NSMenuItem separatorItem]];
	while([_pageMenu numberOfItems] > numberOfOtherItems) [_pageMenu removeItemAtIndex:numberOfOtherItems];
	[[self node] addMenuItemsToMenu:_pageMenu];
	if([_pageMenu numberOfItems] == numberOfOtherItems) [_pageMenu removeItemAtIndex:numberOfOtherItems - 1];
	[self AE_postNotificationName:PGDocumentSortedNodesDidChangeNotification];
}
- (void)noteNodeIsViewableDidChange:(PGNode *)node
{
	if(_node) [self AE_postNotificationName:PGDocumentNodeIsViewableDidChangeNotification userInfo:[NSDictionary dictionaryWithObject:node forKey:PGDocumentNodeKey]];
}
- (void)noteNodeThumbnailDidChange:(PGNode *)node
        children:(BOOL)flag
{
	if(node) [self AE_postNotificationName:PGDocumentNodeThumbnailDidChangeNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:node, PGDocumentNodeKey, [NSNumber numberWithBool:flag], PGDocumentUpdateChildrenKey, nil]];
}
- (void)noteNodeDisplayNameDidChange:(PGNode *)node
{
	if(!_node) return;
	if([self node] == node) [[self displayController] synchronizeWindowTitleWithDocumentName];
	[self AE_postNotificationName:PGDocumentNodeDisplayNameDidChangeNotification userInfo:[NSDictionary dictionaryWithObject:node forKey:PGDocumentNodeKey]];
}
- (void)noteNodeDidCache:(PGNode *)node
{
	if(!_node) return;
	[_cachedNodes removeObjectIdenticalTo:node];
	[_cachedNodes insertObject:node atIndex:0];
	while([_cachedNodes count] > PGDocumentMaxCachedNodes) {
		[[_cachedNodes lastObject] clearCache];
		[_cachedNodes removeLastObject];
	}
}

#pragma mark -

- (void)subscriptionEventDidOccur:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	unsigned const flags = [[[aNotif userInfo] objectForKey:PGSubscriptionRootFlagsKey] unsignedIntValue];
	if(flags & (NOTE_DELETE | NOTE_REVOKE)) return [self close];
	PGResourceIdentifier *const ident = [[[[aNotif userInfo] objectForKey:PGSubscriptionPathKey] AE_fileURL] AE_resourceIdentifier];
	if([ident isEqual:[[self node] identifier]]) [[self displayController] synchronizeWindowTitleWithDocumentName];
	[[[self node] nodeForIdentifier:ident] noteFileEventDidOccurDirect:YES];
}

#pragma mark Private Protocol

- (PGNode *)_initialNode
{
	PGNode *const node = [[self node] nodeForIdentifier:_initialIdentifier];
	return node ? node : [[self node] sortedViewableNodeFirst:YES];
}
- (void)_setInitialIdentifier:(PGResourceIdentifier *)ident
{
	if(ident == _initialIdentifier) return;
	[_initialIdentifier release];
	_initialIdentifier = [ident retain];
}

#pragma mark PGPrefObject

- (void)setShowsInfo:(BOOL)flag
{
	[super setShowsInfo:flag];
	[[PGPrefObject globalPrefObject] setShowsInfo:flag];
}
- (void)setShowsThumbnails:(BOOL)flag
{
	[super setShowsThumbnails:flag];
	[[PGPrefObject globalPrefObject] setShowsThumbnails:flag];
}
- (void)setReadingDirection:(PGReadingDirection)aDirection
{
	[super setReadingDirection:aDirection];
	[[PGPrefObject globalPrefObject] setReadingDirection:aDirection];
}
- (void)setImageScalingMode:(PGImageScalingMode)aMode
{
	[super setImageScalingMode:aMode];
	[[PGPrefObject globalPrefObject] setImageScalingMode:aMode];
}
- (void)setImageScaleFactor:(float)aFloat
{
	[super setImageScaleFactor:aFloat];
	[[PGPrefObject globalPrefObject] setImageScaleFactor:aFloat];
}
- (void)setImageScalingConstraint:(PGImageScalingConstraint)constraint
{
	[super setImageScalingConstraint:constraint];
	[[PGPrefObject globalPrefObject] setImageScalingConstraint:constraint];
}
- (void)setSortOrder:(PGSortOrder)anOrder
{
	if([self sortOrder] != anOrder) {
		[super setSortOrder:anOrder];
		[[self node] noteSortOrderDidChange];
		[self noteSortedChildrenDidChange];
	}
	[[PGPrefObject globalPrefObject] setSortOrder:anOrder];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_pageMenu = [[[PGDocumentController sharedDocumentController] defaultPageMenu] copy];
		[_pageMenu addItem:[NSMenuItem separatorItem]];
		_cachedNodes = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[self AE_removeObserver];
	[_node cancelLoad];
	[_node detachFromTree];
	[_identifier release];
	[_node release];
	[_subscription release];
	[_cachedNodes release]; // Don't worry about sending -clearCache to each node because the ones that don't get deallocated with us are in active use by somebody else.
	[_storedNode release];
	[_storedImageView release];
	[_storedQuery release];
	[_initialIdentifier release];
	[_displayController release];
	[_pageMenu release];
	[super dealloc];
}

@end
