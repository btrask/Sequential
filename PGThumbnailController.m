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
#import "PGThumbnailController.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"

// Views
#import "PGClipView.h"
#import "PGBezelPanel.h"
#import "PGThumbnailBrowser.h"
#import "PGThumbnailView.h"

// Controllers
#import "PGDisplayController.h"

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGFoundationAdditions.h"
#import "PGGeometry.h"

NSString *const PGThumbnailControllerContentInsetDidChangeNotification = @"PGThumbnailControllerContentInsetDidChange";

#define PGMaxVisibleColumns (NSUInteger)3

@interface PGThumbnailController(Private)

- (void)_updateWindowFrame;

@end

@implementation PGThumbnailController

#pragma mark +PGThumbnailController

+ (BOOL)canShowThumbnailsForDocument:(PGDocument *)aDoc
{
	return [[aDoc node] hasViewableNodeCountGreaterThan:1];
}
+ (BOOL)shouldShowThumbnailsForDocument:(PGDocument *)aDoc
{
	return [aDoc showsThumbnails] && [self canShowThumbnailsForDocument:aDoc];
}

#pragma mark -PGThumbnailController

@synthesize displayController = _displayController;
- (void)setDisplayController:(PGDisplayController *)aController
{
	if(aController == _displayController) return;
	[[_window parentWindow] removeChildWindow:_window];
	[_displayController PG_removeObserver:self name:PGDisplayControllerActiveNodeDidChangeNotification];
	[_displayController PG_removeObserver:self name:PGDisplayControllerActiveNodeWasReadNotification];
	[[_displayController clipView] PG_removeObserver:self name:PGClipViewBoundsDidChangeNotification];
	[[_displayController window] PG_removeObserver:self name:NSWindowDidResizeNotification];
	[[_displayController windowForSheet] PG_removeObserver:self name:NSWindowWillBeginSheetNotification];
	[[_displayController windowForSheet] PG_removeObserver:self name:NSWindowDidEndSheetNotification];
	_displayController = aController;
	[_displayController PG_addObserver:self selector:@selector(displayControllerActiveNodeDidChange:) name:PGDisplayControllerActiveNodeDidChangeNotification];
	[_displayController PG_addObserver:self selector:@selector(displayControllerActiveNodeWasRead:) name:PGDisplayControllerActiveNodeWasReadNotification];
	[[_displayController clipView] PG_addObserver:self selector:@selector(clipViewBoundsDidChange:) name:PGClipViewBoundsDidChangeNotification];
	[[_displayController window] PG_addObserver:self selector:@selector(parentWindowDidResize:) name:NSWindowDidResizeNotification];
	[[_displayController windowForSheet] PG_addObserver:self selector:@selector(parentWindowWillBeginSheet:) name:NSWindowWillBeginSheetNotification];
	[[_displayController windowForSheet] PG_addObserver:self selector:@selector(parentWindowDidEndSheet:) name:NSWindowDidEndSheetNotification];
	[_window setIgnoresMouseEvents:!![[_displayController windowForSheet] attachedSheet]];
	[self setDocument:[_displayController activeDocument]];
	[self display];
}
@synthesize document = _document;
- (void)setDocument:(PGDocument *)aDoc
{
	if(aDoc == _document) return;
	[_document PG_removeObserver:self name:PGDocumentNodeThumbnailDidChangeNotification];
	[_document PG_removeObserver:self name:PGDocumentBaseOrientationDidChangeNotification];
	[_document PG_removeObserver:self name:PGDocumentSortedNodesDidChangeNotification];
	[_document PG_removeObserver:self name:PGDocumentNodeIsViewableDidChangeNotification];
	_document = aDoc;
	[_document PG_addObserver:self selector:@selector(documentNodeThumbnailDidChange:) name:PGDocumentNodeThumbnailDidChangeNotification];
	[_document PG_addObserver:self selector:@selector(documentBaseOrientationDidChange:) name:PGDocumentBaseOrientationDidChangeNotification];
	[_document PG_addObserver:self selector:@selector(documentSortedNodesDidChange:) name:PGDocumentSortedNodesDidChangeNotification];
	[_document PG_addObserver:self selector:@selector(documentNodeIsViewableDidChange:) name:PGDocumentNodeIsViewableDidChangeNotification];
	[self _updateWindowFrame];
	[self displayControllerActiveNodeDidChange:nil];
	[self documentBaseOrientationDidChange:nil];
	[self _updateWindowFrame];
}
- (PGInset)contentInset
{
	return PGMakeInset(NSWidth([_window frame]), 0.0f, 0.0f, 0.0f);
}
- (NSSet *)selectedNodes
{
	return _browser.selection;
}

