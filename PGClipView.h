/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

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
typedef int PGScrollType;

@interface PGClipView : NSView
{
	@private
	IBOutlet id              delegate;
	IBOutlet NSView         *documentView;
	         NSRect         _documentFrame;
	         NSColor       *_backgroundColor;
	         NSPoint        _position;
	         NSTimer       *_scrollTimer;
	         NSTimeInterval _lastScrollTime;
	         NSPoint        _immediatePosition;
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

- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)aColor;

- (NSRect)scrollableRectWithBorder:(BOOL)flag;
- (NSSize)distanceInDirection:(PGRectEdgeMask)direction forScrollType:(PGScrollType)scrollType;
- (NSSize)distanceInDirection:(PGRectEdgeMask)direction forScrollType:(PGScrollType)scrollType fromPosition:(NSPoint)position;
- (BOOL)shouldExitForMovementInDirection:(PGRectEdgeMask)mask;

- (NSPoint)position;
- (NSPoint)center;
- (BOOL)scrollTo:(NSPoint)aPoint allowAnimation:(BOOL)flag;
- (BOOL)scrollToCenterAt:(NSPoint)aPoint allowAnimation:(BOOL)flag;
- (BOOL)scrollBy:(NSSize)aSize allowAnimation:(BOOL)flag;
- (BOOL)scrollToEdge:(PGRectEdgeMask)mask allowAnimation:(BOOL)flag;
- (BOOL)scrollToLocation:(PGPageLocation)location allowAnimation:(BOOL)flag;
- (void)stopAnimatedScrolling;

- (void)mouseDown:(NSEvent *)firstEvent secondaryButton:(BOOL)flag;
- (void)arrowKeyDown:(NSEvent *)firstEvent;
- (void)scrollInDirection:(PGRectEdgeMask)direction type:(PGScrollType)scrollType;
- (void)magicPanForward:(BOOL)forward acrossFirst:(BOOL)across;

- (void)viewFrameDidChange:(NSNotification *)aNotif;

@end

@interface NSObject (PGClipViewDelegate)

- (void)clipViewWasClicked:(PGClipView *)sender event:(NSEvent *)anEvent;
- (BOOL)clipView:(PGClipView *)sender handleKeyDown:(NSEvent *)anEvent;
- (BOOL)clipView:(PGClipView *)sender shouldExitEdges:(PGRectEdgeMask)mask;
- (PGRectEdgeMask)clipView:(PGClipView *)sender directionFor:(PGPageLocation)pageLocation; // Don't provide contradictory directions.
- (void)clipView:(PGClipView *)sender magnifyBy:(float)amount;
- (void)clipViewGestureDidEnd:(PGClipView *)sender;

@end

@interface NSView (PGClipViewDocumentView)

- (BOOL)isSolidForClipView:(PGClipView *)sender;

@end
