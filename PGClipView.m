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
#import "PGClipView.h"
#import <IOKit/hidsystem/IOHIDLib.h>
#import <IOKit/hidsystem/event_status_driver.h>
#import <HMDTAppKit/HMAppKitEx.h>

// Other
#import "PGGeometry.h"
#import "PGKeyboardLayout.h"
#import "PGNonretainedObjectProxy.h"
#import "PGZooming.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSWindowAdditions.h"

#define PGMouseHiddenDraggingStyle true
#define PGAnimateScrolling         true
#define PGCopiesOnScroll           true // Only used prior to Leopard.
#define PGClickSlopDistance        3.0
#define PGPageTurnMovementDelay    0.5
#define PGGameStyleArrowScrolling  true
#define PGBorderPadding            (PGGameStyleArrowScrolling ? 10.0 : 23.0)
#define PGLineScrollDistance       (PGBorderPadding * 4)

enum {
	PGNotDragging,
	PGPreliminaryDragging,
	PGDragging
};
typedef unsigned PGDragMode;

static inline void PGGetRectDifference(NSRect diff[4], unsigned *count, NSRect minuend, NSRect subtrahend)
{
	if(NSIsEmptyRect(subtrahend)) {
		diff[0] = minuend;
		*count = 1;
		return;
	}
	unsigned i = 0;
	diff[i] = NSMakeRect(NSMinX(minuend), NSMaxY(subtrahend), NSWidth(minuend), MAX(NSMaxY(minuend) - NSMaxY(subtrahend), 0));
	if(!NSIsEmptyRect(diff[i])) i++;
	diff[i] = NSMakeRect(NSMinX(minuend), NSMinY(minuend), NSWidth(minuend), MAX(NSMinY(subtrahend) - NSMinY(minuend), 0));
	if(!NSIsEmptyRect(diff[i])) i++;
	float const sidesMinY = MAX(NSMinY(minuend), NSMinY(subtrahend));
	float const sidesHeight = NSMaxY(subtrahend) - MAX(NSMinY(minuend), NSMinY(subtrahend));
	diff[i] = NSMakeRect(NSMinX(minuend), sidesMinY, MAX(NSMinX(subtrahend) - NSMinX(minuend), 0), sidesHeight);
	if(!NSIsEmptyRect(diff[i])) i++;
	diff[i] = NSMakeRect(NSMaxX(subtrahend), sidesMinY, MAX(NSMaxX(minuend) - NSMaxX(subtrahend), 0), sidesHeight);
	if(!NSIsEmptyRect(diff[i])) i++;
	*count = i;
}
static inline NSPoint PGPointInRect(NSPoint aPoint, NSRect aRect)
{
	return NSMakePoint(MAX(MIN(aPoint.x, NSMaxX(aRect)), NSMinX(aRect)), MAX(MIN(aPoint.y, NSMaxY(aRect)), NSMinY(aRect)));
}

@interface PGClipView (Private)

- (BOOL)_setPosition:(NSPoint)aPoint scrollEnclosingClipViews:(BOOL)scroll markForRedisplay:(BOOL)redisplay;
- (BOOL)_scrollTo:(NSPoint)aPoint;
- (void)_scrollOneFrame:(NSTimer *)timer;
- (void)_beginPreliminaryDrag:(NSValue *)val;

@end

@implementation PGClipView

#pragma mark Instance Methods

- (id)delegate
{
	return delegate;
}
- (void)setDelegate:(id)anObject
{
	delegate = anObject;
}

#pragma mark -

- (NSView *)documentView
{
	return [[documentView retain] autorelease];
}
- (void)setDocumentView:(NSView *)aView
{
	if(aView == documentView) return;
	[documentView AE_removeObserver:self name:NSViewFrameDidChangeNotification];
	[documentView removeFromSuperview];
	[documentView release];
	documentView = [aView retain];
	if(!documentView) return;
	[self addSubview:documentView];
	[documentView AE_addObserver:self selector:@selector(viewFrameDidChange:) name:NSViewFrameDidChangeNotification];
	[self viewFrameDidChange:nil];
	[documentView setPostsFrameChangedNotifications:YES];
}
- (PGInset)boundsInset
{
	return _boundsInset;
}
- (void)setBoundsInset:(PGInset)inset
{
	NSPoint const p = [self position];
	_boundsInset = inset;
	[self scrollTo:p animation:PGAllowAnimation];
}
- (NSRect)insetBounds
{
	return PGInsetRect([self bounds], _boundsInset);
}

#pragma mark -

