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
#import "PGDocument.h"

// Models
#import "PGNode.h"
#import "PGGenericImageAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGSubscription.h"
#import "PGBookmark.h"

// Controllers
#import "PGDocumentController.h"
#import "PGBookmarkController.h"
#import "PGDisplayController.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGDocumentWillRemoveNodesNotification          = @"PGDocumentWillRemoveNodes";
NSString *const PGDocumentSortedNodesDidChangeNotification     = @"PGDocumentSortedNodesDidChange";
NSString *const PGDocumentNodeIsViewableDidChangeNotification  = @"PGDocumentNodeIsViewableDidChange";
NSString *const PGDocumentNodeDisplayNameDidChangeNotification = @"PGDocumentNodeDisplayNameDidChange";
NSString *const PGDocumentBaseOrientationDidChangeNotification = @"PGDocumentBaseOrientationDidChange";

NSString *const PGDocumentNodeKey            = @"PGDocumentNode";
NSString *const PGDocumentRemovedChildrenKey = @"PGDocumentRemovedChildren";

#define PGDocumentMaxCachedNodes 3

@implementation PGDocument

#pragma mark Instance Methods

- (id)initWithResourceIdentifier:(PGResourceIdentifier *)ident
{
	if((self = [self init])) {
		_identifier = [ident retain];
		_node = [[PGNode alloc] initWithParentAdapter:nil document:self identifier:ident];
		PGResourceIdentifier *rootIdentifier = ident;
		if([_identifier isFileIdentifier] && [[_node classWithURLResponse:nil] isKindOfClass:[PGGenericImageAdapter class]]) {
			[_node release];
			_node = nil; // Nodes check to see if they already exist, so make sure it doesn't.
			rootIdentifier = [[[[[ident URL] path] stringByDeletingLastPathComponent] AE_fileURL] AE_resourceIdentifier];
			_node = [[PGNode alloc] initWithParentAdapter:nil document:self identifier:rootIdentifier];
			[self setInitialIdentifier:ident];
		}
		[_node loadWithURLResponse:nil];
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

#pragma mark -

- (BOOL)getStoredNode:(out PGNode **)outNode
        center:(out NSPoint *)outCenter
        query:(out NSString **)outQuery
{
	if(outNode) *outNode = _storedNode;
	if(outCenter) *outCenter = _storedCenter;
	if(outQuery) *outQuery = _storedQuery;
	[_storedNode autorelease];
	[_storedQuery autorelease];
	_storedQuery = nil;
	if(_storedNode) {
		_storedNode = nil;
		return YES;
	}
	return NO;
}
- (void)storeNode:(PGNode *)node
        center:(NSPoint)center
        query:(NSString *)query
{
	[_storedNode autorelease];
	_storedNode = [node retain];
	_storedCenter = center;
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

- (PGNode *)initialNode
{
	PGNode *const node = [[self node] nodeForIdentifier:_initialIdentifier];
	return node ? node : [[self node] sortedViewableNodeFirst:YES];
}
- (void)setInitialIdentifier:(PGResourceIdentifier *)ident
{
	if(ident == _initialIdentifier) return;
	[_initialIdentifier release];
	_initialIdentifier = [ident retain];
}
- (void)openBookmark:(PGBookmark *)aBookmark
{
	[self setInitialIdentifier:[aBookmark fileIdentifier]];
	PGNode *const initialNode = [self initialNode];
	if([[initialNode identifier] isEqual:[aBookmark fileIdentifier]]) {
		[[self displayController] showNode:initialNode];
		[[PGBookmarkController sharedBookmarkController] removeBookmark:aBookmark];
	} else NSBeep();
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

- (NSString *)displayName
{
	return [[self identifier] displayName];
}
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
- (void)setOrientation:(PGOrientation)anOrientation
{
	if(anOrientation == _baseOrientation) return;
	_baseOrientation = anOrientation;
	[self AE_postNotificationName:PGDocumentBaseOrientationDidChangeNotification];
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
		_storedCenter = PGRectEdgeMaskToPointWithMagnitude(PGReadingDirectionAndLocationToRectEdgeMask([self readingDirection], PGHomeLocation), FLT_MAX);
	}
	[self AE_postNotificationName:PGDocumentWillRemoveNodesNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:node, PGDocumentNodeKey, anArray, PGDocumentRemovedChildrenKey, nil]];
}
- (void)noteSortedChildrenDidChange
{
	int const numberOfOtherItems = [[[PGDocumentController sharedDocumentController] defaultPageMenu] numberOfItems] + 1;
	if([_pageMenu numberOfItems] < numberOfOtherItems) [_pageMenu addItem:[NSMenuItem separatorItem]];
	while([_pageMenu numberOfItems] > numberOfOtherItems) [_pageMenu removeItemAtIndex:numberOfOtherItems];
	[[self node] addMenuItemsToMenu:_pageMenu];
	if([_pageMenu numberOfItems] == numberOfOtherItems) [_pageMenu removeItemAtIndex:numberOfOtherItems - 1];
	[self AE_postNotificationName:PGDocumentSortedNodesDidChangeNotification];
}
- (void)noteNodeIsViewableDidChange:(PGNode *)node
{
	if(!_node) return;
	NSParameterAssert(node);
	[self AE_postNotificationName:PGDocumentNodeIsViewableDidChangeNotification userInfo:[NSDictionary dictionaryWithObject:node forKey:PGDocumentNodeKey]];
}
- (void)noteNodeDisplayNameDidChange:(PGNode *)node
{
	if(!_node) return;
	NSParameterAssert(node);
	if([self node] == node) [[self displayController] synchronizeWindowTitleWithDocumentName];
	[self AE_postNotificationName:PGDocumentNodeDisplayNameDidChangeNotification userInfo:[NSDictionary dictionaryWithObject:node forKey:PGDocumentNodeKey]];
}
- (void)noteNodeDidCache:(PGNode *)node
{
	if(!_node) return;
	NSParameterAssert(node);
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

#pragma mark PGPrefObject

- (void)setShowsOnScreenDisplay:(BOOL)flag
{
	[super setShowsOnScreenDisplay:flag];
	[[PGPrefObject globalPrefObject] setShowsOnScreenDisplay:flag];
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
	[_identifier release];
	[_node release];
	[_subscription release];
	[_cachedNodes release]; // Don't worry about sending -clearCache to each node because the ones that don't get deallocated with us are in active use by somebody else.
	[_storedNode release];
	[_storedQuery release];
	[_initialIdentifier release];
	[_displayController release];
	[_pageMenu release];
	[super dealloc];
}

@end
