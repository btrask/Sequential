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
#import "PGAlertView.h"

// Views
#import "PGBezelPanel.h"

// Other
#import "PGNonretainedObjectProxy.h"

// Categories
#import "NSObjectAdditions.h"

#define PGAlertViewSize     300.0f
#define PGAlertMinTopMargin 20.0f

static inline BOOL PGIntersectsRectList(NSRect rect, NSRect const *list, unsigned count)
{
	unsigned i = count;
	while(i--) if(NSIntersectsRect(rect, list[i])) return YES;
	return NO;
}

@interface PGAlertView (Private)

- (void)_delayed_popGraphic:(NSValue *)aGraphicValue; // +cancelPreviousPerformRequestsWithTarget:selector:object: unfortunately compares with -isEqual:, so we wrap the object in NSValue.
- (void)_updateCurrentGraphic;

@end

@implementation PGAlertView

#pragma mark Instance Methods

- (PGAlertGraphic *)currentGraphic
{
	return [[_currentGraphic retain] autorelease];
}
- (void)pushGraphic:(PGAlertGraphic *)aGraphic
        window:(NSWindow *)window
{
	NSParameterAssert(aGraphic);
	unsigned const i = [_graphicStack indexOfObject:aGraphic];
	if(0 == i) {
		[self PG_cancelPreviousPerformRequestsWithSelector:@selector(_delayed_popGraphic:) object:[NSValue valueWithNonretainedObject:_currentGraphic]];
	} else {
		[_graphicStack insertObject:aGraphic atIndex:0];
		[self _updateCurrentGraphic];
	}
	NSTimeInterval const fadeOutDelay = [_currentGraphic fadeOutDelay];
	if(fadeOutDelay) [self PG_performSelector:@selector(_delayed_popGraphic:) withObject:[NSValue valueWithNonretainedObject:_currentGraphic] afterDelay:fadeOutDelay retain:NO];
	if(window && [[self window] respondsToSelector:@selector(displayOverWindow:)]) [(PGBezelPanel *)[self window] displayOverWindow:window];
}
- (void)popGraphic:(PGAlertGraphic *)aGraphic
{
	NSParameterAssert(aGraphic);
	unsigned const i = [_graphicStack indexOfObject:aGraphic];
	if(NSNotFound == i) return;
	[_graphicStack removeObjectAtIndex:i];
	[self _updateCurrentGraphic];
}
- (void)popGraphicIdenticalTo:(PGAlertGraphic *)aGraphic
{
	NSParameterAssert(aGraphic);
	unsigned const i = [_graphicStack indexOfObjectIdenticalTo:aGraphic];
	if(NSNotFound == i) return;
	[_graphicStack removeObjectAtIndex:i];
	[self _updateCurrentGraphic];
}
- (void)popGraphicsOfType:(PGAlertGraphicType)type
{
	PGAlertGraphic *graphic;
	NSEnumerator *const graphicEnum = [[[_graphicStack copy] autorelease] objectEnumerator];
	while((graphic = [graphicEnum nextObject])) if([graphic graphicType] == type) [_graphicStack removeObjectIdenticalTo:graphic];
	[self _updateCurrentGraphic];
}

#pragma mark -

- (unsigned)frameCount
{
	return _frameCount;
}
- (void)animateOneFrame:(NSTimer *)aTimer
{
	NSParameterAssert(_currentGraphic);
	_frameCount++;
	_frameCount %= [_currentGraphic frameMax];
	[_currentGraphic animateOneFrame:self];
}

#pragma mark -

- (void)windowWillClose:(NSNotification *)aNotif
{
	[_frameTimer invalidate];
	_frameTimer = nil;
	[_graphicStack removeAllObjects];
}

#pragma mark Private Protocol

- (void)_delayed_popGraphic:(NSValue *)aGraphicValue
{
	[self popGraphicIdenticalTo:[aGraphicValue nonretainedObjectValue]];
}
- (void)_updateCurrentGraphic
{
	if(![_graphicStack count]) {
		if([_currentGraphic fadeOutDelay]) [(PGBezelPanel *)[self window] fadeOut];
		else [[self window] close];
		return;
	}
	[_currentGraphic release];
	_currentGraphic = [[_graphicStack objectAtIndex:0] retain];
	[_frameTimer invalidate];
	_frameCount = 0;
	NSTimeInterval const animationDelay = [_currentGraphic animationDelay];
	_frameTimer = animationDelay ? [NSTimer timerWithTimeInterval:animationDelay target:self selector:@selector(animateOneFrame:) userInfo:nil repeats:YES] : nil;
	if(_frameTimer) [[NSRunLoop currentRunLoop] addTimer:_frameTimer forMode:PGCommonRunLoopsMode];
	[self setNeedsDisplay:YES];
}