- (NSColor *)backgroundColor
{
	return [[_backgroundColor retain] autorelease];
}
- (void)setBackgroundColor:(NSColor *)aColor
{
	if(aColor == _backgroundColor || (aColor && _backgroundColor && [aColor isEqual:_backgroundColor])) return;
	[_backgroundColor release];
	_backgroundColor = [aColor copy];
	_backgroundIsComplex = !_backgroundColor || [NSPatternColorSpace isEqualToString:[_backgroundColor colorSpaceName]];
	if([[self documentView] isOpaque]) {
		unsigned i;
		NSRect rects[4];
		PGGetRectDifference(rects, &i, [self bounds], _documentFrame);
		while(i--) [self setNeedsDisplayInRect:rects[i]];
	} else [self setNeedsDisplay:YES];
}
- (BOOL)showsBorder
{
	return _showsBorder;
}
- (void)setShowsBorder:(BOOL)flag
{
	_showsBorder = flag;
}
- (NSCursor *)cursor
{
	return [[_cursor retain] autorelease];
}
- (void)setCursor:(NSCursor *)cursor
{
	if(cursor == _cursor) return;
	[_cursor release];
	_cursor = [cursor retain];
	[[self window] invalidateCursorRectsForView:self];
}

#pragma mark -

- (NSRect)scrollableRectWithBorder:(BOOL)flag
{
	NSSize const boundsSize = [self insetBounds].size;
	NSSize margin = NSMakeSize((boundsSize.width - NSWidth(_documentFrame)) / 2, (boundsSize.height - NSHeight(_documentFrame)) / 2);
	float const padding = _showsBorder && flag ? PGBorderPadding : 0;
	if(margin.width < 0) margin.width = padding;
	if(margin.height < 0) margin.height = padding;
	NSRect r = NSInsetRect(_documentFrame, -margin.width, -margin.height);
	r.size.width -= boundsSize.width;
	r.size.height -= boundsSize.height;
	PGInset const inset = [self boundsInset];
	return NSOffsetRect(r, -inset.minX, -inset.minY);
}
- (NSSize)distanceInDirection:(PGRectEdgeMask)direction
          forScrollType:(PGScrollType)scrollType
{
	return [self distanceInDirection:direction forScrollType:scrollType fromPosition:[self position]];
}
- (NSSize)distanceInDirection:(PGRectEdgeMask)direction
          forScrollType:(PGScrollType)scrollType
          fromPosition:(NSPoint)position
{
	NSSize s = NSZeroSize;
	NSSize const max = [self maximumDistanceForScrollType:scrollType];
	switch(scrollType) {
		case PGScrollByLine:
		{
			if(PGHorzEdgesMask & direction && PGVertEdgesMask & direction) s = NSMakeSize(sqrtf(powf(max.width, 2) / 2.0f), sqrtf(powf(max.height, 2) / 2.0f));
			else if(PGHorzEdgesMask & direction) s.width = max.width;
			else if(PGVertEdgesMask & direction) s.height = max.height;
			break;
		}
		case PGScrollByPage:
		{
			NSRect const scrollableRect = [self scrollableRectWithBorder:YES];
			if(PGMinXEdgeMask & direction) s.width = position.x - NSMinX(scrollableRect);
			else if(PGMaxXEdgeMask & direction) s.width = NSMaxX(scrollableRect) - position.x;
			if(PGMinYEdgeMask & direction) s.height = position.y - NSMinY(scrollableRect);
			else if(PGMaxYEdgeMask & direction) s.height = NSMaxY(scrollableRect) - position.y;
			if(s.width) s.width = ceilf(s.width / ceilf(s.width / max.width));
			if(s.height) s.height = ceilf(s.height / ceilf(s.height / max.height));
		}
	}
	if(PGMinXEdgeMask & direction) s.width *= -1;
	if(PGMinYEdgeMask & direction) s.height *= -1;
	return s;
}
- (NSSize)maximumDistanceForScrollType:(PGScrollType)scrollType
{
	switch(scrollType) {
		case PGScrollByLine: return NSMakeSize(PGLineScrollDistance, PGLineScrollDistance);
		case PGScrollByPage: return NSMakeSize(NSWidth([self insetBounds]) - PGLineScrollDistance, NSHeight([self insetBounds]) - PGLineScrollDistance);
		default: return NSZeroSize;
	}
}
- (BOOL)shouldExitForMovementInDirection:(PGRectEdgeMask)mask
{
	if(PGNoEdges == mask) return NO;
	NSRect const l = [self scrollableRectWithBorder:YES];
	NSRect const s = NSInsetRect([self scrollableRectWithBorder:NO], -1, -1);
	if(mask & PGMinXEdgeMask && _immediatePosition.x > MAX(NSMinX(l), NSMinX(s))) return NO;
	if(mask & PGMinYEdgeMask && _immediatePosition.y > MAX(NSMinY(l), NSMinY(s))) return NO;
	if(mask & PGMaxXEdgeMask && _immediatePosition.x < MIN(NSMaxX(l), NSMaxX(s))) return NO;
	if(mask & PGMaxYEdgeMask && _immediatePosition.y < MIN(NSMaxY(l), NSMaxY(s))) return NO; // Don't use NSIntersectionRect() because it returns NSZeroRect if the width or height is zero.
	return YES;
}

#pragma mark -

