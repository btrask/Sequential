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
#import "PGThumbnailView.h"

// Views
#import "PGClipView.h"

// Other
#import "PGGeometry.h"

// Categories
#import "NSBezierPathAdditions.h"

#define PGThumbnailSize      96.0
#define PGThumbnailMargin    6.0
#define PGThumbnailSizeTotal (PGThumbnailSize + PGThumbnailMargin * 2)

@implementation PGThumbnailView

#pragma mark Instance Methods

- (id)dataSource
{
	return dataSource;
}
- (void)setDataSource:(id)obj
{
	dataSource = obj;
}
- (id)delegate
{
	return delegate;
}
- (void)setDelegate:(id)obj
{
	delegate = obj;
}
- (id)representedObject
{
	return [[_representedObject retain] autorelease];
}
- (void)setRepresentedObject:(id)obj
{
	if(obj == _representedObject) return;
	[_representedObject release];
	_representedObject = [obj retain];
}

#pragma mark -

- (NSArray *)items
{
	return [[_items retain] autorelease];
}
- (NSSet *)selection
{
	return [[_selection copy] autorelease];
}
- (void)setSelection:(NSSet *)items
{
	if(items == _selection) return;
	NSMutableSet *const removedItems = [[_selection mutableCopy] autorelease];
	[removedItems minusSet:items];
	id removedItem;
	NSEnumerator *const removedItemEnum = [removedItems objectEnumerator];
	while((removedItem = [removedItemEnum nextObject])) [self setNeedsDisplayInRect:[self frameOfItemAtIndex:[_items indexOfObjectIdenticalTo:removedItem] withMargin:YES]];
	[_selection setSet:items];
	unsigned const selCount = [_selection count];
	if(1 == selCount) [self PG_scrollRectToVisible:[self frameOfItemAtIndex:[_items indexOfObjectIdenticalTo:[_selection anyObject]] withMargin:YES]];
	else if(selCount) {
		unsigned i = 0;
		for(; i < [_items count]; i++) {
			if(![_selection containsObject:[_items objectAtIndex:i]]) continue;
			[self PG_scrollRectToVisible:[self frameOfItemAtIndex:i withMargin:YES]];
			break;
		}
	}
	[[self delegate] thumbnailViewSelectionDidChange:self];
}

#pragma mark -

- (unsigned)numberOfColumns
{
	return _numberOfColumns;
}
- (unsigned)indexOfItemAtPoint:(NSPoint)aPoint
{
	NSPoint p = aPoint;
	if(PGRightToLeftLayout == _layoutDirection) p.x = NSMaxX([self bounds]) - p.x;
	return floorf(p.y / PGThumbnailSizeTotal) * _numberOfColumns + floorf(p.x / PGThumbnailSizeTotal);
}
- (NSRect)frameOfItemAtIndex:(unsigned)index
          withMargin:(BOOL)flag
{
	NSRect frame = NSMakeRect((index % _numberOfColumns) * PGThumbnailSizeTotal + PGThumbnailMargin, (index / _numberOfColumns) * PGThumbnailSizeTotal + PGThumbnailMargin, PGThumbnailSize, PGThumbnailSize);
	if(PGRightToLeftLayout == _layoutDirection) frame.origin.x = NSMaxX([self bounds]) - NSMaxX(frame);
	return flag ? NSInsetRect(frame, -PGThumbnailMargin, -PGThumbnailMargin) : frame;
}

#pragma mark -

- (PGLayoutDirection)layoutDirection
{
	return _layoutDirection;
}
- (void)setLayoutDirection:(PGLayoutDirection)dir
{
	if(dir == _layoutDirection) return;
	_layoutDirection = dir;
	[self setNeedsDisplay:YES];
}

#pragma mark -

- (void)reloadData
{
	BOOL const hadSelection = !![_selection count];
	[_items release];
	_items = [[[self dataSource] itemsForThumbnailView:self] copy];
	[self setFrameSize:NSZeroSize];
	[self setNeedsDisplay:YES];
	if(hadSelection) [[self delegate] thumbnailViewSelectionDidChange:self];
}

#pragma mark PGClipViewDocumentView Protocol

- (BOOL)acceptsClicksInClipView:(PGClipView *)sender
{
	return NO;
}

#pragma mark NSView

- (id)initWithFrame:(NSRect)aRect
{
	if((self = [super initWithFrame:aRect])) {
		_selection = (NSMutableSet *)CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
	}
	return self;
}

#pragma mark -