#pragma mark PGBezelPanelContentView Protocol

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)scaleFactor
{
	float const scaledPanelSize = scaleFactor * PGAlertViewSize;
	return NSIntegralRect(NSMakeRect(floorf(NSMidX(aRect) - scaledPanelSize / 2), floorf(MIN(NSMaxY(aRect) - scaledPanelSize - PGAlertMinTopMargin * scaleFactor, NSMinY(aRect) + NSHeight(aRect) * (2.0 / 3.0) - scaledPanelSize / 2)), floorf(scaledPanelSize), floorf(scaledPanelSize)));
}

#pragma mark NSView

- (id)initWithFrame:(NSRect)aRect
{
	if((self = [super initWithFrame:aRect])) {
		_graphicStack = [[NSMutableArray alloc] init];
	}
	return self;
}

- (BOOL)isOpaque
{
	return YES;
}
- (void)drawRect:(NSRect)aRect
{
	[_currentGraphic drawInView:self];
}

- (void)viewWillMoveToWindow:(NSWindow *)aWindow
{
	[[self window] AE_removeObserver:self name:NSWindowWillCloseNotification];
	if(aWindow) [aWindow AE_addObserver:self selector:@selector(windowWillClose:) name:NSWindowWillCloseNotification];
	else [self windowWillClose:nil];
}

#pragma mark NSObject

- (void)dealloc
{
	[self PG_cancelPreviousPerformRequests];
	[self AE_removeObserver];
	[_graphicStack release];
	[_currentGraphic release];
	[_frameTimer invalidate];
	[super dealloc];
}

@end

@interface PGCannotGoRightGraphic : PGAlertGraphic
@end
@interface PGCannotGoLeftGraphic : PGCannotGoRightGraphic
@end

@interface PGLoopedLeftGraphic : PGAlertGraphic
@end
@interface PGLoopedRightGraphic : PGLoopedLeftGraphic
@end

@implementation PGAlertGraphic

#pragma mark Class Methods

+ (id)cannotGoRightGraphic
{
	return [[[PGCannotGoRightGraphic alloc] init] autorelease];
}
+ (id)cannotGoLeftGraphic
{
	return [[[PGCannotGoLeftGraphic alloc] init] autorelease];
}
+ (id)loopedRightGraphic
{
	return [[[PGLoopedRightGraphic alloc] init] autorelease];
}
+ (id)loopedLeftGraphic
{
	return [[[PGLoopedLeftGraphic alloc] init] autorelease];
}

#pragma mark Instance Methods

- (PGAlertGraphicType)graphicType
{
	return PGSingleImageGraphic;
}

#pragma mark -

- (void)drawInView:(PGAlertView *)anAlertView
{
	int count, i;
	NSRect const *rects;
	[anAlertView getRectsBeingDrawn:&rects count:&count];
	[[NSColor colorWithDeviceWhite:0 alpha:0.5] set];
	for(i = count; i--;) {
		NSRectFill(NSIntersectionRect(rects[i], NSMakeRect(0, 50, 50, 200)));
		NSRectFill(NSIntersectionRect(rects[i], NSMakeRect(50, 0, 200, 300)));
		NSRectFill(NSIntersectionRect(rects[i], NSMakeRect(250, 50, 50, 200)));
	}
	NSRect const corners[4] = {NSMakeRect(250, 250, 50, 50),
		NSMakeRect(0, 250, 50, 50),
		NSMakeRect(0, 0, 50, 50),
		NSMakeRect(250, 0, 50, 50)};
	NSPoint const centers[4] = {NSMakePoint(250, 250),
		NSMakePoint(50, 250),
		NSMakePoint(50, 50),
		NSMakePoint(250, 50)};
	for(i = 4; i--;) {
		NSRect const corner = corners[i];
		if(!PGIntersectsRectList(corner, rects, count)) continue; // -needsToDrawRect: is broken in 10.3, see hxxp://developer.apple.com/technotes/tn2002/tn2107.html.
		[[NSColor clearColor] set];
		NSRectFill(corners[i]);
		[[NSColor colorWithDeviceWhite:0 alpha:0.5] set];
		NSBezierPath *const path = [NSBezierPath bezierPath];
		[path moveToPoint:centers[i]];
		[path appendBezierPathWithArcWithCenter:centers[i] radius:50 startAngle:90 * i endAngle:90 * (i + 1)];
		[path closePath];
		[path fill];
	}

	NSShadow *const shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowBlurRadius:4];
	[shadow setShadowOffset:NSMakeSize(0, -1)];
	[shadow setShadowColor:[NSColor blackColor]];
	[shadow set];
}
- (void)flipHorizontally
{
	NSAffineTransform *const flip = [[[NSAffineTransform alloc] init] autorelease];
	[flip translateXBy:300 yBy:0];
	[flip scaleXBy:-1 yBy:1];
	[flip concat];
}