- (NSPoint)position
{
	return _scrollTimer ? _position : _immediatePosition;
}
- (NSPoint)positionForScrollAnimation:(PGAnimationType)type
{
	return [self position];
}

- (BOOL)scrollTo:(NSPoint)aPoint
        animation:(PGAnimationType)type
{
	if(!PGAnimateScrolling || PGPreferAnimation != type) {
		if(PGNoAnimation == type) [self stopAnimatedScrolling];
		if(!_scrollTimer) return [self _scrollTo:aPoint];
	}
	NSPoint const newTargetPosition = PGPointInRect(aPoint, [self scrollableRectWithBorder:YES]);
	if(NSEqualPoints(newTargetPosition, [self position])) return NO;
	_position = newTargetPosition;
	if(!_scrollTimer) {
		[self beginScrolling];
		_scrollTimer = [NSTimer timerWithTimeInterval:PGAnimationFramerate target:[self PG_nonretainedObjectProxy] selector:@selector(_scrollOneFrame:) userInfo:nil repeats:YES];
		[[NSRunLoop currentRunLoop] addTimer:_scrollTimer forMode:PGCommonRunLoopsMode];
	}
	return YES;
}
- (BOOL)scrollBy:(NSSize)aSize
        animation:(PGAnimationType)type
{
	return [self scrollTo:PGOffsetPointBySize([self positionForScrollAnimation:type], aSize) animation:type];
}
- (BOOL)scrollToEdge:(PGRectEdgeMask)mask
        animation:(PGAnimationType)type
{
	NSAssert(!PGHasContradictoryRectEdges(mask), @"Can't scroll to contradictory edges.");
	return [self scrollBy:PGRectEdgeMaskToSizeWithMagnitude(mask, FLT_MAX) animation:type];
}
- (BOOL)scrollToLocation:(PGPageLocation)location
        animation:(PGAnimationType)type
{
	return [self scrollToEdge:[[self delegate] clipView:self directionFor:location] animation:type];
}

- (void)stopAnimatedScrolling
{
	if(!_scrollTimer) return;
	[_scrollTimer invalidate];
	_scrollTimer = nil;
	_lastScrollTime = 0;
	[self endScrolling];
}

#pragma mark -

- (PGRectEdgeMask)pinLocation
{
	return _pinLocation;
}
- (void)setPinLocation:(PGRectEdgeMask)mask
{
	_pinLocation = PGNonContradictoryRectEdges(mask);
}
- (NSSize)pinLocationOffset
{
	if(NSIsEmptyRect(_documentFrame)) return NSZeroSize;
	NSRect const b = [self insetBounds];
	PGRectEdgeMask const pin = [self pinLocation];
	NSSize const diff = PGPointDiff(PGPointOfPartOfRect(b, pin), PGPointOfPartOfRect(_documentFrame, pin));
	if(![[self documentView] PG_scalesContentWithFrameSizeInClipView:self]) return diff;
	return NSMakeSize(diff.width * 2.0f / NSWidth(_documentFrame), diff.height * 2.0f / NSHeight(_documentFrame));
}
- (BOOL)scrollPinLocationToOffset:(NSSize)aSize
{
	NSSize o = aSize;
	NSRect const b = [self insetBounds];
	PGRectEdgeMask const pin = [self pinLocation];
	if([[self documentView] PG_scalesContentWithFrameSizeInClipView:self]) o = NSMakeSize(o.width * NSWidth(_documentFrame) * 0.5f, o.height * NSHeight(_documentFrame) * 0.5f);
	return [self scrollBy:PGPointDiff(PGOffsetPointBySize(PGPointOfPartOfRect(_documentFrame, pin), o), PGPointOfPartOfRect(b, pin)) animation:PGAllowAnimation];
}

#pragma mark -

- (NSPoint)center
{
	NSRect const b = [self insetBounds];
	PGInset const inset = [self boundsInset];
	return PGOffsetPointByXY([self position], inset.minX + NSWidth(b) / 2, inset.minY + NSHeight(b) / 2);
}
- (BOOL)scrollCenterTo:(NSPoint)aPoint
        animation:(PGAnimationType)type
{
	NSRect const b = [self insetBounds];
	PGInset const inset = [self boundsInset];
	return [self scrollTo:PGOffsetPointByXY(aPoint, -inset.minX - NSWidth(b) / 2, -inset.minY - NSHeight(b) / 2) animation:type];
}

#pragma mark -

