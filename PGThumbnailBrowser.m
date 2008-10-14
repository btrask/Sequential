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
#import "PGThumbnailBrowser.h"

// Views
@class PGBezelPanel;
#import "PGThumbnailView.h"

@interface PGThumbnailBrowser (Private)

- (void)_addColumnWithItem:(id)item;

@end

@implementation PGThumbnailBrowser

#pragma mark Instance Methods

- (id)dataSource
{
	return dataSource;
}
- (void)setDataSource:(id)obj
{
	if(obj == dataSource) return;
	dataSource = obj;
	[[self views] makeObjectsPerformSelector:@selector(setDataSource:) withObject:obj];
}
- (id)delegate
{
	return delegate;
}
- (void)setDelegate:(id)obj
{
	delegate = obj;
}

#pragma mark -

- (void)reloadData
{
	[self removeAllColumns];
	[self _addColumnWithItem:nil];
}
- (void)reloadChildrenOfItem:(id)item
{
}
- (void)reloadChildOfItem:(id)item
        atIndex:(unsigned)index
{
}

#pragma mark Private Protocol

- (void)_addColumnWithItem:(id)item
{
	if(item && dataSource && ![dataSource thumbnailBrowser:self itemCanHaveChildren:item]) return;
	PGThumbnailView *const thumbnailView = [[[PGThumbnailView alloc] init] autorelease];
	[thumbnailView setDataSource:[self dataSource]];
	[thumbnailView setDelegate:self];
	[thumbnailView setRepresentedObject:item];
	[thumbnailView reloadData];
	[self addColumnWithView:thumbnailView];
}

#pragma mark PGThumbnailViewDelegate Protocol

- (void)thumbnailViewSelectionDidChange:(PGThumbnailView *)sender
{
	NSSet *const newSelection = [sender selection];
	if([newSelection count] != 1) {
		[self removeColumnsAfterView:sender];
		[[self delegate] thumbnailViewSelectionDidChange:self];
		return;
	}
	id const selectedItem = [newSelection anyObject];
	NSArray *const views = [self views];
	unsigned const col = [views indexOfObjectIdenticalTo:sender];
	NSParameterAssert(NSNotFound != col);
	if(col + 1 < [views count]) {
		PGThumbnailView *const nextView = [views objectAtIndex:col + 1];
		if([nextView representedObject] == selectedItem) {
			// TODO: Deselect everything in nextView.
			return;
		}
		[self removeColumnsAfterView:sender];
	}
	[self _addColumnWithItem:selectedItem];
	[[self delegate] thumbnailViewSelectionDidChange:self];
}

#pragma mark PGBezelPanelContentView Protocol

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)scaleFactor
{
	return NSMakeRect(NSMinX(aRect), NSMaxY(aRect) - 300, NSWidth(aRect), 300);
}

@end

@implementation NSObject (PGThumbnailBrowserDataSource)

- (BOOL)thumbnailBrowser:(PGThumbnailBrowser *)sender
        itemCanHaveChildren:(id)item
{
	return YES;
}

@end

@implementation NSObject (PGThumbnailBrowserDelegate)

- (void)thumbnailBrowserSelectionDidChange:(PGThumbnailBrowser *)sender {}

@end