#pragma mark -

- (void)display
{
	if(_selfRetained) [self autorelease];
	_selfRetained = NO;
	[[[self displayController] window] addChildWindow:_window ordered:NSWindowAbove];
	[self _updateWindowFrame];
}
- (void)fadeOut
{
	if(!_selfRetained) [self retain];
	_selfRetained = YES;
	[_window fadeOut];
}

#pragma mark -

- (void)displayControllerActiveNodeDidChange:(NSNotification *)aNotif
{
	PGNode *const node = [[self displayController] activeNode];
	[_browser setSelection:node ? [NSSet setWithObject:node] : nil];
}
- (void)displayControllerActiveNodeWasRead:(NSNotification *)aNotif
{
	[self clipViewBoundsDidChange:nil];
}
- (void)clipViewBoundsDidChange:(NSNotification *)aNotif
{
	[_browser redisplayItem:[[self displayController] activeNode] recursively:NO];
}
- (void)parentWindowDidResize:(NSNotification *)aNotif
{
	[self _updateWindowFrame];
}
- (void)parentWindowWillBeginSheet:(NSNotification *)aNotif
{
	[_window setIgnoresMouseEvents:YES];
}
- (void)parentWindowDidEndSheet:(NSNotification *)aNotif
{
	[_window setIgnoresMouseEvents:NO];
}

#pragma mark -

- (void)documentNodeThumbnailDidChange:(NSNotification *)aNotif
{
	[_browser redisplayItem:[[aNotif userInfo] objectForKey:PGDocumentNodeKey] recursively:[[[aNotif userInfo] objectForKey:PGDocumentUpdateRecursivelyKey] boolValue]];
}
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif
{
	[_browser setThumbnailOrientation:[[self document] baseOrientation]];
}
- (void)documentSortedNodesDidChange:(NSNotification *)aNotif
{
	[_browser setSelection:[_browser selection]];
}
- (void)documentNodeIsViewableDidChange:(NSNotification *)aNotif
{
	[_browser redisplayItem:[[aNotif userInfo] objectForKey:PGDocumentNodeKey] recursively:NO];
}

#pragma mark -PGThumbnailController(Private)

- (void)_updateWindowFrame
{
	NSWindow *const p = [_displayController window];
	if(!p) return;
	NSRect const r = [p PG_contentRect];
	NSRect const newFrame = NSMakeRect(NSMinX(r), NSMinY(r), (MIN([_browser numberOfColumns], PGMaxVisibleColumns) * [_browser columnWidth]) * [_window PG_userSpaceScaleFactor], NSHeight(r));
	if(NSEqualRects(newFrame, [_window frame])) return;
	[_window setFrame:newFrame display:YES];
	[self PG_postNotificationName:PGThumbnailControllerContentInsetDidChangeNotification];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		_window = [[PGThumbnailBrowser PG_bezelPanel] retain];
		[_window setReleasedWhenClosed:NO];
		[_window setDelegate:self];
		[_window setAcceptsEvents:YES];
		[_window setCanBecomeKey:YES];
		_browser = [_window content];
		[_browser setDelegate:self];
		[_browser setDataSource:self];
	}
	return self;
}
- (void)dealloc
{
	[self PG_removeObserver];
	[_window setDelegate:nil];
	[_window release];
	[super dealloc];
}

#pragma mark -<NSWindowDelegate>