- (BOOL)handleMouseDown:(NSEvent *)firstEvent
{
	NSParameterAssert(firstEvent);
	[self beginScrolling];
	[self stopAnimatedScrolling];
	BOOL handled = NO;
	unsigned dragMask = 0;
	NSEventType stopType = 0;
	switch([firstEvent type]) {
		case NSLeftMouseDown:  dragMask = NSLeftMouseDraggedMask;  stopType = NSLeftMouseUp;  break;
		case NSRightMouseDown: dragMask = NSRightMouseDraggedMask; stopType = NSRightMouseUp; break;
		default: return NO;
	}
	PGDragMode dragMode = PGNotDragging;
	NSValue *const dragModeValue = [NSValue valueWithPointer:&dragMode];
	[self PG_performSelector:@selector(_beginPreliminaryDrag:) withObject:dragModeValue afterDelay:(GetDblTime() / 60.0) inModes:[NSArray arrayWithObject:NSEventTrackingRunLoopMode] retain:NO]; // GetDblTime() is not available in 64-bit, but the only alternative for now seems to be checking the "com.apple.mouse.doubleClickThreshold" default.
	NSPoint const originalPoint = [firstEvent locationInWindow]; // Don't convert the point to our view coordinates, since we change them when scrolling.
	NSPoint finalPoint = [[self window] convertBaseToScreen:originalPoint]; // We use CGAssociateMouseAndMouseCursorPosition() to prevent the mouse from moving during the drag, so we have to keep track of where it should reappear ourselves.
	NSPoint const dragPoint = PGOffsetPointByXY(originalPoint, [self position].x, [self position].y);
	NSRect const availableDragRect = NSInsetRect([[self window] AE_contentRect], 4, 4);
	NSEvent *latestEvent;
	while([(latestEvent = [[self window] nextEventMatchingMask:(dragMask | NSEventMaskFromType(stopType)) untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES]) type] != stopType) {
		if(PGPreliminaryDragging == dragMode || (PGNotDragging == dragMode && hypotf(originalPoint.x - [latestEvent locationInWindow].x, originalPoint.y - [latestEvent locationInWindow].y) >= PGClickSlopDistance)) {
			dragMode = PGDragging;
			if(PGMouseHiddenDraggingStyle) {
				[NSCursor hide];
				CGAssociateMouseAndMouseCursorPosition(false); // Prevents the cursor from being moved over the dock, which makes it reappear when it shouldn't.
			} else [[NSCursor closedHandCursor] push];
			[self PG_cancelPreviousPerformRequestsWithSelector:@selector(_beginPreliminaryDrag:) object:dragModeValue];
		}
		if(PGMouseHiddenDraggingStyle) [self scrollBy:NSMakeSize(-[latestEvent deltaX], [latestEvent deltaY]) animation:PGNoAnimation];
		else [self scrollTo:PGOffsetPointByXY(dragPoint, -[latestEvent locationInWindow].x, -[latestEvent locationInWindow].y) animation:PGNoAnimation];
		finalPoint = PGPointInRect(PGOffsetPointByXY(finalPoint, [latestEvent deltaX], -[latestEvent deltaY]), availableDragRect);
	}
	[self PG_cancelPreviousPerformRequestsWithSelector:@selector(_beginPreliminaryDrag:) object:dragModeValue];
	[[self window] discardEventsMatchingMask:NSAnyEventMask beforeEvent:nil];
	if(PGNotDragging != dragMode) {
		handled = YES;
		[NSCursor pop];
		if(PGMouseHiddenDraggingStyle) {
			CGAssociateMouseAndMouseCursorPosition(true);
			NXEventHandle const handle = NXOpenEventStatus();
			IOHIDSetMouseLocation((io_connect_t)handle, (int)finalPoint.x, (int)(CGDisplayPixelsHigh(kCGDirectMainDisplay) - finalPoint.y)); // Use this function instead of CGDisplayMoveCursorToPoint() because it doesn't make the mouse lag briefly after being moved.
			NXCloseEventStatus(handle);
			[NSCursor unhide];
		}
		dragMode = PGNotDragging;
	} else handled = [[self delegate] clipView:self handleMouseEvent:firstEvent first:_firstMouse];
	_firstMouse = NO;
	[self endScrolling];
	return handled;
}
- (void)arrowKeyDown:(NSEvent *)firstEvent
{
	NSParameterAssert(NSKeyDown == [firstEvent type]);
	[self beginScrolling];
	[NSEvent startPeriodicEventsAfterDelay:0 withPeriod:PGAnimationFramerate];
	NSEvent *latestEvent = firstEvent;
	PGRectEdgeMask pressedDirections = PGNoEdges;
	NSTimeInterval pageTurnTime = 0, lastScrollTime = 0;
	do {
		NSEventType const type = [latestEvent type];
		if(NSPeriodic == type) {
			NSTimeInterval const currentTime = PGUptime();
			if(currentTime > pageTurnTime + PGPageTurnMovementDelay) {
				NSSize const d = [self distanceInDirection:PGNonContradictoryRectEdges(pressedDirections) forScrollType:PGScrollByLine];
				float const timeAdjustment = lastScrollTime ? PGAnimationFramerate / (currentTime - lastScrollTime) : 1;
				[self scrollBy:NSMakeSize(d.width / timeAdjustment, d.height / timeAdjustment) animation:PGNoAnimation];
			}
			lastScrollTime = currentTime;
			continue;
		}
		if([latestEvent isARepeat]) continue;
		NSString *const characters = [latestEvent charactersIgnoringModifiers];
		if([characters length] != 1) continue;
		unichar const character = [characters characterAtIndex:0];
		PGRectEdgeMask direction;
		switch(character) {
			case NSUpArrowFunctionKey:    direction = PGMaxYEdgeMask; break;
			case NSLeftArrowFunctionKey:  direction = PGMinXEdgeMask; break;
			case NSDownArrowFunctionKey:  direction = PGMinYEdgeMask; break;
			case NSRightArrowFunctionKey: direction = PGMaxXEdgeMask; break;
			default: continue;
		}
		if(NSKeyDown == type) {
			pressedDirections |= direction;
			PGRectEdgeMask const d = PGNonContradictoryRectEdges(pressedDirections);
			if([self shouldExitForMovementInDirection:d] && [[self delegate] clipView:self shouldExitEdges:d]) pageTurnTime = PGUptime();
		} else pressedDirections &= ~direction;
	} while(pressedDirections && (latestEvent = [NSApp nextEventMatchingMask:NSKeyUpMask | NSKeyDownMask | NSPeriodicMask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES]));
	[NSEvent stopPeriodicEvents];
	[[self window] discardEventsMatchingMask:NSAnyEventMask beforeEvent:nil];
	[self endScrolling];
}
- (void)scrollInDirection:(PGRectEdgeMask)direction
        type:(PGScrollType)scrollType
{
	if(![self shouldExitForMovementInDirection:direction] || ![[self delegate] clipView:self shouldExitEdges:direction]) [self scrollBy:[self distanceInDirection:direction forScrollType:scrollType] animation:PGPreferAnimation];
}
- (void)magicPanForward:(BOOL)forward
        acrossFirst:(BOOL)across
{
	PGRectEdgeMask const mask = [[self delegate] clipView:self directionFor:(forward ? PGEndLocation : PGHomeLocation)];
	NSAssert(!PGHasContradictoryRectEdges(mask), @"Delegate returned contradictory directions.");
	NSPoint position = [self position];
	PGRectEdgeMask const dir1 = mask & (across ? PGHorzEdgesMask : PGVertEdgesMask);
	position = PGOffsetPointBySize(position, [self distanceInDirection:dir1 forScrollType:PGScrollByPage fromPosition:position]);
	if([self shouldExitForMovementInDirection:dir1] || NSEqualPoints(PGPointInRect(position, [self scrollableRectWithBorder:YES]), [self position])) {
		PGRectEdgeMask const dir2 = mask & (across ? PGVertEdgesMask : PGHorzEdgesMask);
		position = PGOffsetPointBySize(position, [self distanceInDirection:dir2 forScrollType:PGScrollByPage fromPosition:position]);
		if([self shouldExitForMovementInDirection:dir2]) {
			if([[self delegate] clipView:self shouldExitEdges:mask]) return;
			position = PGRectEdgeMaskToPointWithMagnitude(mask, FLT_MAX); // We can't exit, but make sure we're at the very end.
		} else if(across) position.x = FLT_MAX * (mask & PGMinXEdgeMask ? 1 : -1);
		else position.y = FLT_MAX * (mask & PGMinYEdgeMask ? 1 : -1);
	}
	[self scrollTo:position animation:PGPreferAnimation];
}

