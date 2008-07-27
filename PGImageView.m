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
	[super setFrameSize:size];
	if(rep != _rep) {
		[_image removeRepresentation:_rep];
		_cacheIsValid = NO;
		[_image removeRepresentation:_cache];
		[_rep release];
		_rep = [rep retain];
		[_image addRepresentation:_rep];
		_isOpaque = _rep && ![_rep hasAlpha];
		_isPDF = [_rep isKindOfClass:[NSPDFImageRep class]];
		_numberOfFrames = [_rep isKindOfClass:[NSBitmapImageRep class]] ? [[(NSBitmapImageRep *)_rep valueForProperty:NSImageFrameCount] unsignedIntValue] : 1;

		[self _updateAnimationTimer];
	}
	[self _cache];
	[self setNeedsDisplay:YES];
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
	NSSize const imageSize = NSMakeSize([_rep pixelsWide], [_rep pixelsHigh]);
	NSSize const viewSize = [self frame].size;
	return imageSize.width < viewSize.width && imageSize.height < viewSize.height ? NSImageInterpolationNone : NSImageInterpolationHigh;
}

#pragma mark -

- (BOOL)drawsRoundedCorners
{
	if(!_drawsRoundedCorners) return NO;
	NSSize const s = [self frame].size;
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
	return _cacheIsValid  || PGUpright == _orientation;
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
	if([self inLiveResize]) {
		_cheatedDuringLiveResize = YES;
		return; // Don't bother until we stop.
	}
	NSSize const scaledSize = [self frame].size;
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
		NSAffineTransform *const orient = [[[NSAffineTransform alloc] init] autorelease];
		[orient translateXBy:NSWidth(r) / 2 yBy:NSHeight(r) / 2];
		if(_orientation & PGRotated90CC) {
			float const swap = r.size.width;
			r.size.width = r.size.height;
			r.size.height = swap;
			[orient rotateByDegrees:90];
		}
		[orient scaleXBy:(_orientation & PGFlippedHorz ? -1 : 1) yBy:(_orientation & PGFlippedVert ? -1 : 1)];
		[orient concat];
		r.origin.x = NSWidth(r) / -2;
		r.origin.y = NSHeight(r) / -2;
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
		_antialias = YES;
		_drawsRoundedCorners = YES;
		[NSApp AE_addObserver:self selector:@selector(appDidHide:) name:NSApplicationDidHideNotification];
		[NSApp AE_addObserver:self selector:@selector(appDidUnhide:) name:NSApplicationDidUnhideNotification];
	}
	return self;
}

- (BOOL)isOpaque
{
	return _isOpaque && ![self drawsRoundedCorners];
}
- (void)drawRect:(NSRect)aRect
{
	BOOL const drawCorners = !_cacheIsValid && [self drawsRoundedCorners];
	if(drawCorners) CGContextBeginTransparencyLayer([[NSGraphicsContext currentContext] graphicsPort], NULL);
	int count = 0;
	NSRect const *rects = NULL;
	if(_isPDF) {
		[self getRectsBeingDrawn:&rects count:&count];
		[[NSColor whiteColor] set];
		NSRectFillList(rects, count);
	}
	NSRect const b = [self bounds];
	if([self usesOptimizedDrawing]) {
		NSCompositingOperation const operation = !_isPDF && [self isOpaque] ? NSCompositeCopy : NSCompositeSourceOver;
		if(!rects) [self getRectsBeingDrawn:&rects count:&count]; // Be sure this gets read.
		float const horz = [_image size].width / b.size.width;
		float const vert = [_image size].height / b.size.height;
		int i = count;
		while(i--) {
			NSRect sourceRect = rects[i];
			if(NSIsEmptyRect(sourceRect)) continue;
			sourceRect.origin.x *= horz;
			sourceRect.origin.y *= vert;
			sourceRect.size.width *= horz;
			sourceRect.size.height *= vert;
			[_image drawInRect:rects[i] fromRect:sourceRect operation:operation fraction:1.0];
		}
	} else [self _drawInRect:b];
	if(drawCorners) {
		[self _drawCornersOnRect:b];
		CGContextEndTransparencyLayer([[NSGraphicsContext currentContext] graphicsPort]);
	}
}
- (void)setFrameSize:(NSSize)aSize
{
	if(NSEqualSizes(aSize, [self frame].size)) return;
	[super setFrameSize:aSize];
	[self _cache];
}
- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	if(_cheatedDuringLiveResize) [self _cache];
	_cheatedDuringLiveResize = NO;
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
