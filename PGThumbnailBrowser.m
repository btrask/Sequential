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
#import "PGBezelPanel.h"

// Categories
#import "NSObjectAdditions.h"

#define PGMaxVisibleColumns (unsigned)3

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

- (unsigned)indexOfColumnForItem:(id)item
{
	NSArray *const views = [self views];
	unsigned i = 0;
	for(; i < [views count]; i++) if([[views objectAtIndex:i] representedObject] == item) return i;
	return NSNotFound;
}

#pragma mark -

- (NSSet *)selection
{
	PGThumbnailView *const lastView = [[self views] lastObject];
	NSSet *const selection = [lastView selection];
	if([selection count]) return selection;
	id const item = [lastView representedObject];
	return item ? [NSSet setWithObject:item] : nil;
}
- (void)setSelection:(NSSet *)aSet
        reload:(BOOL)flag
{
	++_updateCount;
	unsigned const initialNumberOfColumns = [self numberOfColumns];
	if(!initialNumberOfColumns) [self _addColumnWithItem:nil];
	else if(flag) [[self viewAtIndex:0] reloadData];

	NSMutableArray *const path = [NSMutableArray array];
	id obj = [aSet anyObject];
	while((obj = [[self dataSource] thumbnailBrowser:self parentOfItem:obj])) [path insertObject:obj atIndex:0];

	unsigned i = 0;
	for(; i < [path count]; i++) {
		PGThumbnailView *const view = [self viewAtIndex:i];
		id const item = [path objectAtIndex:i];
		NSParameterAssert([[self dataSource] thumbnailBrowser:self itemCanHaveChildren:item]);
		[view setSelection:[NSSet setWithObject:item]];
		if(i + 1 < [self numberOfColumns]) {
			PGThumbnailView *const nextView = [self viewAtIndex:i + 1];
			if([nextView representedObject] != item || flag) {
				[nextView setRepresentedObject:item];
				[nextView reloadData];
			}
		} else [self _addColumnWithItem:item];
	}

	PGThumbnailView *const lastView = [self viewAtIndex:i];
	[self removeColumnsAfterView:lastView];
	if([lastView representedObject] == [path lastObject]) [lastView setSelection:aSet];

	--_updateCount;
	if(MIN(initialNumberOfColumns, PGMaxVisibleColumns) != MIN([self numberOfColumns], PGMaxVisibleColumns)) [self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
	if([self numberOfColumns] > initialNumberOfColumns) [self scrollToLastColumnAnimate:YES];
}
- (void)redisplayItem:(id)item
        children:(BOOL)flag
{
	id const parent = [[self dataSource] thumbnailBrowser:self parentOfItem:item];
	PGThumbnailView *view;
	NSEnumerator *const viewEnum = [[self views] objectEnumerator];
	while((view = [viewEnum nextObject])) {
		id const rep = [view representedObject];
		if(rep == parent) {
			unsigned const i = [[view items] indexOfObject:item];
			if(NSNotFound != i) [view setNeedsDisplayInRect:[view frameOfItemAtIndex:i withMargin:YES]];
		} else if(flag && rep == item) [view setNeedsDisplay:YES];
	}
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
	if(![self numberOfColumns]) [self setColumnWidth:NSWidth([thumbnailView frame]) + 1];
	[self addColumnWithView:thumbnailView];
}

#pragma mark PGThumbnailViewDelegate Protocol

- (void)thumbnailViewSelectionDidChange:(PGThumbnailView *)sender
{
	if(_updateCount) return;
	NSSet *const newSelection = [sender selection];
	id const selectedItem = [newSelection anyObject];
	if([newSelection count] != 1 || (dataSource && ![dataSource thumbnailBrowser:self itemCanHaveChildren:selectedItem])) {
		[self removeColumnsAfterView:sender];
		[[self delegate] thumbnailBrowserSelectionDidChange:self];
		return;
	}
	NSArray *const views = [self views];
	unsigned const col = [views indexOfObjectIdenticalTo:sender];
	NSParameterAssert(NSNotFound != col);
	if(col + 1 < [views count]) {
		PGThumbnailView *const nextView = [views objectAtIndex:col + 1];
		[nextView setSelection:nil];
		if([nextView representedObject] == selectedItem) return;
		[nextView setRepresentedObject:selectedItem];
		[nextView reloadData];
		[self scrollToTopOfColumnWithView:nextView];
	} else [self _addColumnWithItem:selectedItem];
	[self scrollToLastColumnAnimate:YES];
	[[self delegate] thumbnailBrowserSelectionDidChange:self];
}

#pragma mark PGBezelPanelContentView Protocol

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)scaleFactor
{
	return NSMakeRect(NSMinX(aRect), NSMinY(aRect), (MIN([self numberOfColumns], PGMaxVisibleColumns) * [self columnWidth] - 1) * scaleFactor, NSHeight(aRect));
}

#pragma mark PGColumnView

- (void)insertColumnWithView:(NSView *)aView
        atIndex:(unsigned)index
{
	unsigned const columns = [self numberOfColumns];
	[super insertColumnWithView:aView atIndex:index];
	if(!_updateCount && MIN(columns, PGMaxVisibleColumns) != MIN([self numberOfColumns], PGMaxVisibleColumns)) [self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
}
- (void)removeColumnsAfterView:(NSView *)aView
{
	unsigned const columns = [self numberOfColumns];
	[super removeColumnsAfterView:aView];
	if(!_updateCount && MIN(columns, PGMaxVisibleColumns) != MIN([self numberOfColumns], PGMaxVisibleColumns)) [self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
}

@end

@implementation NSObject (PGThumbnailBrowserDataSource)

- (id)thumbnailBrowser:(PGThumbnailBrowser *)sender
      parentOfItem:(id)item
{
	return nil;
}
- (BOOL)thumbnailBrowser:(PGThumbnailBrowser *)sender
        itemCanHaveChildren:(id)item
{
	return YES;
}

@end

@implementation NSObject (PGThumbnailBrowserDelegate)

- (void)thumbnailBrowserSelectionDidChange:(PGThumbnailBrowser *)sender {}

@end