#pragma mark -

- (void)beginScrolling
{
	if(!_scrollCount++) [self PG_viewWillScrollInClipView:self];
	[[self PG_enclosingClipView] beginScrolling];
}
- (void)endScrolling
{
	NSParameterAssert(_scrollCount);
	[[self PG_enclosingClipView] endScrolling];
	if(!--_scrollCount) [self PG_viewDidScrollInClipView:self];
}

#pragma mark -

- (void)viewFrameDidChange:(NSNotification *)aNotif
{
	_documentViewIsResizing++;
	NSSize const offset = [self pinLocationOffset];
	_documentFrame = [documentView frame];
	[self scrollPinLocationToOffset:offset];
	NSParameterAssert(_documentViewIsResizing);
	_documentViewIsResizing--;
}

#pragma mark Private Protocol

- (BOOL)_setPosition:(NSPoint)aPoint
        scrollEnclosingClipViews:(BOOL)scroll
        markForRedisplay:(BOOL)redisplay
{
	NSPoint const newPosition = PGPointInRect(aPoint, [self scrollableRectWithBorder:YES]);
	if(scroll) [[self PG_enclosingClipView] scrollBy:NSMakeSize(aPoint.x - newPosition.x, aPoint.y - newPosition.y) animation:PGAllowAnimation];
	if(NSEqualPoints(newPosition, _immediatePosition)) return NO;
	[self beginScrolling];
	_immediatePosition = newPosition;
	[self setBoundsOrigin:NSMakePoint(roundf(_immediatePosition.x), roundf(_immediatePosition.y))];
	if(redisplay) [self setNeedsDisplay:YES];
	[self endScrolling];
	return YES;
}
- (BOOL)_scrollTo:(NSPoint)aPoint
{
	if(!PGCopiesOnScroll || PGIsLeopardOrLater() || _documentViewIsResizing || (_backgroundIsComplex && ![documentView isOpaque])) return [self _setPosition:aPoint scrollEnclosingClipViews:YES markForRedisplay:YES];
	NSRect const oldBounds = [self bounds];
	NSRect const oldResizeRect = [[self window] HM_resizeRectForView:self];
	if(![self _setPosition:aPoint scrollEnclosingClipViews:YES markForRedisplay:NO]) return NO;
	NSRect const bounds = [self bounds];
	float const x = NSMinX(bounds) - NSMinX(oldBounds);
	float const y = NSMinY(bounds) - NSMinY(oldBounds);
	NSRect const copiedRect = NSIntersectionRect(NSIntersectionRect(bounds, oldBounds), _documentFrame);
	if(![self lockFocusIfCanDraw]) {
		[self setNeedsDisplay:YES];
		return YES;
	}
	NSCopyBits(0, NSOffsetRect(copiedRect, x, y), copiedRect.origin);
	[self unlockFocus];

	unsigned i;
	NSRect rects[4];
	PGGetRectDifference(rects, &i, NSUnionRect(NSOffsetRect(_documentFrame, x, y), _documentFrame), copiedRect);
	while(i--) [self setNeedsDisplayInRect:rects[i]];
	[self setNeedsDisplayInRect:oldResizeRect];
	[self displayIfNeededIgnoringOpacity];
	[self setNeedsDisplayInRect:[[self window] HM_resizeRectForView:self]]; // The window needs to draw this itself.
	return YES;
}
- (void)_scrollOneFrame:(NSTimer *)timer
{
	NSSize const r = NSMakeSize(_position.x - _immediatePosition.x, _position.y - _immediatePosition.y);
	float const dist = hypotf(r.width, r.height);
	float const factor = MIN(1, MAX(0.25, 10 / dist) / PGLagCounteractionSpeedup(&_lastScrollTime, PGAnimationFramerate));
	if(![self _scrollTo:(dist < 1 ? _position : PGOffsetPointByXY(_immediatePosition, r.width * factor, r.height * factor))]) [self stopAnimatedScrolling];
}

