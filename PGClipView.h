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
#import <Cocoa/Cocoa.h>

// Other
#import "PGGeometry.h"

enum {
	PGScrollByLine = 0,
	PGScrollByPage = 1
};
typedef unsigned PGScrollType;

enum {
	PGNoAnimation     = 0,
	PGAllowAnimation  = 1,
	PGPreferAnimation = 2
};
typedef unsigned PGAnimationType;

@interface PGClipView : NSView
{
	@private
	IBOutlet id              delegate;
	IBOutlet NSView         *documentView;
	         NSRect         _documentFrame;
	         PGInset        _boundsInset;
	         NSColor       *_backgroundColor;
	         BOOL           _showsBorder;
	         NSCursor      *_cursor;
	         NSPoint        _immediatePosition;
	         NSPoint        _position;
	         NSTimer       *_scrollTimer;
	         NSTimeInterval _lastScrollTime;
	         PGRectEdgeMask _pinLocation;
	         enum {
	                        PGNotDragging,
	                        PGPreliminaryDragging,
	                        PGDragging
	         }              _dragMode;
	         BOOL           _firstMouse;
}

- (id)delegate;
- (void)setDelegate:(id)anObject;

- (NSView *)documentView;
- (void)setDocumentView:(NSView *)aView;
- (PGInset)boundsInset;
- (void)setBoundsInset:(PGInset)inset;
- (NSRect)insetBounds;

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)aColor;
- (BOOL)showsBorder;
- (void)setShowsBorder:(BOOL)flag;
- (NSCursor *)cursor;
- (void)setCursor:(NSCursor *)cursor;

- (NSRect)scrollableRectWithBorder:(BOOL)flag;
- (NSSize)distanceInDirection:(PGRectEdgeMask)direction forScrollType:(PGScrollType)scrollType;
- (NSSize)distanceInDirection:(PGRectEdgeMask)direction forScrollType:(PGScrollType)scrollType fromPosition:(NSPoint)position;
- (NSSize)maximumDistanceForScrollType:(PGScrollType)scrollType;
- (BOOL)shouldExitForMovementInDirection:(PGRectEdgeMask)mask;

- (NSPoint)position;
- (NSPoint)positionForScrollAnimation:(PGAnimationType)type;
- (BOOL)scrollTo:(NSPoint)aPoint animation:(PGAnimationType)type;
- (BOOL)scrollBy:(NSSize)aSize animation:(PGAnimationType)type;
- (BOOL)scrollToEdge:(PGRectEdgeMask)mask animation:(PGAnimationType)type;
- (BOOL)scrollToLocation:(PGPageLocation)location animation:(PGAnimationType)type;
- (void)stopAnimatedScrolling;

- (PGRectEdgeMask)pinLocation;
- (void)setPinLocation:(PGRectEdgeMask)mask;
- (NSSize)pinLocationOffset;
- (BOOL)scrollPinLocationToOffset:(NSSize)aSize;

- (NSPoint)center;
- (BOOL)scrollCenterTo:(NSPoint)aPoint animation:(PGAnimationType)type;

- (BOOL)handleMouseDown:(NSEvent *)firstEvent;
- (void)arrowKeyDown:(NSEvent *)firstEvent;
- (void)scrollInDirection:(PGRectEdgeMask)direction type:(PGScrollType)scrollType;
- (void)magicPanForward:(BOOL)forward acrossFirst:(BOOL)across;

- (void)viewFrameDidChange:(NSNotification *)aNotif;

@end

@interface NSObject (PGClipViewDelegate)

- (BOOL)clipView:(PGClipView *)sender handleMouseEvent:(NSEvent *)anEvent first:(BOOL)flag;
- (BOOL)clipView:(PGClipView *)sender handleKeyDown:(NSEvent *)anEvent;
- (BOOL)clipView:(PGClipView *)sender shouldExitEdges:(PGRectEdgeMask)mask;
- (PGRectEdgeMask)clipView:(PGClipView *)sender directionFor:(PGPageLocation)pageLocation; // Don't provide contradictory directions.
- (void)clipView:(PGClipView *)sender magnifyBy:(float)amount;
- (void)clipView:(PGClipView *)sender rotateByDegrees:(float)amount;
- (void)clipViewGestureDidEnd:(PGClipView *)sender;

@end

@interface NSView (PGClipViewAdditions)

- (PGClipView *)PG_enclosingClipView;
- (PGClipView *)PG_clipView;

- (void)PG_scrollRectToVisible:(NSRect)aRect;
- (void)PG_scrollRectToVisible:(NSRect)aRect forView:(NSView *)view;

- (BOOL)PG_acceptsClicksInClipView:(PGClipView *)sender;
- (BOOL)PG_scalesContentWithFrameSizeInClipView:(PGClipView *)sender;
- (void)PG_viewDidScrollInClipView:(PGClipView *)clipView;

@end
