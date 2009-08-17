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
#import "PGClipView.h"
#import <IOKit/hidsystem/IOHIDLib.h>
#import <IOKit/hidsystem/event_status_driver.h>
#import <HMDTAppKit/HMAppKitEx.h>

// Other
#import "PGDelayedPerforming.h"
#import "PGGeometry.h"
#import "PGKeyboardLayout.h"
#import "PGZooming.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSWindowAdditions.h"

NSString *const PGClipViewBoundsDidChangeNotification = @"PGClipViewBoundsDidChange";

#define PGMouseHiddenDraggingStyle true
#define PGAnimateScrolling true
#define PGCopiesOnScroll true // Only used prior to Leopard.
#define PGClickSlopDistance 3.0f
#define PGPageTurnMovementDelay 0.5f
#define PGGameStyleArrowScrolling true
#define PGBorderPadding (PGGameStyleArrowScrolling ? 10.0f : 23.0f)
#define PGLineScrollDistance (PGBorderPadding * 4.0f)
#define PGMouseWheelScrollFactor 10.0f
#define PGMouseWheelZoomFactor 20.0f

enum {
	PGNotDragging,
	PGPreliminaryDragging,
	PGDragging
};
typedef unsigned PGDragMode;

static inline NSPoint PGPointInRect(NSPoint aPoint, NSRect aRect)
{
	return NSMakePoint(MAX(MIN(aPoint.x, NSMaxX(aRect)), NSMinX(aRect)), MAX(MIN(aPoint.y, NSMaxY(aRect)), NSMinY(aRect)));
}

@interface PGClipView (Private)

- (BOOL)_setPosition:(NSPoint)aPoint scrollEnclosingClipViews:(BOOL)scroll markForRedisplay:(BOOL)redisplay;
- (BOOL)_scrollTo:(NSPoint)aPoint;
- (void)_scrollOneFrame;
- (void)_beginPreliminaryDrag:(NSValue *)val;
- (void)_delayedEndGesture;

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
- (NSRect)documentFrame
{
	return _documentFrame;
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
	[[self window] invalidateCursorRectsForView:self];
	[self AE_postNotificationName:PGClipViewBoundsDidChangeNotification];
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
	NSSize margin = NSMakeSize((boundsSize.width - NSWidth(_documentFrame)) / 2.0f, (boundsSize.height - NSHeight(_documentFrame)) / 2.0f);
	float const padding = _showsBorder && flag ? PGBorderPadding : 0.0f;
	if(margin.width < 0.0f) margin.width = padding;
	if(margin.height < 0.0f) margin.height = padding;
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
			if(PGHorzEdgesMask & direction && PGVertEdgesMask & direction) s = NSMakeSize(sqrtf(powf(max.width, 2.0f) / 2.0f), sqrtf(powf(max.height, 2.0f) / 2.0f));
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
		_scrollTimer = [[self PG_performSelector:@selector(_scrollOneFrame) withObject:nil fireDate:nil interval:PGAnimationFramerate options:kNilOptions] retain];
	}
	return YES;
}
- (BOOL)scrollBy:(NSSize)aSize
        animation:(PGAnimationType)type
{
	return [self scrollTo:PGOffsetPointBySize([self position], aSize) animation:type];
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
	NSParameterAssert(PGPreserveLocation != location);
	return [self scrollToEdge:[[self delegate] clipView:self directionFor:location] animation:type];
}

- (void)stopAnimatedScrolling
{
	if(!_scrollTimer) return;
	[_scrollTimer invalidate];
	[_scrollTimer release];
	_scrollTimer = nil;
	_lastScrollTime = 0.0f;
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
	return [self scrollBy:PGPointDiff(PGOffsetPointBySize(PGPointOfPartOfRect(_documentFrame, pin), o), PGPointOfPartOfRect(b, pin)) animation:PGNoAnimation];
}

#pragma mark -