- (void)_beginPreliminaryDrag:(NSValue *)val
{
	PGDragMode *dragMode = [val pointerValue];
	NSAssert(PGNotDragging == *dragMode, @"Already dragging.");
	*dragMode = PGPreliminaryDragging;
	[[NSCursor closedHandCursor] push];
}

#pragma mark PGClipViewAdditions Protocol

- (PGClipView *)PG_clipView
{
	return self;
}

#pragma mark -

- (void)PG_scrollRectToVisible:(NSRect)aRect
        forView:(NSView *)view
{
	NSRect const r = [self convertRect:aRect fromView:view];
	NSRect const b = [self insetBounds];
	NSSize o = NSZeroSize;
	if(NSWidth(r) > NSWidth(b)) {
		// TODO: Use the current pin location to pick an edge of the rect to show.
	} else if(NSMinX(r) < NSMinX(b)) o.width = NSMinX(r) - NSMinX(b);
	else if(NSMaxX(r) > NSMaxX(b)) o.width = NSMaxX(r) - NSMaxX(b);
	if(NSHeight(r) > NSHeight(b)) {
		// TODO: Same as above.
	} else if(NSMinY(r) < NSMinY(b)) o.height = NSMinY(r) - NSMinY(b);
	else if(NSMaxY(r) > NSMaxY(b)) o.height = NSMaxY(r) - NSMaxY(b);
	[self scrollBy:o animation:PGAllowAnimation];
}
- (void)PG_viewWillScrollInClipView:(PGClipView *)clipView
{
	if(clipView == self || !_scrollCount) [super PG_viewWillScrollInClipView:clipView];
}
- (void)PG_viewDidScrollInClipView:(PGClipView *)clipView
{
	if(clipView == self || !_scrollCount) [super PG_viewDidScrollInClipView:clipView];
}

#pragma mark PGZooming Protocol

- (NSSize)PG_zoomedBoundsSize
{
	return PGInsetSize([super PG_zoomedBoundsSize], PGInvertInset([self boundsInset]));
}

#pragma mark NSView

- (id)initWithFrame:(NSRect)aRect
{
	if((self = [super initWithFrame:aRect])) {
		[self setShowsBorder:YES];
		[self setCursor:[NSCursor arrowCursor]];
		_backgroundIsComplex = YES;
	}
	return self;
}

#pragma mark -

- (BOOL)isOpaque
{
	return !!_backgroundColor;
}
- (BOOL)isFlipped
{
	return NO;
}
- (BOOL)wantsDefaultClipping
{
	return NO;
}
- (void)drawRect:(NSRect)aRect
{
	NSColor *const color = [self backgroundColor];
	if(!color) return;
	int count;
	NSRect const *rects;
	[self getRectsBeingDrawn:&rects count:&count];
	[color set];
	NSRectFillList(rects, count);
}