- (BOOL)isFlipped
{
	return YES;
}
- (void)setUpGState
{
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
}
- (void)drawRect:(NSRect)aRect
{
	int count = 0;
	NSRect const *rects = NULL;
	[self getRectsBeingDrawn:&rects count:&count];
	unsigned i = 0;
	for(; i < [_items count]; i++) {
		NSRect const frameWithMargin = [self frameOfItemAtIndex:i withMargin:YES];
		if(!PGIntersectsRectList(frameWithMargin, rects, count)) continue;
		id const item = [_items objectAtIndex:i];
		if([_selection containsObject:item]) {
			[[NSColor alternateSelectedControlColor] set];
			[[NSBezierPath AE_bezierPathWithRoundRect:NSInsetRect([self frameOfItemAtIndex:i withMargin:NO], -4, -4) cornerRadius:4.0] fill];
		}
		NSShadow *const shadow = [[[NSShadow alloc] init] autorelease];
		[shadow setShadowBlurRadius:4.0f];
		[shadow setShadowOffset:NSMakeSize(0.0f, -2.0f)];
		[shadow set];
		NSImage *const thumb = [[self dataSource] thumbnailView:self thumbnailForItem:item];
		[thumb setFlipped:[self isFlipped]];
		NSSize const originalSize = [thumb size];
		NSRect const frame = [self frameOfItemAtIndex:i withMargin:NO];
		[thumb drawInRect:PGCenteredSizeInRect(PGScaleSizeByFloat(originalSize, MIN(NSWidth(frame) / originalSize.width, NSHeight(frame) / originalSize.height)), frame) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:([[self dataSource] thumbnailView:self canSelectItem:item] ? 1.0f : 0.5f)];
		[shadow setShadowColor:nil];
		[shadow set];
	}
}

#pragma mark -

- (void)setFrameSize:(NSSize)oldSize
{
	NSView *const superview = [self superview];
	if(!superview) return;
	NSRect const sb = [superview bounds];
	unsigned const maxCols = NSWidth(sb) / PGThumbnailSizeTotal;
	_numberOfColumns = MAX(MIN(ceilf(sqrt([_items count])), maxCols), 1);
	if(ceilf((float)[_items count] / _numberOfColumns) * PGThumbnailSizeTotal > NSHeight(sb)) _numberOfColumns = MIN(ceilf((NSHeight(sb) / PGThumbnailSizeTotal) * [_items count]), maxCols);
	[super setFrameSize:NSMakeSize(_numberOfColumns * PGThumbnailSizeTotal, ceilf((float)[_items count] / _numberOfColumns) * PGThumbnailSizeTotal)];
}

#pragma mark NSResponder

- (void)mouseDown:(NSEvent *)anEvent
{
	NSPoint const p = [self convertPoint:[anEvent locationInWindow] fromView:nil];
	unsigned const i = [self indexOfItemAtPoint:p];
	id const item = [self mouse:p inRect:[self bounds]] && i < [_items count] ? [_items objectAtIndex:i] : nil;
	BOOL const canSelect = !dataSource || [dataSource thumbnailView:self canSelectItem:item];
	BOOL const modifyExistingSelection = !!([anEvent modifierFlags] & (NSShiftKeyMask | NSCommandKeyMask));
	if([_selection containsObject:item]) {
		if(!modifyExistingSelection) {
			[_selection removeAllObjects];
			[self setNeedsDisplay:YES];
			if(canSelect && item) [_selection addObject:item];
		} else if(item) [_selection removeObject:item];
	} else {
		if(!modifyExistingSelection) {
			[_selection removeAllObjects];
			[self setNeedsDisplay:YES];
		}
		if(canSelect && item) [_selection addObject:item];
	}
	[self setNeedsDisplayInRect:[self frameOfItemAtIndex:i withMargin:YES]];
	[[self delegate] thumbnailViewSelectionDidChange:self];
}

#pragma mark NSObject

- (void)dealloc
{
	[_representedObject release];
	[_selection release];
	[super dealloc];
}

@end

@implementation NSObject (PGThumbnailViewDataSource)

- (NSArray *)itemsForThumbnailView:(PGThumbnailView *)sender
{
	return nil;
}
- (NSImage *)thumbnailView:(PGThumbnailView *)sender
             thumbnailForItem:(id)item
{
	return nil;
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender
        canSelectItem:(id)item;
{
	return YES;
}

@end

@implementation NSObject (PGThumbnailViewDelegate)

- (void)thumbnailViewSelectionDidChange:(PGThumbnailView *)sender {}

@end