- (NSPoint)center
{
	NSRect const b = [self insetBounds];
	PGInset const inset = [self boundsInset];
	return PGOffsetPointByXY([self position], inset.minX + NSWidth(b) / 2.0f, inset.minY + NSHeight(b) / 2.0f);
}
- (BOOL)scrollCenterTo:(NSPoint)aPoint
        animation:(PGAnimationType)type
{
	NSRect const b = [self insetBounds];
	PGInset const inset = [self boundsInset];
	return [self scrollTo:PGOffsetPointByXY(aPoint, -inset.minX - NSWidth(b) / 2.0f, -inset.minY - NSHeight(b) / 2.0f) animation:type];
}
- (NSPoint)relativeCenter
{
	NSPoint const p = [self center];
	return NSMakePoint((p.x - NSMinX(_documentFrame)) / NSWidth(_documentFrame), (p.y - NSMinY(_documentFrame)) / NSHeight(_documentFrame));
}
- (BOOL)scrollRelativeCenterTo:(NSPoint)aPoint animation:(PGAnimationType)type
{
	return [self scrollCenterTo:NSMakePoint(aPoint.x * NSWidth(_documentFrame) + NSMinX(_documentFrame), aPoint.y * NSHeight(_documentFrame) + NSMinY(_documentFrame)) animation:type];
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
	[self PG_performSelector:@selector(_beginPreliminaryDrag:) withObject:dragModeValue fireDate:nil interval:GetDblTime() / -60.0f options:kNilOptions mode:NSEventTrackingRunLoopMode]; // GetDblTime() is not available in 64-bit, but the only alternative for now seems to be checking the "com.apple.mouse.doubleClickThreshold" default.
	NSPoint const originalPoint = [firstEvent locationInWindow]; // Don't convert the point to our view coordinates, since we change them when scrolling.
	NSPoint finalPoint = originalPoint; // We use CGAssociateMouseAndMouseCursorPosition() to prevent the mouse from moving during the drag, so we have to keep track of where it should reappear ourselves.
	NSRect const availableDragRect = [self convertRect:NSInsetRect([self insetBounds], 4, 4) toView:nil];
	NSPoint const dragPoint = PGOffsetPointByXY(originalPoint, [self position].x, [self position].y);
	NSEvent *latestEvent;
	while([(latestEvent = [[self window] nextEventMatchingMask:(dragMask | NSEventMaskFromType(stopType)) untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES]) type] != stopType) {
		if(PGPreliminaryDragging == dragMode || (PGNotDragging == dragMode && hypotf(originalPoint.x - [latestEvent locationInWindow].x, originalPoint.y - [latestEvent locationInWindow].y) >= PGClickSlopDistance)) {
			dragMode = PGDragging;
			if(PGMouseHiddenDraggingStyle) {
				[NSCursor hide];
				CGAssociateMouseAndMouseCursorPosition(false);
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
			NSPoint const screenPoint = PGPointInRect([[self window] convertBaseToScreen:finalPoint], [[self window] AE_contentRect]);
			IOHIDSetMouseLocation((io_connect_t)handle, roundf(screenPoint.x), roundf(CGDisplayPixelsHigh(kCGDirectMainDisplay) - screenPoint.y)); // Use this function instead of CGDisplayMoveCursorToPoint() because it doesn't make the mouse lag briefly after being moved.
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
	[NSEvent startPeriodicEventsAfterDelay:0.0f withPeriod:PGAnimationFramerate];
	NSEvent *latestEvent = firstEvent;
	PGRectEdgeMask pressedDirections = PGNoEdges;
	NSTimeInterval pageTurnTime = 0.0f, lastScrollTime = 0.0f;
	do {
		NSEventType const type = [latestEvent type];
		if(NSPeriodic == type) {
			NSTimeInterval const currentTime = PGUptime();
			if(currentTime > pageTurnTime + PGPageTurnMovementDelay) {
				NSSize const d = [self distanceInDirection:PGNonContradictoryRectEdges(pressedDirections) forScrollType:PGScrollByLine];
				float const timeAdjustment = (float)(lastScrollTime ? PGAnimationFramerate / (currentTime - lastScrollTime) : 1.0f);
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
	[self AE_postNotificationName:PGClipViewBoundsDidChangeNotification];
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
	[self AE_postNotificationName:PGClipViewBoundsDidChangeNotification];
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
- (void)_scrollOneFrame
{
	NSSize const r = NSMakeSize(_position.x - _immediatePosition.x, _position.y - _immediatePosition.y);
	float const dist = hypotf(r.width, r.height);
	float const factor = MIN(1.0f, MAX(0.25f, 10.0f / dist) * PGLagCounteractionSpeedup(&_lastScrollTime, PGAnimationFramerate));
	if(![self _scrollTo:(dist < 1.0f ? _position : PGOffsetPointByXY(_immediatePosition, r.width * factor, r.height * factor))]) [self stopAnimatedScrolling];
}

- (void)_beginPreliminaryDrag:(NSValue *)val
{
	PGDragMode *dragMode = [val pointerValue];
	NSAssert(PGNotDragging == *dragMode, @"Already dragging.");
	*dragMode = PGPreliminaryDragging;
	[[NSCursor closedHandCursor] push];
}
- (void)_delayedEndGesture
{
	[[self delegate] clipViewGestureDidEnd:self];
}

#pragma mark PGClipViewAdditions Protocol

- (PGClipView *)PG_clipView
{
	return self;
}

#pragma mark -

- (void)PG_scrollRectToVisible:(NSRect)aRect forView:(NSView *)view type:(PGScrollToRectType)type
{
	NSRect const r = [self convertRect:aRect fromView:view];
	NSRect const b = [self insetBounds];
	NSSize o = NSZeroSize;
	NSPoint const preferredVisiblePoint = PGPointOfPartOfRect(r, [self pinLocation]);
	NSPoint const preferredTargetLocation = PGPointOfPartOfRect(b, [self pinLocation]);
	if(NSWidth(r) > NSWidth(b)) o.width = preferredVisiblePoint.x - preferredTargetLocation.x;
	else if(NSMinX(r) < NSMinX(b)) switch(type) {
		case PGScrollLeastToRect:  o.width = NSMinX(r) - NSMinX(b); break;
		case PGScrollCenterToRect: o.width = NSMidX(r) - NSMidX(b); break;
		case PGScrollMostToRect:   o.width = NSMaxX(r) - NSMaxX(b); break;
	} else if(NSMaxX(r) > NSMaxX(b)) switch(type) {
		case PGScrollLeastToRect:  o.width = NSMaxX(r) - NSMaxX(b); break;
		case PGScrollCenterToRect: o.width = NSMidX(r) - NSMidX(b); break;
		case PGScrollMostToRect:   o.width = NSMinX(r) - NSMinX(b); break;
	}
	if(NSHeight(r) > NSHeight(b)) o.height = preferredVisiblePoint.y - preferredTargetLocation.y;
	else if(NSMinY(r) < NSMinY(b)) switch(type) {
		case PGScrollLeastToRect:  o.height = NSMinY(r) - NSMinY(b); break;
		case PGScrollCenterToRect: o.height = NSMidY(r) - NSMidY(b); break;
		case PGScrollMostToRect:   o.height = NSMaxY(r) - NSMaxY(b); break;
	} else if(NSMaxY(r) > NSMaxY(b)) switch(type) {
		case PGScrollLeastToRect:  o.height = NSMaxY(r) - NSMaxY(b); break;
		case PGScrollCenterToRect: o.height = NSMidY(r) - NSMidY(b); break;
		case PGScrollMostToRect:   o.height = NSMinY(r) - NSMinY(b); break;
	}
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
	if(!_backgroundColor) return;
	CGContextSetPatternPhase([[NSGraphicsContext currentContext] graphicsPort], CGSizeMake(0, NSHeight([self bounds])));
	[_backgroundColor set];

	int count;
	NSRect const *rects;
	[self getRectsBeingDrawn:&rects count:&count];
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
	NSRect b = [self insetBounds];
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
	if(![self _setPosition:PGOffsetPointByXY(_immediatePosition, 0.0f, heightDiff) scrollEnclosingClipViews:NO markForRedisplay:YES]) [self AE_postNotificationName:PGClipViewBoundsDidChangeNotification];
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
	if([[self window] isKeyWindow]) [self handleMouseDown:anEvent];
}
- (void)scrollWheel:(NSEvent *)anEvent
{
	[NSCursor setHiddenUntilMouseMoves:YES];
	float const x = -[anEvent deltaX], y = [anEvent deltaY];
	if([anEvent modifierFlags] & NSCommandKeyMask) {
		[self PG_cancelPreviousPerformRequestsWithSelector:@selector(_delayedEndGesture) object:nil];
		[[self delegate] clipView:self magnifyBy:y * PGMouseWheelZoomFactor];
		[self PG_performSelector:@selector(_delayedEndGesture) withObject:nil fireDate:nil interval:-1.0f options:kNilOptions]; // We don't actually know when the zooming will stop, since there's no such thing as a "scroll wheel up" event.
	} else [self scrollBy:NSMakeSize(x * PGMouseWheelScrollFactor, y * PGMouseWheelScrollFactor) animation:PGNoAnimation];
}

#pragma mark -

// Private, invoked by guestures on new laptop trackpads.
- (void)beginGestureWithEvent:(NSEvent *)anEvent
{
	[NSCursor setHiddenUntilMouseMoves:YES];
}
- (void)swipeWithEvent:(NSEvent *)anEvent
{
	[[self delegate] clipView:self shouldExitEdges:PGPointToRectEdgeMaskWithThreshhold(NSMakePoint(-[anEvent deltaX], [anEvent deltaY]), 0.1f)];
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
	if([anEvent modifierFlags] & NSCommandKeyMask) return [super keyDown:anEvent];
	unsigned const modifiers = [anEvent modifierFlags];
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
- (BOOL)performKeyEquivalent:(NSEvent *)anEvent
{
	[NSCursor setHiddenUntilMouseMoves:YES];
	return [super performKeyEquivalent:anEvent] || [[self delegate] performKeyEquivalent:anEvent];
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

- (void)PG_scrollRectToVisible:(NSRect)aRect type:(PGScrollToRectType)type
{
	[self PG_scrollRectToVisible:aRect forView:self type:type];
}
- (void)PG_scrollRectToVisible:(NSRect)aRect forView:(NSView *)view type:(PGScrollToRectType)type
{
	[[self superview] PG_scrollRectToVisible:aRect forView:view type:type];
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