- (NSView *)hitTest:(NSPoint)aPoint
{
	NSView *const subview = [super hitTest:aPoint];
	if(!subview) return nil;
	return [subview PG_acceptsClicksInClipView:self] ? subview : self;
}
- (void)resetCursorRects
{
	if(!_cursor) return;
	unsigned i;
	NSRect rects[4];
	NSRect b = [self bounds];
	if([[self window] styleMask] & NSResizableWindowMask) {
		PGGetRectDifference(rects, &i, NSMakeRect(NSMinX(b), NSMinY(b), NSWidth(b) - 15, 15), ([[self documentView] PG_acceptsClicksInClipView:self] ? _documentFrame : NSZeroRect));
		while(i--) [self addCursorRect:rects[i] cursor:_cursor];

		b.origin.y += 15;
		b.size.height -= 15;
	}
	PGGetRectDifference(rects, &i, b, ([[self documentView] PG_acceptsClicksInClipView:self] ? _documentFrame : NSZeroRect));
	while(i--) [self addCursorRect:rects[i] cursor:_cursor];
}

- (void)setFrameSize:(NSSize)newSize
{
	float const heightDiff = NSHeight([self frame]) - newSize.height;
	[super setFrameSize:newSize];
	[self _setPosition:PGOffsetPointByXY(_immediatePosition, 0, heightDiff) scrollEnclosingClipViews:NO markForRedisplay:YES];
}

#pragma mark NSResponder

- (BOOL)acceptsFirstMouse:(NSEvent *)anEvent
{
	_firstMouse = YES;
	return YES;
}
- (void)mouseDown:(NSEvent *)anEvent
{
	[self handleMouseDown:anEvent];
}
- (void)rightMouseDown:(NSEvent *)anEvent
{
	[self handleMouseDown:anEvent];
}
- (void)scrollWheel:(NSEvent *)anEvent
{
	[NSCursor setHiddenUntilMouseMoves:YES];
	float const x = -[anEvent deltaX], y = [anEvent deltaY];
	[self scrollBy:NSMakeSize(x * PGLineScrollDistance, y * PGLineScrollDistance) animation:PGPreferAnimation];
}

#pragma mark -

// Private, invoked by guestures on new laptop trackpads.
- (void)beginGestureWithEvent:(NSEvent *)anEvent
{
	[NSCursor setHiddenUntilMouseMoves:YES];
}
- (void)swipeWithEvent:(NSEvent *)anEvent
{
	[[self delegate] clipView:self shouldExitEdges:PGPointToRectEdgeMaskWithThreshhold(NSMakePoint(-[anEvent deltaX], [anEvent deltaY]), 0.1)];
}
- (void)magnifyWithEvent:(NSEvent *)anEvent
{
	[[self delegate] clipView:self magnifyBy:[anEvent deltaZ]];
}
- (void)rotateWithEvent:(NSEvent *)anEvent
{
	[[self delegate] clipView:self rotateByDegrees:[anEvent rotation]];
}
- (void)endGestureWithEvent:(NSEvent *)anEvent
{
	[[self delegate] clipViewGestureDidEnd:self];
}

#pragma mark -

- (BOOL)acceptsFirstResponder
{
	return YES;
}
- (void)keyDown:(NSEvent *)anEvent
{
	[NSCursor setHiddenUntilMouseMoves:YES];
	if([[self delegate] clipView:self handleKeyDown:anEvent]) return;
	unsigned const modifiers = [anEvent modifierFlags];
	if(modifiers & NSCommandKeyMask) return [super keyDown:anEvent]; // Ignore all command key equivalents.
	BOOL const forward = !(NSShiftKeyMask & modifiers);
	switch([anEvent keyCode]) {
#if PGGameStyleArrowScrolling
		case PGKeyArrowUp:
		case PGKeyArrowDown:
		case PGKeyArrowLeft:
		case PGKeyArrowRight:
			return [self arrowKeyDown:anEvent];
#endif

		case PGKeyN:
		case PGKeySpace: return [self magicPanForward:forward acrossFirst:YES];
		case PGKeyV: return [self magicPanForward:forward acrossFirst:NO];
		case PGKeyB: return [self magicPanForward:NO acrossFirst:YES];
		case PGKeyC: return [self magicPanForward:NO acrossFirst:NO];

		case PGKeyPad1: return [self scrollInDirection:PGMinXEdgeMask | PGMinYEdgeMask type:PGScrollByPage];
		case PGKeyPad2: return [self scrollInDirection:PGMinYEdgeMask type:PGScrollByPage];
		case PGKeyPad3: return [self scrollInDirection:PGMaxXEdgeMask | PGMinYEdgeMask type:PGScrollByPage];
		case PGKeyPad4: return [self scrollInDirection:PGMinXEdgeMask type:PGScrollByPage];
		case PGKeyPad5: return [self scrollInDirection:PGMinYEdgeMask type:PGScrollByPage];
		case PGKeyPad6: return [self scrollInDirection:PGMaxXEdgeMask type:PGScrollByPage];
		case PGKeyPad7: return [self scrollInDirection:PGMinXEdgeMask | PGMaxYEdgeMask type:PGScrollByPage];
		case PGKeyPad8: return [self scrollInDirection:PGMaxYEdgeMask type:PGScrollByPage];
		case PGKeyPad9: return [self scrollInDirection:PGMaxXEdgeMask | PGMaxYEdgeMask type:PGScrollByPage];
		case PGKeyPad0: return [self magicPanForward:forward acrossFirst:YES];
		case PGKeyPadEnter: return [self magicPanForward:forward acrossFirst:NO];

		case PGKeyReturn:
		case PGKeyQ:
			return [super keyDown:anEvent]; // Pass these keys on.
	}
	if(![[NSApp mainMenu] performKeyEquivalent:anEvent]) [self interpretKeyEvents:[NSArray arrayWithObject:anEvent]];
}

