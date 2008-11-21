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

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGThumbnailView.h"

// Views
#import "PGClipView.h"

// Other
#import "PGGeometry.h"

// Categories
#import "NSBezierPathAdditions.h"

#define PGThumbnailSize         128.0f
#define PGThumbnailHoleSize     6.0f
#define PGThumbnailHoleSpacing  3.0f
#define PGThumbnailHoleAdvance  (PGThumbnailHoleSize + PGThumbnailHoleSpacing)
#define PGThumbnailMarginWidth  (PGThumbnailHoleSize + PGThumbnailHoleSpacing * 2)
#define PGThumbnailMarginHeight 2.0f
#define PGThumbnailTotalWidth   (PGThumbnailSize + PGThumbnailMarginWidth * 2)
#define PGThumbnailTotalHeight  (PGThumbnailSize + PGThumbnailMarginHeight * 2)

@interface PGThumbnailView (Private)

- (void)_validateSelection;

@end

static void PGGradientCallback(void *info, float const *inData, float *outData)
{
	outData[0] = (0.25f - powf(inData[0] - 0.5f, 2.0f)) / 2.0f + 0.1f;
	outData[1] = 0.95f;
}

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
	NSMutableSet *const addedItems = [[items mutableCopy] autorelease];
	[addedItems minusSet:_selection];
	id addedItem;
	NSEnumerator *const addedItemEnum = [addedItems objectEnumerator];
	while((addedItem = [addedItemEnum nextObject])) [self setNeedsDisplayInRect:[self frameOfItemAtIndex:[_items indexOfObjectIdenticalTo:addedItem] withMargin:YES]];
	[_selection setSet:items];
	[self _validateSelection];
	[self scrollToFirstSelectedItem];
	[[self delegate] thumbnailViewSelectionDidChange:self];
}
- (void)scrollToFirstSelectedItem
{
	unsigned const selCount = [_selection count];
	if(1 == selCount) return [self PG_scrollRectToVisible:[self frameOfItemAtIndex:[_items indexOfObjectIdenticalTo:[_selection anyObject]] withMargin:YES]];
	else if(selCount) {
		unsigned i = 0;
		for(; i < [_items count]; i++) {
			if(![_selection containsObject:[_items objectAtIndex:i]]) continue;
			[self PG_scrollRectToVisible:[self frameOfItemAtIndex:i withMargin:YES]];
			return;
		}
	}
	[[self PG_enclosingClipView] scrollToEdge:PGMaxYEdgeMask animation:PGAllowAnimation];
}

#pragma mark -

- (unsigned)indexOfItemAtPoint:(NSPoint)p
{
	return floorf(p.y / PGThumbnailTotalHeight);
}
- (NSRect)frameOfItemAtIndex:(unsigned)index
          withMargin:(BOOL)flag
{
	NSRect frame = NSMakeRect(PGThumbnailMarginWidth, index * PGThumbnailTotalHeight + PGThumbnailMarginHeight, PGThumbnailSize, PGThumbnailSize);
	return flag ? NSInsetRect(frame, -PGThumbnailMarginWidth, -PGThumbnailMarginHeight) : frame;
}

#pragma mark -

- (void)reloadData
{
	BOOL const hadSelection = !![_selection count];
	[_items release];
	_items = [[[self dataSource] itemsForThumbnailView:self] copy];
	[self _validateSelection];
	[self sizeToFit];
	[self scrollToFirstSelectedItem];
	[self setNeedsDisplay:YES];
	if(hadSelection) [[self delegate] thumbnailViewSelectionDidChange:self];
}
- (void)sizeToFit
{
	float const height = [self superview] ? NSHeight([[self superview] bounds]) : 0;
	[super setFrameSize:NSMakeSize(PGThumbnailTotalWidth + 2, MAX(height, [_items count] * PGThumbnailTotalHeight))];
}

#pragma mark Private Protocol

