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
#import "PGImageView.h"

// Views
@class PGClipView;

// Other
#import "PGNonretainedObjectProxy.h"

// Categories
#import "NSObjectAdditions.h"

@interface PGImageView (Private)

- (void)_updateAnimationTimer;
- (void)_animate;
- (void)_cache;
- (void)_drawInRect:(NSRect)aRect;
- (void)_drawCornersOnRect:(NSRect)r;
- (NSAffineTransform *)_transformWithRotationInDegrees:(float)val;
- (void)_updateFrameSize;

@end

@implementation PGImageView

#pragma mark NSObject

+ (void)initialize
{
	if([PGImageView class] != self) return;
	[self exposeBinding:@"animates"];
	[self exposeBinding:@"antialiasWhenUpscaling"];
	[self exposeBinding:@"drawsRoundedCorners"];
}

#pragma mark Instance Methods

- (NSImageRep *)rep
{
	return [[_rep retain] autorelease];
}
- (PGOrientation)orientation
{
	return _orientation;
}
- (void)setImageRep:(NSImageRep *)rep
        orientation:(PGOrientation)orientation
        size:(NSSize)size
{
	_orientation = orientation;
	if(rep != _rep) {
		[_image removeRepresentation:_rep];
		_cacheIsValid = NO;
		[_image removeRepresentation:_cache];
		[_rep release];
		_rep = nil;
		[self setSize:size];
		_rep = [rep retain];
		[_image addRepresentation:_rep];
		_isOpaque = _rep && ![_rep hasAlpha];
		_isPDF = [_rep isKindOfClass:[NSPDFImageRep class]];
		_numberOfFrames = [_rep isKindOfClass:[NSBitmapImageRep class]] ? [[(NSBitmapImageRep *)_rep valueForProperty:NSImageFrameCount] unsignedIntValue] : 1;

		[self _updateAnimationTimer];
	} else [self setSize:size];
	[self _cache];
	[self setNeedsDisplay:YES];
}

#pragma mark -

- (NSSize)size
{
	return _size;
}
- (void)setSize:(NSSize)size
{
	if(NSEqualSizes(size, _size)) return;
	_size = size;
	[self _updateFrameSize];
}
- (float)averageScaleFactor
{
	return (PGRotated90CC && _orientation ? [self size].height / [_rep pixelsWide] + [self size].width / [_rep pixelsHigh] : [self size].width / [_rep pixelsWide] + [self size].height / [_rep pixelsHigh]) / 2.0;
}

#pragma mark -

- (BOOL)usesCaching
{
	return _usesCaching;
}
- (void)setUsesCaching:(BOOL)flag
{
	if(flag == _usesCaching) return;
	_usesCaching = flag;
	if(!flag || !_cacheIsOutOfDate) return;
	_cacheIsOutOfDate = NO;
	[self _cache];
}

#pragma mark -

- (float)rotationInDegrees
{
	return _rotationInDegrees;
}
- (void)setRotationInDegrees:(float)val
{
	if(val == _rotationInDegrees) return;
	_rotationInDegrees = remainderf(val, 360);
	[self _updateFrameSize];
	[self setNeedsDisplay:YES];
}
- (NSPoint)rotateByDegrees:(float)val
{
	NSRect const r = [self convertRect:[[self superview] bounds] fromView:[self superview]];
	NSRect const b1 = [self bounds];
	NSPoint screenCenter = NSMakePoint(NSMidX(r) - NSMidX(b1), NSMidY(r) - NSMidY(b1)); // Our bounds are going to change to fit the rotated image. Any point we want to remain constant relative to the image, we have to make relative to the bounds' center, since that's where the image is drawn.
	[self setRotationInDegrees:[self rotationInDegrees] + val];
	NSRect const b2 = [self bounds];
	screenCenter.x += NSMidX(b2);
	screenCenter.y += NSMidY(b2);
	return [self convertPoint:[[self _transformWithRotationInDegrees:val] transformPoint:screenCenter] toView:[self superview]];
}

#pragma mark -