- (void)windowWillClose:(NSNotification *)aNotif
{
	if(_selfRetained) [self autorelease];
	_selfRetained = NO;
}

#pragma mark -<PGThumbnailBrowserDataSource>

- (id)thumbnailBrowser:(PGThumbnailBrowser *)sender parentOfItem:(id)item
{
	PGNode *const parent = [(PGNode *)item parentNode];
	return [[self document] node] == parent && ![parent isViewable] ? nil : parent;
}
- (BOOL)thumbnailBrowser:(PGThumbnailBrowser *)sender itemCanHaveChildren:(id)item
{
	return [item isContainer];
}

#pragma mark -<PGThumbnailBrowserDelegate>

- (void)thumbnailBrowserSelectionDidChange:(PGThumbnailBrowser *)sender
{
	NSSet *const selection = [sender selection];
	id const item = [selection anyObject];
	(void)[[self displayController] tryToSetActiveNode:[([selection count] == 1 ? item : [(PGNode *)item parentNode]) viewableAncestor] forward:YES];
}
- (void)thumbnailBrowser:(PGThumbnailBrowser *)sender numberOfColumnsDidChangeFrom:(NSUInteger)oldCount
{
	if(MIN(oldCount, PGMaxVisibleColumns) != MIN([sender numberOfColumns], PGMaxVisibleColumns)) [self _updateWindowFrame];
}

#pragma mark -<PGThumbnailViewDataSource>

- (NSArray *)itemsForThumbnailView:(PGThumbnailView *)sender
{
	id const item = [sender representedObject];
	if(item) return [item isContainer] ? [item sortedChildren] : nil;
	PGNode *const root = [[self document] node];
	if([root isViewable]) return [root PG_asArray];
	return [root isContainer] ? [(PGContainerAdapter *)root sortedChildren] : nil;
}
- (NSImage *)thumbnailView:(PGThumbnailView *)sender thumbnailForItem:(id)item
{
	return [item thumbnail];
}
- (NSString *)thumbnailView:(PGThumbnailView *)sender labelForItem:(id)item
{
	return [item hasRealThumbnail] ? nil : [[(PGNode *)item identifier] displayName];
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender canSelectItem:(id)item;
{
	return [item hasViewableNodeCountGreaterThan:0];
}
- (NSColor *)thumbnailView:(PGThumbnailView *)sender labelColorForItem:(id)item
{
	switch([[(PGNode *)item identifier] labelColor]) {
		case PGLabelRed: return [NSColor redColor];
		case PGLabelOrange: return [NSColor orangeColor];
		case PGLabelYellow: return [NSColor yellowColor];
		case PGLabelGreen: return [NSColor greenColor];
		case PGLabelBlue: return [NSColor blueColor];
		case PGLabelPurple: return [NSColor purpleColor];
		case PGLabelGray: return [NSColor grayColor];
		default: return nil;
	}
}
- (NSRect)thumbnailView:(PGThumbnailView *)sender highlightRectForItem:(id)item
{
	PGDisplayController *const d = [self displayController];
	NSRect const fullHighlight = NSMakeRect(0.0f, 0.0f, 1.0f, 1.0f);
	if([d activeNode] != item || ![d isDisplayingImage]) return fullHighlight;
	if([d isReading]) return NSZeroRect;
	PGClipView *const clipView = [d clipView];
	NSRect const scrollableRect = [clipView scrollableRectWithBorder:NO];
	if(NSWidth(scrollableRect) <= 0.0001f && NSHeight(scrollableRect) <= 0.0001f) return fullHighlight; // We can't use NSIsEmptyRect() because it can be 0 in one direction but not the other.
	NSRect const f = [clipView documentFrame];
	NSRect r = PGScaleRect(NSOffsetRect(NSIntersectionRect(f, [clipView insetBounds]), -NSMinX(f), -NSMinY(f)), 1.0f / NSWidth(f), 1.0f / NSHeight(f));
	r.origin.y = 1.0f - NSMaxY(r);
	return r;
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender shouldRotateThumbnailForItem:(id)item
{
	return [item hasRealThumbnail];
}

@end