- (void)_validateSelection
{
	id selectedItem;
	NSEnumerator *const selectedItemEnum = [[[_selection copy] autorelease] objectEnumerator];
	while((selectedItem = [selectedItemEnum nextObject])) if([_items indexOfObjectIdenticalTo:selectedItem] == NSNotFound) [_selection removeObject:selectedItem];
}

#pragma mark NSToolTipOwner Protocol

- (NSString *)view:(NSView *)view
              stringForToolTip:(NSToolTipTag)tag
              point:(NSPoint)point
              userData:(void *)data
{
	NSString *const label = [[self dataSource] thumbnailView:self labelForItem:[_items objectAtIndex:[self indexOfItemAtPoint:point]]];
	return label ? label : @"";
}

#pragma mark PGClipViewAdditions Protocol

- (BOOL)PG_acceptsClicksInClipView:(PGClipView *)sender
{
	return NO;
}
- (void)PG_viewWillScrollInClipView:(PGClipView *)clipView
{
	[super PG_viewWillScrollInClipView:clipView];
	[self removeAllToolTips];
}
- (void)PG_viewDidScrollInClipView:(PGClipView *)sender
{
	[super PG_viewDidScrollInClipView:sender];
	NSRect const v = [self visibleRect];
	unsigned i = 0;
	for(; i < [_items count]; i++) {
		NSRect const r = NSIntersectionRect(v, [self frameOfItemAtIndex:i withMargin:YES]);
		if(!NSIsEmptyRect(r)) [self addToolTipRect:r owner:self userData:nil];
	}
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
- (BOOL)isOpaque
{
	return YES;
}
- (void)setUpGState
{
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
}
- (void)drawRect:(NSRect)aRect
{
	NSRect const b = [self bounds];

	[[NSColor clearColor] set];
	NSRectFill(b); // We say we're opaque so we have to fill everything.

	NSShadow *const nilShadow = [[[NSShadow alloc] init] autorelease];
	[nilShadow setShadowColor:nil];
	NSShadow *const shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowOffset:NSMakeSize(0, -2)];
	[shadow setShadowBlurRadius:4.0f];
	[shadow set];

	CGContextRef const context = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextBeginTransparencyLayer(context, NULL);

	static CGShadingRef shade = NULL;
	if(!shade) {
		CGColorSpaceRef const colorSpace = CGColorSpaceCreateDeviceGray();
		float const domain[] = {0, 1};
		float const range[] = {0, 1, 0, 1};
		CGFunctionCallbacks const callbacks = {0, PGGradientCallback, NULL};
		CGFunctionRef const function = CGFunctionCreate(NULL, 1, domain, 2, range, &callbacks);
		shade = CGShadingCreateAxial(colorSpace, CGPointMake(NSMinX(b), 0), CGPointMake(NSMinX(b) + PGThumbnailTotalWidth, 0), function, NO, NO);
		CFRelease(function);
		CFRelease(colorSpace);
	}
	CGContextDrawShading([[NSGraphicsContext currentContext] graphicsPort], shade);

	int count = 0;
	NSRect const *rects = NULL;
	[self getRectsBeingDrawn:&rects count:&count];
	[shadow set];
	unsigned i = 0;
	for(; i < [_items count]; i++) {
		NSRect const frameWithMargin = [self frameOfItemAtIndex:i withMargin:YES];
		if(!PGIntersectsRectList(frameWithMargin, rects, count)) continue;
		id const item = [_items objectAtIndex:i];
		if([_selection containsObject:item]) {
			[nilShadow set];
			[[[NSColor alternateSelectedControlColor] colorWithAlphaComponent:0.5f] set];
			NSRectFillUsingOperation(frameWithMargin, NSCompositeSourceOver);
			[shadow set];
		}
		NSImage *const thumb = [[self dataSource] thumbnailView:self thumbnailForItem:item];
		if(!thumb) {
			[NSBezierPath AE_drawSpinnerInRect:NSInsetRect([self frameOfItemAtIndex:i withMargin:NO], 20, 20) startAtPetal:-1];
			continue;
		}
		[thumb setFlipped:[self isFlipped]];
		NSSize const originalSize = [thumb size];
		NSRect const frame = [self frameOfItemAtIndex:i withMargin:NO];
		NSRect const thumbnailRect = PGIntegralRect(PGCenteredSizeInRect(PGScaleSizeByFloat(originalSize, MIN(1, MIN(NSWidth(frame) / originalSize.width, NSHeight(frame) / originalSize.height))), frame));
		[thumb drawInRect:thumbnailRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:([[self dataSource] thumbnailView:self canSelectItem:item] ? 1.0f : 0.33f)];

		NSColor *const labelColor = [[self dataSource] thumbnailView:self labelColorForItem:item];
		if(!labelColor) continue;
		NSRect const labelRect = NSMakeRect(NSMaxX(frame) - 16, roundf(MAX(NSMaxY(thumbnailRect) - 16, NSMidY(thumbnailRect) - 6)), 12, 12);
		[NSGraphicsContext saveGraphicsState];
		[[NSBezierPath bezierPathWithRect:NSInsetRect(labelRect, -5, -5)] addClip]; // By adding a clipping rect we tell the system how big the transparency layer has to be.
		CGContextBeginTransparencyLayer(context, NULL);
		NSBezierPath *const labelDot = [NSBezierPath bezierPathWithOvalInRect:labelRect];
		[labelColor set];
		[labelDot fill];
		[[NSColor whiteColor] set];
		[labelDot setLineWidth:2];
		[labelDot stroke];
		CGContextEndTransparencyLayer(context);
		[NSGraphicsContext restoreGraphicsState];
	}
	[nilShadow set];

	float top = roundf(NSMinY(aRect) / PGThumbnailHoleAdvance) * PGThumbnailHoleAdvance - PGThumbnailHoleSize / 2;
	for(; top < NSMaxY(aRect); top += PGThumbnailHoleAdvance) {
		NSRect const leftHoleRect = NSMakeRect(PGThumbnailHoleSpacing, top, PGThumbnailHoleSize, PGThumbnailHoleSize);
		NSRect const rightHoleRect = NSMakeRect(PGThumbnailTotalWidth - PGThumbnailMarginWidth + PGThumbnailHoleSpacing, top, PGThumbnailHoleSize, PGThumbnailHoleSize);

		[[NSColor colorWithDeviceWhite:1 alpha:0.1f] set];
		[[NSBezierPath AE_bezierPathWithRoundRect:NSOffsetRect(leftHoleRect, 0, 1) cornerRadius:2] fill];
		[[NSBezierPath AE_bezierPathWithRoundRect:NSOffsetRect(rightHoleRect, 0, 1) cornerRadius:2] fill];

		[[NSColor clearColor] set];
		[[NSBezierPath AE_bezierPathWithRoundRect:leftHoleRect cornerRadius:2] AE_fillUsingOperation:NSCompositeCopy];
		[[NSBezierPath AE_bezierPathWithRoundRect:rightHoleRect cornerRadius:2] AE_fillUsingOperation:NSCompositeCopy];
	}

	CGContextEndTransparencyLayer(context);
	[nilShadow set];
}

#pragma mark -

- (void)setFrameSize:(NSSize)oldSize
{
	[self sizeToFit];
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
	[_items release];
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
- (NSString *)thumbnailView:(PGThumbnailView *)sender
              labelForItem:(id)item
{
	return nil;
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender
        canSelectItem:(id)item;
{
	return YES;
}
- (NSColor *)thumbnailView:(PGThumbnailView *)sender
             labelColorForItem:(id)item
{
	return nil;
}

@end

@implementation NSObject (PGThumbnailViewDelegate)

- (void)thumbnailViewSelectionDidChange:(PGThumbnailView *)sender {}

@end