- (BOOL)canAnimateRep
{
	return _numberOfFrames > 1;
}
- (BOOL)animates
{
	return _animates;
}
- (void)setAnimates:(BOOL)flag
{
	if(flag == _animates) return;
	_animates = flag;
	[self _updateAnimationTimer];
}
- (void)pauseAnimation
{
	_pauseCount++;
	[self _updateAnimationTimer];
}
- (void)resumeAnimation
{
	NSParameterAssert(_pauseCount);
	_pauseCount--;
	[self _updateAnimationTimer];
}

#pragma mark -

- (BOOL)antialiasWhenUpscaling
{
	return _antialias;
}
- (void)setAntialiasWhenUpscaling:(BOOL)flag
{
	if(flag == _antialias) return;
	_antialias = flag;
	[self _cache];
	[self setNeedsDisplay:YES];
}
- (NSImageInterpolation)interpolation
{
	if([self antialiasWhenUpscaling]) return NSImageInterpolationHigh;
	NSSize const imageSize = NSMakeSize([_rep pixelsWide], [_rep pixelsHigh]), viewSize = [self size];
	return imageSize.width < viewSize.width && imageSize.height < viewSize.height ? NSImageInterpolationNone : NSImageInterpolationHigh;
}

#pragma mark -

- (BOOL)drawsRoundedCorners
{
	if(!_drawsRoundedCorners) return NO;
	NSSize const s = [self size];
	return s.width >= 16 && s.height >= 16;
}
- (void)setDrawsRoundedCorners:(BOOL)flag
{
	if(flag == _drawsRoundedCorners) return;
	_drawsRoundedCorners = flag;
	[self _cache];
	[self setNeedsDisplay:YES];
}
- (BOOL)usesOptimizedDrawing
{
	return _cacheIsValid || PGUpright == _orientation;
}

#pragma mark -

- (void)appDidHide:(NSNotification *)aNotif
{
	[self pauseAnimation];
}
- (void)appDidUnhide:(NSNotification *)aNotif
{
	[self resumeAnimation];
}

#pragma mark Private Protocol

