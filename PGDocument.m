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
#import "PGBookmark.h"

// Controllers
#import "PGDocumentController.h"
#import "PGBookmarkController.h"
#import "PGDisplayController.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGDocumentSortedNodesDidChangeNotification     = @"PGDocumentSortedNodesDidChange";
NSString *const PGDocumentNodeIsViewableDidChangeNotification  = @"PGDocumentNodeIsViewableDidChange";
NSString *const PGDocumentNodeDisplayNameDidChangeNotification = @"PGDocumentNodeDisplayNameDidChange";
NSString *const PGDocumentBaseOrientationDidChangeNotification = @"PGDocumentBaseOrientationDidChange";

NSString *const PGDocumentNodeKey              = @"PGDocumentNode";
NSString *const PGDocumentOldSortedChildrenKey = @"PGDocumentOldSortedChildren";

#define PGDocumentMaxCachedNodes 3

@implementation PGDocument

#pragma mark Instance Methods

- (id)initWithResourceIdentifier:(PGResourceIdentifier *)ident
{
	if((self = [self init])) {
		_identifier = [ident retain];
		_node = [[PGNode alloc] initWithParentAdapter:nil document:self identifier:ident adapterClass:nil dataSource:nil load:YES];
		if([_identifier isFileIdentifier] && [[_node resourceAdapter] isKindOfClass:[PGGenericImageAdapter class]]) {
			[_node release];
			_node = nil; // Nodes check to see if they already exist, so make sure it doesn't.
			_node = [[PGNode alloc] initWithParentAdapter:nil document:self identifier:[PGResourceIdentifier resourceIdentifierWithURL:[[[[ident URL] path] stringByDeletingLastPathComponent] AE_fileURL]] adapterClass:nil dataSource:nil load:YES];
			[self setInitialIdentifier:ident];
		}
		[self noteSortedChildrenOfNodeDidChange:nil oldSortedChildren:nil];
	}
	return self;
}
- (id)initWithURL:(NSURL *)aURL
{
	return [self initWithResourceIdentifier:[PGResourceIdentifier resourceIdentifierWithURL:aURL]];
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
{
	if(outNode) *outNode = _storedNode;
	if(outCenter) *outCenter = _storedCenter;
	if(_storedNode) {
		_storedNode = nil;
		return YES;
	}
	return NO;
}
- (void)storeNode:(PGNode *)node
        center:(NSPoint)center
{
	_storedNode = node;
	_storedCenter = center;
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
	if([[[self initialNode] identifier] isEqual:[aBookmark fileIdentifier]]) [[PGBookmarkController sharedBookmarkController] removeBookmark:aBookmark];
	// TODO: Display the initial node in our open display controller, if we have one.
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
- (void)validate:(BOOL)knownInvalid
{
	if(!knownInvalid && [[self node] hasViewableNodes]) return;
	[self close];
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
- (void)addToBaseOrientation:(PGOrientation)anOrientation
{
	PGOrientation const o = PGAddOrientation(_baseOrientation, anOrientation);
	if(o == _baseOrientation) return;
	_baseOrientation = o;
	[self AE_postNotificationName:PGDocumentBaseOrientationDidChangeNotification];
}

#pragma mark -

- (void)noteSortedChildrenOfNodeDidChange:(PGNode *)node
        oldSortedChildren:(NSArray *)children
{
	int const numberOfOtherItems = [[[PGDocumentController sharedDocumentController] defaultPageMenu] numberOfItems] + 1;
	if([_pageMenu numberOfItems] < numberOfOtherItems) [_pageMenu addItem:[NSMenuItem separatorItem]];
	while([_pageMenu numberOfItems] > numberOfOtherItems) [_pageMenu removeItemAtIndex:numberOfOtherItems];
	[[self node] addMenuItemsToMenu:_pageMenu];
	if([_pageMenu numberOfItems] == numberOfOtherItems) [_pageMenu removeItemAtIndex:numberOfOtherItems - 1];
	[self AE_postNotificationName:PGDocumentSortedNodesDidChangeNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:children, PGDocumentOldSortedChildrenKey, node, PGDocumentNodeKey, nil]];
}
- (void)noteNodeIsViewableDidChange:(PGNode *)node
{
	NSParameterAssert(node);
	[self AE_postNotificationName:PGDocumentNodeIsViewableDidChangeNotification userInfo:[NSDictionary dictionaryWithObject:node forKey:PGDocumentNodeKey]];
}
- (void)noteNodeDisplayNameDidChange:(PGNode *)node
{
	NSParameterAssert(node);
	if([self node] == node) [[self displayController] synchronizeWindowTitleWithDocumentName];
	[self AE_postNotificationName:PGDocumentNodeDisplayNameDidChangeNotification userInfo:[NSDictionary dictionaryWithObject:node forKey:PGDocumentNodeKey]];
}
- (void)noteNodeDidCache:(PGNode *)node
{
	NSParameterAssert(node);
	[_cachedNodes removeObjectIdenticalTo:node];
	[_cachedNodes insertObject:node atIndex:0];
	while([_cachedNodes count] > PGDocumentMaxCachedNodes) {
		[[_cachedNodes lastObject] clearCache];
		[_cachedNodes removeLastObject];
	}
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
		[[self node] sortOrderDidChange];
		[self noteSortedChildrenOfNodeDidChange:nil oldSortedChildren:nil];
	}
	[[PGPrefObject globalPrefObject] setSortOrder:anOrder];
}
- (void)setAnimatesImages:(BOOL)flag
{
	[super setAnimatesImages:flag];
	[[PGPrefObject globalPrefObject] setAnimatesImages:flag];
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
	[_identifier release];
	[_node release];
	[_cachedNodes release]; // Don't worry about sending -clearCache to each node because the ones that don't get deallocated with us are in active use by somebody else.
	[_initialIdentifier release];
	[_displayController release];
	[_pageMenu release];
	[super dealloc];
}

@end