#if !PGGameStyleArrowScrolling
- (void)moveUp:(id)sender
{
	[self scrollInDirection:PGMaxYEdgeMask type:PGScrollByLine];
}
- (void)moveLeft:(id)sender
{
	[self scrollInDirection:PGMinXEdgeMask type:PGScrollByLine];
}
- (void)moveDown:(id)sender
{
	[self scrollInDirection:PGMinYEdgeMask type:PGScrollByLine];
}
- (void)moveRight:(id)sender
{
	[self scrollInDirection:PGMaxXEdgeMask type:PGScrollByLine];
}
#endif

- (IBAction)moveToBeginningOfDocument:(id)sender
{
	[self scrollToLocation:PGHomeLocation animation:PGPreferAnimation];
}
- (IBAction)moveToEndOfDocument:(id)sender
{
	[self scrollToLocation:PGEndLocation animation:PGPreferAnimation];
}
- (IBAction)scrollPageUp:(id)sender
{
	[self scrollInDirection:PGMaxYEdgeMask type:PGScrollByPage];
}
- (IBAction)scrollPageDown:(id)sender
{
	[self scrollInDirection:PGMinYEdgeMask type:PGScrollByPage];
}

- (void)insertTab:(id)sender
{
	[[self window] selectNextKeyView:sender];
}
- (void)insertBacktab:(id)sender
{
	[[self window] selectPreviousKeyView:sender];
}

// These two functions aren't actually defined by NSResponder, but -interpretKeyEvents: calls them.
- (IBAction)scrollToBeginningOfDocument:(id)sender
{
	[self moveToBeginningOfDocument:sender];
}
- (IBAction)scrollToEndOfDocument:(id)sender
{
	[self moveToEndOfDocument:sender];
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[self stopAnimatedScrolling];
	[documentView release];
	[_backgroundColor release];
	[_cursor release];
	[super dealloc];
}

@end

@implementation NSObject (PGClipViewDelegate)

- (BOOL)clipView:(PGClipView *)sender
        handleMouseEvent:(NSEvent *)anEvent
        first:(BOOL)flag
{
	return NO;
}
- (BOOL)clipView:(PGClipView *)sender
        handleKeyDown:(NSEvent *)anEvent
{
	return NO;
}
- (BOOL)clipView:(PGClipView *)sender
        shouldExitEdges:(PGRectEdgeMask)mask;
{
	return NO;
}
- (PGRectEdgeMask)clipView:(PGClipView *)sender
                  directionFor:(PGPageLocation)pageLocation
{
	return PGNoEdges;
}
- (void)clipView:(PGClipView *)sender magnifyBy:(float)amount {}
- (void)clipView:(PGClipView *)sender rotateByDegrees:(float)amount {}
- (void)clipViewGestureDidEnd:(PGClipView *)sender {}

@end

@implementation NSView (PGClipViewAdditions)

- (PGClipView *)PG_enclosingClipView
{
	return [[self superview] PG_clipView];
}
- (PGClipView *)PG_clipView
{
	return [self PG_enclosingClipView];
}

- (void)PG_scrollRectToVisible:(NSRect)aRect
{
	[self PG_scrollRectToVisible:aRect forView:self];
}
- (void)PG_scrollRectToVisible:(NSRect)aRect
        forView:(NSView *)view
{
	[[self superview] PG_scrollRectToVisible:aRect forView:view];
}

- (BOOL)PG_acceptsClicksInClipView:(PGClipView *)sender
{
	return YES;
}
- (BOOL)PG_scalesContentWithFrameSizeInClipView:(PGClipView *)sender
{
	return NO;
}
- (void)PG_viewWillScrollInClipView:(PGClipView *)clipView
{
	if(clipView) [[self subviews] makeObjectsPerformSelector:_cmd withObject:clipView];
}
- (void)PG_viewDidScrollInClipView:(PGClipView *)clipView
{
	if(clipView) [[self subviews] makeObjectsPerformSelector:_cmd withObject:clipView];
}

@end