- (void)_updateAnimationTimer
{
	if([self canAnimateRep] && _animates && !_pauseCount) {
		if(_animationTimer) return;
		_animationTimer = [NSTimer timerWithTimeInterval:[[(NSBitmapImageRep *)_rep valueForProperty:NSImageCurrentFrameDuration] floatValue] target:[self autorelease] selector:@selector(_animate) userInfo:nil repeats:YES]; // The timer retains us.
		[[NSRunLoop currentRunLoop] addTimer:_animationTimer forMode:PGCommonRunLoopsMode];
	} else {
		if(!_animationTimer) return;
		[self retain];
		[_animationTimer invalidate];
		_animationTimer = nil;
	}
}
- (void)_animate
{
	unsigned const i = [[(NSBitmapImageRep *)_rep valueForProperty:NSImageCurrentFrame] unsignedIntValue] + 1;
	[(NSBitmapImageRep *)_rep setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithUnsignedInt:(i < _numberOfFrames ? i : 0)]];
	[self setNeedsDisplay:YES];
}
- (void)_cache
{
	[NSObject cancelPreviousPerformRequestsWithTarget:[self PG_nonretainedObjectProxy] selector:@selector(_cache) object:nil];
	if(!_cache || !_rep || _isPDF || [self canAnimateRep]) return;
	if(_cacheIsValid) {
		_cacheIsValid = NO;
		[_image removeRepresentation:_cache];
	} else [_image removeRepresentation:_rep];
	NSSize const pixelSize = NSMakeSize([_rep pixelsWide], [_rep pixelsHigh]);
	[_image setSize:pixelSize];
	[_image addRepresentation:_rep];
	if(![self usesCaching] || [self inLiveResize]) {
		_cacheIsOutOfDate = YES;
		return;
	}
	NSSize const scaledSize = [self size];
	if(scaledSize.width > 10000 || scaledSize.height > 10000) return; // 10,000 is a hard limit imposed on window size by the Window Server.

	[_cache setSize:scaledSize];
	[_cache setPixelsWide:scaledSize.width];
	[_cache setPixelsHigh:scaledSize.height];
	NSWindow *const cacheWindow = [_cache window];
	NSRect cacheWindowFrame = [cacheWindow frame];
	cacheWindowFrame.size.width = MAX(NSWidth(cacheWindowFrame), scaledSize.width);
	cacheWindowFrame.size.height = MAX(NSHeight(cacheWindowFrame), scaledSize.height);
	[cacheWindow setFrame:cacheWindowFrame display:NO];
	NSView *const view = [cacheWindow contentView];
	if(![view lockFocusIfCanDraw]) return [[self PG_nonretainedObjectProxy] AE_performSelector:@selector(_cache) withObject:nil afterDelay:0];
	[self _drawInRect:[_cache rect]];
	[self _drawCornersOnRect:[_cache rect]];
	[view unlockFocus];
	[_image removeRepresentation:_rep];
	[_image setSize:scaledSize];
	[_image addRepresentation:_cache];
	_cacheIsValid = YES;
}
- (void)_drawInRect:(NSRect)aRect
{
	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setImageInterpolation:[self interpolation]];
	NSRect r = aRect;
	if(PGUpright != _orientation) {
		NSAffineTransform *const t = [NSAffineTransform transform];
		[t translateXBy:NSMidX(r) yBy:NSMidY(r)];
		if(_orientation & PGRotated90CC) {
			r.size = NSMakeSize(NSHeight(r), NSWidth(r));
			[t rotateByDegrees:90];
		}
		[t scaleXBy:(_orientation & PGFlippedHorz ? -1 : 1) yBy:(_orientation & PGFlippedVert ? -1 : 1)];
		[t concat];
		r.origin = NSMakePoint(NSWidth(r) / -2, NSHeight(r) / -2);
	}
	[_rep drawInRect:r];
	[NSGraphicsContext restoreGraphicsState];
}
- (void)_drawCornersOnRect:(NSRect)r
{
	if(!_rep || ![self drawsRoundedCorners]) return;
	static NSImage *tl = nil, *tr = nil, *br = nil, *bl = nil;
	if(!tl) tl = [[NSImage imageNamed:@"Corner-Top-Left"] retain];
	if(!tr) tr = [[NSImage imageNamed:@"Corner-Top-Right"] retain];
	if(!br) br = [[NSImage imageNamed:@"Corner-Bottom-Right"] retain];
	if(!bl) bl = [[NSImage imageNamed:@"Corner-Bottom-Left"] retain];
	[tl drawAtPoint:NSMakePoint(NSMinX(r), NSMaxY(r) - [tl size].height) fromRect:NSZeroRect operation:NSCompositeDestinationOut fraction:1];
	[tr drawAtPoint:NSMakePoint(NSMaxX(r) - [tr size].width, NSMaxY(r) - [tr size].height) fromRect:NSZeroRect operation:NSCompositeDestinationOut fraction:1];
	[br drawAtPoint:NSMakePoint(NSMaxX(r) - [br size].width, NSMinY(r)) fromRect:NSZeroRect operation:NSCompositeDestinationOut fraction:1];
	[bl drawAtPoint:NSMakePoint(NSMinX(r), NSMinY(r)) fromRect:NSZeroRect operation:NSCompositeDestinationOut fraction:1];
}
- (NSAffineTransform *)_transformWithRotationInDegrees:(float)val
{
	NSRect const b = [self bounds];
	NSAffineTransform *const t = [NSAffineTransform transform];
	[t translateXBy:NSMidX(b) yBy:NSMidY(b)];
	[t rotateByDegrees:val];
	[t translateXBy:-NSMidX(b) yBy:-NSMidY(b)];
	return t;
}
- (void)_updateFrameSize
{
	NSSize s = [self size];
	float const r = [self rotationInDegrees] / 180.0 * pi;
	if(r) s = NSMakeSize(ceilf(fabs(cosf(r)) * s.width + fabs(sinf(r)) * s.height), ceilf(fabs(cosf(r)) * s.height + fabs(sinf(r)) * s.width));
	if(NSEqualSizes(s, [self frame].size)) return;
	[super setFrameSize:s];
	[self _cache];
}

#pragma mark PGClipViewDocumentView Protocol

- (BOOL)isSolidForClipView:(PGClipView *)sender
{
	return NO;
}

#pragma mark NSView