#pragma mark -

- (NSTimeInterval)fadeOutDelay
{
	return 0;
}

#pragma mark -

- (NSTimeInterval)animationDelay
{
	return 0;
}
- (unsigned)frameMax
{
	return 0;
}
- (void)animateOneFrame:(PGAlertView *)anAlertView
{
}

#pragma mark NSObject Protocol

- (unsigned)hash
{
	return [[self class] hash];
}
- (BOOL)isEqual:(id)anObject
{
	return [anObject isMemberOfClass:[self class]];
}

@end

@implementation PGCannotGoRightGraphic

#pragma mark PGAlertGraphic

- (void)drawInView:(PGAlertView *)anAlertView
{
	[super drawInView:anAlertView];

	float const small = 5;
	float const large = 10;
	[[NSColor whiteColor] set];

	NSBezierPath *const arrow = [NSBezierPath bezierPath];
	[arrow appendBezierPathWithArcWithCenter:NSMakePoint(180, 150) radius:large startAngle:315 endAngle:45];
	[arrow appendBezierPathWithArcWithCenter:NSMakePoint(140, 200) radius:small startAngle:45 endAngle:90];
	[arrow appendBezierPathWithArcWithCenter:NSMakePoint(125, 200) radius:small startAngle:90 endAngle:180];
	[arrow appendBezierPathWithArcWithCenter:NSMakePoint(115, 180) radius:small startAngle:0 endAngle:270 clockwise:YES];
	[arrow appendBezierPathWithArcWithCenter:NSMakePoint(75, 170) radius:small startAngle:90 endAngle:180];
	[arrow appendBezierPathWithArcWithCenter:NSMakePoint(75, 130) radius:small startAngle:180 endAngle:270];
	[arrow appendBezierPathWithArcWithCenter:NSMakePoint(115, 120) radius:small startAngle:90 endAngle:0 clockwise:YES];
	[arrow appendBezierPathWithArcWithCenter:NSMakePoint(125, 100) radius:small startAngle:180 endAngle:270];
	[arrow appendBezierPathWithArcWithCenter:NSMakePoint(140, 100) radius:small startAngle:270 endAngle:315];
	[arrow fill];

	NSBezierPath *const wall = [NSBezierPath bezierPath];
	[wall setLineWidth:20];
	[wall setLineCapStyle:NSRoundLineCapStyle];
	[wall moveToPoint:NSMakePoint(210, 220)];
	[wall lineToPoint:NSMakePoint(210, 80)];
	[wall stroke];
}

#pragma mark -

- (NSTimeInterval)fadeOutDelay
{
	return 1;
}

@end

@implementation PGCannotGoLeftGraphic

#pragma mark PGAlertGraphic

- (void)drawInView:(PGAlertView *)anAlertView
{
	[self flipHorizontally];
	[super drawInView:anAlertView];
}

@end

@implementation PGLoopedLeftGraphic

#pragma mark PGAlertGraphic

