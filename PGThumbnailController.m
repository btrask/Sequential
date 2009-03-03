/* Copyright © 2007-2008, The Sequential Project
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
#import <HMDTAppKit/PGFadeOutPanel.h>

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"

// Views
#import "PGClipView.h"
#import "PGThumbnailBrowser.h"
#import "PGThumbnailView.h"

// Controllers
#import "PGDisplayController.h"

// Other
#import "PGGeometry.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSWindowAdditions.h"

NSString *const PGThumbnailControllerContentInsetDidChangeNotification = @"PGThumbnailControllerContentInsetDidChange";

#define PGMaxVisibleColumns (unsigned)3

@interface PGThumbnailController(Private)

- (void)_updateWindowFrameWithParentWindow:(NSWindow *)aWindow;

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

- (PGDisplayController *)displayController
{
	return _displayController;
}
- (void)setDisplayController:(PGDisplayController *)aController
{
	if(aController == _displayController) return;
	NSDisableScreenUpdates();
	[[[self window] parentWindow] removeChildWindow:[self window]];
	[_displayController AE_removeObserver:self name:PGDisplayControllerActiveNodeDidChangeNotification];
	[_displayController AE_removeObserver:self name:PGDisplayControllerActiveNodeWasReadNotification];
	[[_displayController clipView] AE_removeObserver:self name:PGClipViewBoundsDidChangeNotification];
	[[_displayController window] AE_removeObserver:self name:NSWindowDidResizeNotification];
	_displayController = aController;
	[_displayController AE_addObserver:self selector:@selector(displayControllerActiveNodeDidChange:) name:PGDisplayControllerActiveNodeDidChangeNotification];
	[_displayController AE_addObserver:self selector:@selector(displayControllerActiveNodeWasRead:) name:PGDisplayControllerActiveNodeWasReadNotification];
	[[_displayController clipView] AE_addObserver:self selector:@selector(clipViewBoundsDidChange:) name:PGClipViewBoundsDidChangeNotification];
	[[_displayController window] AE_addObserver:self selector:@selector(parentWindowDidResize:) name:NSWindowDidResizeNotification];
	[self setDocument:[_displayController activeDocument]];
	[self displayControllerActiveNodeDidChange:nil];
	[self _updateWindowFrameWithParentWindow:[aController window]];
	[[aController window] addChildWindow:[self window] ordered:NSWindowAbove];
	if(!PGIsTigerOrLater()) [[self window] orderFront:self]; // This makes the parent window -orderFront: as well, which is obnoxious, but unfortunately it seems necessary on Panther.
	[[self window] display];
	NSEnableScreenUpdates();
}
- (PGDocument *)document
{
	return _document;
}
- (void)setDocument:(PGDocument *)aDoc
{
	if(aDoc == _document) return;
	[_document AE_removeObserver:self name:PGDocumentNodeThumbnailDidChangeNotification];
	[_document AE_removeObserver:self name:PGDocumentBaseOrientationDidChangeNotification];
	_document = aDoc;
	[_document AE_addObserver:self selector:@selector(documentNodeThumbnailDidChange:) name:PGDocumentNodeThumbnailDidChangeNotification];
	[_document AE_addObserver:self selector:@selector(documentBaseOrientationDidChange:) name:PGDocumentBaseOrientationDidChangeNotification];
	[_browser redisplayItem:nil children:YES];
	[self _updateWindowFrameWithParentWindow:nil];
}

#pragma mark -

- (PGFadeOutPanel *)window
{
	if(!_window) {
		_browser = [[PGThumbnailBrowser alloc] initWithFrame:NSZeroRect];
		[_browser setDelegate:self];
		[_browser setDataSource:self];
		_window = [[PGFadeOutPanel alloc] initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO];
		[_window setContentView:_browser];
		[_window setReleasedWhenClosed:NO];
		[_window setOpaque:NO];
		[_window useOptimizedDrawing:YES];
		[_window setDelegate:self];
		[_window setHasShadow:NO];
		[_window setHidesOnDeactivate:NO];
	}
	return [[_window retain] autorelease];
}
- (PGInset)contentInset
{
	return PGMakeInset(NSWidth([[self window] frame]), 0.0f, 0.0f, 0.0f);
}
- (NSSet *)selectedNodes
{
	return [_browser selection];
}
- (void)fadeOut
{
	if(!_selfRetained) [self retain];
	_selfRetained = YES;
	[[self window] fadeOut];
}

#pragma mark -

- (void)displayControllerActiveNodeDidChange:(NSNotification *)aNotif
{
	PGNode *const node = [[self displayController] activeNode];
	[_browser setSelection:(node ? [NSSet setWithObject:node] : nil) reload:YES];
}
- (void)displayControllerActiveNodeWasRead:(NSNotification *)aNotif
{
}
- (void)clipViewBoundsDidChange:(NSNotification *)aNotif
{
	[_browser redisplayItem:[[self displayController] activeNode] children:NO];
}
- (void)parentWindowDidResize:(NSNotification *)aNotif
{
	[self _updateWindowFrameWithParentWindow:nil];
}
- (void)documentNodeThumbnailDidChange:(NSNotification *)aNotif
{
	[_browser redisplayItem:[[aNotif userInfo] objectForKey:PGDocumentNodeKey] children:[[[aNotif userInfo] objectForKey:PGDocumentUpdateChildrenKey] boolValue]];
}
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif
{
	[_browser setThumbnailOrientation:[[self document] baseOrientation]];
}

#pragma mark -PGThumbnailController(Private)

- (void)_updateWindowFrameWithParentWindow:(NSWindow *)aWindow
{
	NSWindow *const p = aWindow ? aWindow : [[self window] parentWindow];
	if(!p) return;
	NSRect const r = [p AE_contentRect];
	[[self window] setFrame:NSMakeRect(NSMinX(r), NSMinY(r), (MIN([_browser numberOfColumns], PGMaxVisibleColumns) * [_browser columnWidth]) * [[self window] AE_userSpaceScaleFactor], NSHeight(r)) display:YES];
}

#pragma mark -NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[_window setDelegate:nil];
	[_window release];
	[_browser release];
	[super dealloc];
}

#pragma mark -NSObject(PGThumbnailBrowserDataSource)

- (id)thumbnailBrowser:(PGThumbnailBrowser *)sender
      parentOfItem:(id)item
{
	PGNode *const parent = [(PGNode *)item parentNode];
	return [[self document] node] == parent && ![parent isViewable] ? nil : parent;
}
- (BOOL)thumbnailBrowser:(PGThumbnailBrowser *)sender
        itemCanHaveChildren:(id)item
{
	return [item isContainer];
}

#pragma mark -NSObject(PGThumbnailBrowserDelegate)

- (void)thumbnailBrowserSelectionDidChange:(PGThumbnailBrowser *)sender
{
	NSSet *const selection = [sender selection];
	id const item = [selection anyObject];
	(void)[[self displayController] tryToSetActiveNode:[([selection count] == 1 ? item : [item parentNode]) viewableAncestor] initialLocation:PGHomeLocation];
}
- (void)thumbnailBrowser:(PGThumbnailBrowser *)sender numberOfColumnsDidChangeFrom:(unsigned)oldCount
{
	if(MIN(oldCount, PGMaxVisibleColumns) != MIN([sender numberOfColumns], PGMaxVisibleColumns)) [self _updateWindowFrameWithParentWindow:nil];
}

#pragma mark -NSObject(PGThumbnailViewDataSource)

- (NSArray *)itemsForThumbnailView:(PGThumbnailView *)sender
{
	id const item = [sender representedObject];
	if(item) return [item isContainer] ? [item sortedChildren] : nil;
	PGNode *const root = [[self document] node];
	if([root isViewable]) return [root AE_asArray];
	return [root isContainer] ? [(PGContainerAdapter *)root sortedChildren] : nil;
}
- (NSImage *)thumbnailView:(PGThumbnailView *)sender
             thumbnailForItem:(id)item
{
	return [item thumbnail];
}
- (NSString *)thumbnailView:(PGThumbnailView *)sender
              labelForItem:(id)item
{
	return [item hasRealThumbnail] ? nil : [[item identifier] displayName];
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender
        canSelectItem:(id)item;
{
	return [item hasViewableNodeCountGreaterThan:0];
}
- (NSColor *)thumbnailView:(PGThumbnailView *)sender
             labelColorForItem:(id)item
{
	switch([[item identifier] labelColor]) {
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
- (NSRect)thumbnailView:(PGThumbnailView *)sender
          highlightRectForItem:(id)item
{
	PGDisplayController *const d = [self displayController];
	if([d isReading] || [d activeNode] != item || ![d isDisplayingImage]) return NSZeroRect;
	PGClipView *const clipView = [d clipView];
	NSRect const scrollableRect = [clipView scrollableRectWithBorder:NO];
	if(NSWidth(scrollableRect) <= 0.01 && NSHeight(scrollableRect) <= 0.01) return NSZeroRect; // We can't use NSIsEmptyRect() because it can be 0 in one direction but not the other.
	NSRect const f = [clipView documentFrame];
	NSRect r = PGScaleRect(NSOffsetRect(NSIntersectionRect(f, [clipView insetBounds]), -NSMinX(f), -NSMinY(f)), 1 / NSWidth(f), 1 / NSHeight(f));
	r.origin.y = 1 - NSMaxY(r);
	return r;
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender shouldRotateThumbnailForItem:(id)item
{
	return [item hasRealThumbnail];
}

#pragma mark -NSObject(NSWindowNotifications)

- (void)windowWillClose:(NSNotification *)aNotif
{
	if(_selfRetained) [self autorelease];
	_selfRetained = NO;
}

@end