- (id)initWithFrame:(NSRect)aRect
{
	if((self = [super initWithFrame:aRect])) {
		_image = [[NSImage alloc] init];
		[_image setScalesWhenResized:NO]; // NSImage seems to make copies of its reps when resizing despite this, so be careful..
		[_image setCacheMode:NSImageCacheNever]; // We do our own caching.
		[_image setDataRetained:YES]; // Seems appropriate.
		_usesCaching = YES;
		_antialias = YES;
		_drawsRoundedCorners = YES;
		[NSApp AE_addObserver:self selector:@selector(appDidHide:) name:NSApplicationDidHideNotification];
		[NSApp AE_addObserver:self selector:@selector(appDidUnhide:) name:NSApplicationDidUnhideNotification];
	}
	return self;
}

- (BOOL)isOpaque
{
	return _isOpaque && ![self drawsRoundedCorners] && ![self rotationInDegrees];
}
- (void)drawRect:(NSRect)aRect
{
	NSRect b = (NSRect){NSZeroPoint, [self size]};
	b.origin.x = roundf(NSMidX([self bounds]) - NSWidth(b) / 2);
	b.origin.y = roundf(NSMidY([self bounds]) - NSHeight(b) / 2);

	float const deg = [self rotationInDegrees];
	if(deg) {
		[NSGraphicsContext saveGraphicsState];
		[[self _transformWithRotationInDegrees:deg] concat];
	}
	BOOL const drawCorners = !_cacheIsValid && [self drawsRoundedCorners];
	if(drawCorners) CGContextBeginTransparencyLayer([[NSGraphicsContext currentContext] graphicsPort], NULL);
	int count = 0;
	NSRect const *rects = NULL;
	if(_isPDF) {
		[[NSColor whiteColor] set];
		if(deg) NSRectFill(b);
		else {
			[self getRectsBeingDrawn:&rects count:&count];
			NSRectFillList(rects, count);
		}
	}
	if([self usesOptimizedDrawing]) {
		NSCompositingOperation const operation = !_isPDF && [self isOpaque] ? NSCompositeCopy : NSCompositeSourceOver;
		if(deg) [_image drawInRect:b fromRect:NSZeroRect operation:operation fraction:1.0];
		else {
			if(!rects) [self getRectsBeingDrawn:&rects count:&count]; // Be sure this gets read.
			NSPoint const scale = NSMakePoint([_image size].width / NSWidth(b), [_image size].height / NSHeight(b));
			int i = count;
			while(i--) [_image drawInRect:rects[i] fromRect:NSMakeRect(NSMinX(rects[i]) * scale.x, NSMinY(rects[i]) * scale.y, NSWidth(rects[i]) * scale.x, NSHeight(rects[i]) * scale.y) operation:operation fraction:1.0];
		}
	} else [self _drawInRect:b];
	if(drawCorners) {
		[self _drawCornersOnRect:b];
		CGContextEndTransparencyLayer([[NSGraphicsContext currentContext] graphicsPort]);
	}
	if(deg) [NSGraphicsContext restoreGraphicsState];
}
- (void)setFrameSize:(NSSize)aSize
{
	NSLog(@"-[PGImageView setFrameSize:] should not be invoked directly. Use -setSize: instead.");
}
- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	if(!_cacheIsOutOfDate) return;
	_cacheIsOutOfDate = NO;
	[self _cache];
}
- (void)viewDidMoveToWindow
{
	if(_cacheIsValid) {
		_cacheIsValid = NO;
		[_image removeRepresentation:_cache];
	}
	[_cache release];
	_cache = [self window] ? [[NSCachedImageRep alloc] initWithSize:NSMakeSize(1, 1) depth:[[self window] depthLimit] separate:YES alpha:YES] : nil;
	[self _cache];
}

#pragma mark NSObject

- (id)init
{
	return [self initWithFrame:NSZeroRect];
}
- (void)dealloc
{
	[self AE_removeObserver];
	[self unbind:@"animates"];
	[self unbind:@"antialiasWhenUpscaling"];
	[self setImageRep:nil orientation:PGUpright size:NSZeroSize];
	NSParameterAssert(!_rep);
	[_cache release];
	[self setAnimates:NO];
	[_image release];
	[super dealloc];
}

@end
