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
- (void)setSelection:(NSSet *)items
{
	if(![self numberOfColumns]) [self _addColumnWithItem:nil];
	if(![items count]) return [self removeColumnsAfterView:[self viewAtIndex:0]];
	id ancestor = [items anyObject];
	NSMutableArray *const path = [NSMutableArray array];
	do {
		ancestor = [[self dataSource] thumbnailBrowser:self parentOfItem:ancestor];
		unsigned const i = [self indexOfColumnForItem:ancestor];
		if(NSNotFound != i) {
			[self removeColumnsAfterView:[self viewAtIndex:i]];
			break;
		}
		[path addObject:ancestor];
	} while(ancestor);
	id pathItem;
	NSEnumerator *const pathItemEnum = [path reverseObjectEnumerator];
	while((pathItem = [pathItemEnum nextObject])) {
		[[self lastView] setSelection:[NSSet setWithObject:pathItem]];
		NSParameterAssert([[self lastView] representedObject] == pathItem);
	}
	[[self lastView] setSelection:items];
	[self scrollToLastColumnAnimate:NO];
}
- (void)setSelectedItem:(id)item
{
	[self setSelection:(item ? [NSSet setWithObject:item] : nil)];
}

#pragma mark -

- (void)reloadData
{
	if(![self numberOfColumns]) return [self _addColumnWithItem:nil];
	NSDisableScreenUpdates();
	[[self viewAtIndex:0] setSelection:nil];
	unsigned i = 0;
	for(; i < [self numberOfColumns]; i++) [[self viewAtIndex:i] reloadData];
	NSEnableScreenUpdates();
}
- (void)reloadItem:(id)item
        reloadChildren:(BOOL)flag
{
	PGThumbnailView *view;
	NSEnumerator *const viewEnum = [[self views] objectEnumerator];
	while((view = [viewEnum nextObject])) {
		unsigned const i = [[view items] indexOfObjectIdenticalTo:item];
		if(NSNotFound != i) [view setNeedsDisplayInRect:[view frameOfItemAtIndex:i withMargin:YES]];
		else if(flag && [view representedObject] == item) [view reloadData];
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
		if([nextView representedObject] == selectedItem) return [nextView setSelection:nil];
		[nextView setRepresentedObject:selectedItem];
		[nextView reloadData];
		[self removeColumnsAfterView:nextView];
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
	return NSMakeRect(NSMinX(aRect), NSMinY(aRect), (MIN([self numberOfColumns], (unsigned)3) * [self columnWidth] - 1) * scaleFactor, NSHeight(aRect));
}

#pragma mark PGColumnView

- (void)insertColumnWithView:(NSView *)aView
        atIndex:(unsigned)index
{
	[super insertColumnWithView:aView atIndex:index];
	[self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
}
- (void)removeColumnsAfterView:(NSView *)aView
{
	[super removeColumnsAfterView:aView];
	[self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
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