- (PGAlertGraphicType)graphicType
{
	return PGInterImageGraphic;
}
- (void)drawInView:(PGAlertView *)anAlertView
{
	[super drawInView:anAlertView];

	[[NSColor whiteColor] set];

	NSBezierPath *const s = [NSBezierPath bezierPath];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(105, 155) radius:65 startAngle:90 endAngle:270 clockwise:NO];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(150, 85) radius:5 startAngle:90 endAngle:0 clockwise:YES];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(160, 65) radius:5 startAngle:180 endAngle:270 clockwise:NO];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(165, 65) radius:5 startAngle:270 endAngle:-45 clockwise:NO];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(200, 105) radius:10 startAngle:-45 endAngle:45 clockwise:NO];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(165, 145) radius:5 startAngle:45 endAngle:90 clockwise:NO];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(160, 145) radius:5 startAngle:90 endAngle:180 clockwise:NO];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(150, 125) radius:5 startAngle:0 endAngle:270 clockwise:YES];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(105, 155) radius:35 startAngle:270 endAngle:90 clockwise:YES];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(195, 155) radius:35 startAngle:90 endAngle:0 clockwise:YES];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(245, 155) radius:15 startAngle:180 endAngle:0 clockwise:NO];
	[s appendBezierPathWithArcWithCenter:NSMakePoint(195, 155) radius:65 startAngle:0 endAngle:90 clockwise:NO];
	[s fill];
}

#pragma mark -

- (NSTimeInterval)fadeOutDelay
{
	return 0.5;
}

@end

@implementation PGLoopedRightGraphic

#pragma mark PGAlertGraphic

- (void)drawInView:(PGAlertView *)anAlertView
{
	[self flipHorizontally];
	[super drawInView:anAlertView];
}

@end

@implementation PGLoadingGraphic

#pragma mark Class Methods

+ (id)loadingGraphic
{
	return [[[PGLoadingGraphic alloc] init] autorelease];
}

#pragma mark Instance methods

- (float)progress
{
	return _progress;
}
- (void)setProgress:(float)progress
{
	_progress = MIN(MAX(progress, 0), 1);
}

#pragma mark NSObject Protocol

- (unsigned)hash
{
	return (unsigned)self;
}
- (BOOL)isEqual:(id)anObject
{
	return anObject == self;
}

#pragma mark PGAlertGraphic

- (void)drawInView:(PGAlertView *)anAlertView
{
	[super drawInView:anAlertView];
	unsigned const frameCount = [anAlertView frameCount];
	float const s = _progress ? 0.9 : 1;
	float const h = _progress ? 155.0 : 150.0;
	unsigned i;
	for(i = 0; i < 12; i++) {
		NSBezierPath *const line = [[[NSBezierPath alloc] init] autorelease];
		[line setLineWidth:20 * s];
		[line setLineCapStyle:NSRoundLineCapStyle];
		[line moveToPoint:NSMakePoint(150 + cosf((i / 12.0) * pi * 2) * 55 * s, h + sinf((i / 12.0) * pi * 2) * 55 * s)];
		[line lineToPoint:NSMakePoint(150 + cosf((i / 12.0) * pi * 2) * 110 * s, h + sinf((i / 12.0) * pi * 2) * 110 * s)];
		[[NSColor colorWithDeviceWhite:1 alpha:(((frameCount + i) % 12) / -12.0) + 1] set];
		[line stroke];
	}
	if(!_progress) return;
	BOOL switched = NO;
	[[NSColor whiteColor] set];
	for(i = 0; i < 22; i++) {
		if(!switched && i >= _progress * 22) {
			NSShadow *const shadow = [[[NSShadow alloc] init] autorelease];
			[shadow setShadowColor:nil];
			[shadow set];
			[[NSColor colorWithDeviceWhite:0.1 alpha:0.9] set];
			switched = YES;
		}
		NSRectFill(NSMakeRect(51 + i * 9, 30, 7, 9));
	}
}

#pragma mark -

- (NSTimeInterval)animationDelay
{
	return 1.0 / 12.0;
}
- (unsigned)frameMax
{
	return 12;
}
- (void)animateOneFrame:(PGAlertView *)anAlertView
{
	[anAlertView setNeedsDisplayInRect:NSMakeRect(25, 50, 25, 200)];
	[anAlertView setNeedsDisplayInRect:NSMakeRect(50, 25, 200, 250)];
	[anAlertView setNeedsDisplayInRect:NSMakeRect(250, 50, 25, 200)];
}

@end
