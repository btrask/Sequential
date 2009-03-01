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
#import "PGThumbnailBezelController.h"

// Models
#import "PGNode.h"

// Views
#import "PGClipView.h"
#import "PGThumbnailBrowser.h"
#import "PGThumbnailView.h"

// Categories
#import "NSObjectAdditions.h"

@implementation PGThumbnailBezelController

#pragma mark -PGThumbnailBezelController

- (NSWindow *)parentWindow
{
	return _parentWindow;
}
- (void)setParentWindow:(NSWindow *)aWindow
{
	_parentWindow = aWindow;
}
- (PGNode *)rootNode
{
	return [[_rootNode retain] autorelease];
}
- (void)setRootNode:(PGNode *)aNode
{
	if(aNode == _rootNode) return;
	[_rootNode release];
	_rootNode = [aNode retain];
}
- (PGClipView *)clipView
{
	return [[_clipView retain] autorelease];
}
- (void)setClipView:(PGClipView *)aClipView
{
	if(aClipView == _clipView) return;
	[_clipView AE_removeObserver:self name:PGClipViewBoundsDidChangeNotification];
	[_clipView release];
	_clipView = [aClipView retain];
	[_clipView AE_addObserver:self selector:@selector(clipViewBoundsDidChange:) name:PGClipViewBoundsDidChangeNotification];
}

#pragma mark -

- (void)clipViewBoundsDidChange:(NSNotification *)aNotif
{
	// Hmmm. We have no idea what node the bounds are referring to.
}

#pragma mark -NSObject(PGThumbnailBrowserDataSource)

- (id)thumbnailBrowser:(PGThumbnailBrowser *)sender
      parentOfItem:(id)item
{
	PGNode *const parent = [(PGNode *)item parentNode];
	return [self rootNode] == parent && ![parent isViewable] ? nil : parent;
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
	(void)[self tryToSetActiveNode:[([selection count] == 1 ? item : [item parentNode]) viewableAncestor] initialLocation:PGHomeLocation];
}

#pragma mark -NSObject(PGThumbnailViewDataSource)

- (NSArray *)itemsForThumbnailView:(PGThumbnailView *)sender
{
	id const item = [sender representedObject];
	if(item) return [item isContainer] ? [item sortedChildren] : nil;
	PGNode *const root = [self rootNode];
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
	if(_reading || [self activeNode] != item || [clipView documentView] != _imageView) return NSZeroRect;
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

#pragma mark -NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[_rootNode release];
	[_clipView release];
	[super dealloc];
}

@end
