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
// Other Sources
#import "PGGeometryTypes.h"

extern NSString *const PGClipViewBoundsDidChangeNotification;

enum {
	PGScrollByLine = 0,
	PGScrollByPage = 1
};
typedef NSUInteger PGScrollType;

enum {
	PGNoAnimation = 0,
	PGAllowAnimation = 1,
	PGPreferAnimation = 2
};
typedef NSUInteger PGAnimationType;

enum {
	PGScrollLeastToRect = 0,
	PGScrollCenterToRect = 1,
	PGScrollMostToRect = 2
};
typedef NSUInteger PGScrollToRectType;

@protocol PGClipViewDelegate;

@interface PGClipView : NSView
{
	@private
	IBOutlet NSResponder<PGClipViewDelegate> * delegate;
	IBOutlet NSView *documentView;
	NSRect _documentFrame;
	PGInset _boundsInset;
	NSColor *_backgroundColor;
	BOOL _backgroundIsComplex;
	BOOL _showsBorder;
	NSCursor *_cursor;
	NSPoint _position;
	BOOL _acceptsFirstResponder;
	NSUInteger _documentViewIsResizing;
	BOOL _firstMouse;
	NSUInteger _scrollCount;

	BOOL _allowsAnimation;
	NSPoint _startPosition;
	NSPoint _targetPosition;
	CGFloat _animationProgress;
	NSTimer *_animationTimer;
	NSTimeInterval _lastAnimationTime;
}

@property(assign, nonatomic) NSResponder<PGClipViewDelegate> *delegate;
@property(retain, nonatomic) NSView *documentView;
@property(readonly) NSRect documentFrame;
@property(assign, nonatomic) PGInset boundsInset;
@property(readonly) NSRect insetBounds;
@property(retain, nonatomic) NSColor *backgroundColor;
@property(assign, nonatomic) BOOL showsBorder;
@property(retain, nonatomic) NSCursor *cursor;
@property(assign, nonatomic, getter = isScrolling) BOOL scrolling;
@property(assign, nonatomic) BOOL allowsAnimation;
@property(assign, nonatomic) BOOL acceptsFirstResponder;

@property(readonly) NSPoint position;
@property(readonly) NSPoint center;
@property(readonly) NSPoint relativeCenter;
@property(readonly) NSSize pinLocationOffset;

- (BOOL)scrollTo:(NSPoint)aPoint animation:(PGAnimationType)type;
- (BOOL)scrollBy:(NSSize)aSize animation:(PGAnimationType)type;
- (BOOL)scrollToEdge:(PGRectEdgeMask)mask animation:(PGAnimationType)type;
- (BOOL)scrollToLocation:(PGPageLocation)location animation:(PGAnimationType)type;
- (BOOL)scrollCenterTo:(NSPoint)aPoint animation:(PGAnimationType)type;
- (BOOL)scrollRelativeCenterTo:(NSPoint)aPoint animation:(PGAnimationType)type;
- (BOOL)scrollPinLocationToOffset:(NSSize)aSize animation:(PGAnimationType)type;
- (void)stopAnimatedScrolling;

- (NSRect)documentFrameWithBorder:(BOOL)flag;
- (NSRect)scrollableRectWithBorder:(BOOL)flag;
- (NSSize)distanceInDirection:(PGRectEdgeMask)direction forScrollType:(PGScrollType)scrollType;
- (NSSize)distanceInDirection:(PGRectEdgeMask)direction forScrollType:(PGScrollType)scrollType fromPosition:(NSPoint)position;
- (NSSize)maximumDistanceForScrollType:(PGScrollType)scrollType;
- (BOOL)shouldExitForMovementInDirection:(PGRectEdgeMask)mask;

- (BOOL)handleMouseDown:(NSEvent *)firstEvent;
- (void)arrowKeyDown:(NSEvent *)firstEvent;
- (void)scrollInDirection:(PGRectEdgeMask)direction type:(PGScrollType)scrollType;
- (void)magicPanForward:(BOOL)forward acrossFirst:(BOOL)across;

- (void)viewFrameDidChange:(NSNotification *)aNotif;

@end

@protocol PGClipViewDelegate <NSObject>

@optional
- (BOOL)clipView:(PGClipView *)sender handleMouseEvent:(NSEvent *)anEvent first:(BOOL)flag;
- (BOOL)clipView:(PGClipView *)sender handleKeyDown:(NSEvent *)anEvent;
- (BOOL)clipView:(PGClipView *)sender shouldExitEdges:(PGRectEdgeMask)mask;
- (PGRectEdgeMask)clipView:(PGClipView *)sender directionFor:(PGPageLocation)pageLocation; // Don't provide contradictory directions.
- (void)clipView:(PGClipView *)sender magnifyBy:(CGFloat)amount;
- (void)clipView:(PGClipView *)sender rotateByDegrees:(CGFloat)amount;
- (void)clipViewGestureDidEnd:(PGClipView *)sender;

@end

@interface NSView(PGClipViewAdditions)

@property(readonly) PGClipView *PG_enclosingClipView;
@property(readonly) PGClipView *PG_clipView;

- (void)PG_scrollRectToVisible:(NSRect)aRect type:(PGScrollToRectType)type;
- (void)PG_scrollRectToVisible:(NSRect)aRect forView:(NSView *)view type:(PGScrollToRectType)type;

- (BOOL)PG_acceptsClicksInClipView:(PGClipView *)sender;
- (BOOL)PG_scalesContentWithFrameSizeInClipView:(PGClipView *)sender;
- (void)PG_viewWillScrollInClipView:(PGClipView *)clipView;
- (void)PG_viewDidScrollInClipView:(PGClipView *)clipView;

- (NSView *)PG_deepestViewAtPoint:(NSPoint)aPoint;

@end
