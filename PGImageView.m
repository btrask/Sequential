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
#import "PGImageView.h"
#import <tgmath.h>

// Views
@class PGClipView;

// Other
#import "PGDebug.h"
#import "PGGeometry.h"
#import "PGDelayedPerforming.h"

// Categories
#import "PGFoundationAdditions.h"

#define PGAnimateSizeChanges true
#define PGDebugDrawingModes false

static NSImage *PGRoundedCornerImages[4];
static NSSize PGRoundedCornerSizes[4];

@interface PGImageView(Private)

@property(readonly) BOOL _imageIsOpaque;
- (void)_runAnimationTimer;
- (void)_animate;
- (void)_invalidateCache;
- (void)_cache;
- (void)_drawImageWithFrame:(NSRect)aRect compositeCopy:(BOOL)compositeCopy rects:(NSRect const *)rects count:(NSUInteger)count;
@property(readonly) BOOL _shouldDrawRoundedCorners;
- (BOOL)_needsToDrawRoundedCornersForImageRect:(NSRect)r rects:(NSRect const *)rects count:(NSUInteger)count;
- (void)_getRoundedCornerRects:(NSRectArray)rects forRect:(NSRect)r;
- (NSAffineTransform *)_transformWithRotationInDegrees:(CGFloat)val;
- (BOOL)_setSize:(NSSize)size;
- (void)_sizeTransitionOneFrame;
- (void)_updateFrameSize;
- (void)_update;

@end

@implementation PGImageView

#pragma mark +PGImageView

+ (NSArray *)pasteboardTypes
{
	return [NSArray arrayWithObjects:NSTIFFPboardType, nil];
}

#pragma mark +NSObject

+ (void)initialize
{
	if([PGImageView class] != self) return;
	[self exposeBinding:@"animates"];
	[self exposeBinding:@"antialiasWhenUpscaling"];
	[self exposeBinding:@"usesRoundedCorners"];

	PGRoundedCornerImages[PGMinXMinYCorner] = [[NSImage imageNamed:@"Corner-Bottom-Left"] retain];
	PGRoundedCornerImages[PGMaxXMinYCorner] = [[NSImage imageNamed:@"Corner-Bottom-Right"] retain];
	PGRoundedCornerImages[PGMinXMaxYCorner] = [[NSImage imageNamed:@"Corner-Top-Left"] retain];
	PGRoundedCornerImages[PGMaxXMaxYCorner] = [[NSImage imageNamed:@"Corner-Top-Right"] retain];
	PGRoundedCornerSizes[PGMinXMinYCorner] = [PGRoundedCornerImages[PGMinXMinYCorner] size];
	PGRoundedCornerSizes[PGMaxXMinYCorner] = [PGRoundedCornerImages[PGMaxXMinYCorner] size];
	PGRoundedCornerSizes[PGMinXMaxYCorner] = [PGRoundedCornerImages[PGMinXMaxYCorner] size];
	PGRoundedCornerSizes[PGMaxXMaxYCorner] = [PGRoundedCornerImages[PGMaxXMaxYCorner] size];
}

#pragma mark -PGImageView

@synthesize rep = _rep;
@synthesize orientation = _orientation;
- (NSSize)size
{
	return _sizeTransitionTimer ? _size : _immediateSize;
}
- (NSSize)originalSize
{
	return PGRotated90CC & _orientation ? NSMakeSize([_rep pixelsHigh], [_rep pixelsWide]) : NSMakeSize([_rep pixelsWide], [_rep pixelsHigh]);
}
- (CGFloat)averageScaleFactor
{
	NSSize const s = [self size];
	NSSize const o = [self originalSize];
	return (s.width / o.width + s.height / o.height) / 2.0f;
}
@synthesize rotationInDegrees = _rotationInDegrees;
- (void)setRotationInDegrees:(CGFloat)val
{
	if(val == _rotationInDegrees) return;
	_rotationInDegrees = remainderf(val, 360.0f);
	[self _updateFrameSize];
	[self setNeedsDisplay:YES];
}
@synthesize antialiasWhenUpscaling = _antialiasWhenUpscaling;
- (void)setAntialiasWhenUpscaling:(BOOL)flag
{
	if(flag == _antialiasWhenUpscaling) return;
	_antialiasWhenUpscaling = flag;
	[self _invalidateCache];
	[self setNeedsDisplay:YES];
}
- (NSImageInterpolation)interpolation
{
	if(_sizeTransitionTimer || [self inLiveResize] || ([self canAnimateRep] && [self animates])) return NSImageInterpolationNone;
	if([self antialiasWhenUpscaling]) return NSImageInterpolationHigh;
	NSSize const imageSize = NSMakeSize([_rep pixelsWide], [_rep pixelsHigh]), viewSize = [self size];
	return imageSize.width < viewSize.width && imageSize.height < viewSize.height ? NSImageInterpolationNone : NSImageInterpolationHigh;
}
@synthesize usesRoundedCorners = _usesRoundedCorners;
- (void)setUsesRoundedCorners:(BOOL)flag
{
	if(flag == _usesRoundedCorners) return;
	_usesRoundedCorners = flag;
	[self _invalidateCache];
	[self setNeedsDisplay:YES];
}
@synthesize usesCaching = _usesCaching;
- (void)setUsesCaching:(BOOL)flag
{
	if(flag == _usesCaching) return;
	_usesCaching = flag;
	if(flag) [self setNeedsDisplay:YES];
	else [self _invalidateCache];
}

#pragma mark -

- (BOOL)canAnimateRep
{
	return _numberOfFrames > 1;
}
@synthesize animates = _animates;
- (void)setAnimates:(BOOL)flag
{
	if(flag == _animates) return;
	_animates = flag;
	if(!flag && [self antialiasWhenUpscaling]) [self setNeedsDisplay:YES];
	[self _runAnimationTimer];
}
- (BOOL)isPaused
{
	return !_pauseCount;
}
- (void)setPaused:(BOOL)flag
{
	if(flag) ++_pauseCount;
	else {
		NSParameterAssert(_pauseCount);
		--_pauseCount;
	}
	[self _runAnimationTimer];
}

#pragma mark -

- (void)setImageRep:(NSImageRep *)rep orientation:(PGOrientation)orientation size:(NSSize)size
{
	[self _invalidateCache];
	[self setNeedsDisplay:YES];
	if(orientation == _orientation && rep == _rep && !_sizeTransitionTimer && NSEqualSizes(size, _immediateSize)) return;
	_orientation = orientation;
	if(rep != _rep) {
		[_image removeRepresentation:_rep];
		[_rep release];
		_rep = nil;
		[self setSize:size allowAnimation:NO];
		_rep = [rep retain];
		[_image setSize:NSMakeSize([_rep pixelsWide], [_rep pixelsHigh])];
		[_image addRepresentation:_rep];

		_isPDF = [_rep isKindOfClass:[NSPDFImageRep class]];
		_numberOfFrames = [_rep isKindOfClass:[NSBitmapImageRep class]] ? [[(NSBitmapImageRep *)_rep valueForProperty:NSImageFrameCount] unsignedIntegerValue] : 1;

		[self _runAnimationTimer];
	} else [self setSize:size allowAnimation:NO];
}
- (void)setSize:(NSSize)size allowAnimation:(BOOL)flag
{
	if(!PGAnimateSizeChanges || !flag) {
		_size = size;
		return [self stopAnimatedSizeTransition];
	}
	if(NSEqualSizes(size, [self size])) return;
	_size = size;
	if(!_sizeTransitionTimer) _sizeTransitionTimer = [[self PG_performSelector:@selector(_sizeTransitionOneFrame) withObject:nil fireDate:nil interval:PGAnimationFramerate options:kNilOptions] retain];
}
- (void)stopAnimatedSizeTransition
{
	[_sizeTransitionTimer invalidate];
	[_sizeTransitionTimer release];
	_sizeTransitionTimer = nil;
	_lastSizeAnimationTime = 0.0f;
	[self _setSize:_size];
	[self setNeedsDisplay:YES];
}
- (NSPoint)rotateByDegrees:(CGFloat)val adjustingPoint:(NSPoint)aPoint
{
	NSRect const b1 = [self bounds];
	NSPoint const p = PGOffsetPointByXY(aPoint, -NSMidX(b1), -NSMidY(b1)); // Our bounds are going to change to fit the rotated image. Any point we want to remain constant relative to the image, we have to make relative to the bounds' center, since that's where the image is drawn.
	[self setRotationInDegrees:[self rotationInDegrees] + val];
	NSRect const b2 = [self bounds];
	return [[self _transformWithRotationInDegrees:val] transformPoint:PGOffsetPointByXY(p, NSMidX(b2), NSMidY(b2))];
}

#pragma mark -

- (BOOL)writeToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
	if(![types containsObject:NSTIFFPboardType]) return NO;
	if(!_rep || ![_rep respondsToSelector:@selector(TIFFRepresentation)]) return NO;
	if(pboard) {
		[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
		[pboard setData:[(NSBitmapImageRep *)_rep TIFFRepresentation] forType:NSTIFFPboardType];
	}
	return YES;
}

#pragma mark -

- (void)appDidHide:(NSNotification *)aNotif
{
	self.paused = YES;
}
- (void)appDidUnhide:(NSNotification *)aNotif
{
	self.paused = NO;
}

#pragma mark -PGImageView(Private)

- (BOOL)_imageIsOpaque
{
	return (_isPDF && _cacheLayer) || [_rep isOpaque];
}
- (void)_runAnimationTimer
{
	[self PG_cancelPreviousPerformRequestsWithSelector:@selector(_animate) object:nil];
	if([self canAnimateRep] && _animates && !_pauseCount) [self PG_performSelector:@selector(_animate) withObject:nil fireDate:nil interval:-[[(NSBitmapImageRep *)_rep valueForProperty:NSImageCurrentFrameDuration] doubleValue] options:kNilOptions];
}
- (void)_animate
{
	NSUInteger const i = [[(NSBitmapImageRep *)_rep valueForProperty:NSImageCurrentFrame] unsignedIntegerValue] + 1;
	[(NSBitmapImageRep *)_rep setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithUnsignedInteger:i % _numberOfFrames]];
	[self setNeedsDisplay:YES];
	[self _runAnimationTimer];
}
- (void)_invalidateCache
{
	CGLayerRelease(_cacheLayer);
	_cacheLayer = NULL;
}
- (void)_cache
{
	if(_cacheLayer || !_rep || ([self canAnimateRep] && [self animates]) || ![self usesCaching] || [self inLiveResize] || _sizeTransitionTimer) return;
	NSString *const runLoopMode = [[NSRunLoop currentRunLoop] currentMode];
	if(!runLoopMode || [NSEventTrackingRunLoopMode isEqualToString:runLoopMode]) {
		if(!_awaitingUpdate) [self performSelector:@selector(_update) withObject:nil afterDelay:0.0f inModes:[NSArray arrayWithObject:NSDefaultRunLoopMode]];
		_awaitingUpdate = YES;
		return;
	}
	CGContextRef const context = [[[self window] graphicsContext] graphicsPort];
	NSParameterAssert(context);
	CGLayerRef const layer = CGLayerCreateWithContext(context, NSSizeToCGSize(_immediateSize), NULL);
	NSGraphicsContext *const oldGraphicsContext = [NSGraphicsContext currentContext];
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:CGLayerGetContext(layer) flipped:[self isFlipped]]];
	NSRect const b = (NSRect){NSZeroPoint, _immediateSize};
	[self _drawImageWithFrame:b compositeCopy:YES rects:NULL count:0];
	[NSGraphicsContext setCurrentContext:oldGraphicsContext];
	_cacheLayer = layer;
}
- (void)_drawImageWithFrame:(NSRect)aRect compositeCopy:(BOOL)compositeCopy rects:(NSRect const *)rects count:(NSUInteger)count
{
	BOOL const roundedCorners = [self _needsToDrawRoundedCornersForImageRect:aRect rects:rects count:count];
	BOOL const useTransparencyLayer = roundedCorners && !compositeCopy;
	CGContextRef const context = [[NSGraphicsContext currentContext] graphicsPort];
	if(useTransparencyLayer) CGContextBeginTransparencyLayer(context, NULL);

	if(_isPDF) {
		[[NSColor whiteColor] set];
		if(rects) NSRectFillList(rects, count);
		else NSRectFill(aRect);
	}
	NSSize const actualSize = NSMakeSize([_rep pixelsWide], [_rep pixelsHigh]);
	NSSize const s = NSMakeSize(actualSize.width / _immediateSize.width, actualSize.height / _immediateSize.height);
	BOOL const isActualSize = NSEqualSizes(actualSize, _immediateSize);
	if(!isActualSize) {
		[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setImageInterpolation:[self interpolation]];
	}

	NSRect r = aRect;
	NSAffineTransform *transform = nil;
	if(PGUpright != _orientation) {
		transform = [NSAffineTransform PG_transformWithRect:&r orientation:_orientation];
		[transform concat];
	}
	NSCompositingOperation const op = !_isPDF && (compositeCopy || [_rep isOpaque]) ? NSCompositeCopy : NSCompositeSourceOver;
	if(rects && PGUpright == _orientation) {
		NSInteger i = count;
		while(i--) [_image drawInRect:rects[i] fromRect:NSMakeRect(NSMinX(rects[i]) * s.width, NSMinY(rects[i]) * s.height, NSWidth(rects[i]) * s.width, NSHeight(rects[i]) * s.height) operation:op fraction:1.0f];
	} else [_image drawInRect:r fromRect:NSZeroRect operation:op fraction:1.0f];
	if(roundedCorners) {
		NSUInteger i;
		NSRect corners[4];
		[self _getRoundedCornerRects:corners forRect:r];
		for(i = 0; i < 4; i++) [PGRoundedCornerImages[i] drawAtPoint:corners[i].origin fromRect:NSZeroRect operation:NSCompositeDestinationOut fraction:1];
	}

	if(!isActualSize) [NSGraphicsContext restoreGraphicsState];
	else if(transform) {
		[transform invert];
		[transform concat];
	}

	if(useTransparencyLayer) CGContextEndTransparencyLayer(context);
}
- (BOOL)_shouldDrawRoundedCorners
{
	return _usesRoundedCorners && _immediateSize.width >= 16.0f && _immediateSize.height >= 16.0f;
}
- (BOOL)_needsToDrawRoundedCornersForImageRect:(NSRect)r rects:(NSRect const *)rects count:(NSUInteger)count
{
	if(!self._shouldDrawRoundedCorners) return NO;
	if(!rects) return YES;
	NSRect corners[4];
	[self _getRoundedCornerRects:corners forRect:r];
	NSUInteger i, j;
	for(i = 0; i < count; i++) for(j = 0; j < 4; j++) if(NSIntersectsRect(rects[i], corners[j])) return YES;
	return NO;
}
- (void)_getRoundedCornerRects:(NSRectArray)rects forRect:(NSRect)r
{
	NSParameterAssert(rects);
	rects[PGMinXMinYCorner] = NSMakeRect(NSMinX(r), NSMinY(r), PGRoundedCornerSizes[PGMinXMinYCorner].width, PGRoundedCornerSizes[PGMinXMinYCorner].height);
	rects[PGMaxXMinYCorner] = NSMakeRect(NSMaxX(r) - PGRoundedCornerSizes[PGMaxXMinYCorner].width, NSMinY(r), PGRoundedCornerSizes[PGMaxXMinYCorner].width, PGRoundedCornerSizes[PGMaxXMinYCorner].height);
	rects[PGMinXMaxYCorner] = NSMakeRect(NSMinX(r), NSMaxY(r) - PGRoundedCornerSizes[PGMinXMaxYCorner].height, PGRoundedCornerSizes[PGMinXMaxYCorner].width, PGRoundedCornerSizes[PGMinXMaxYCorner].height);
	rects[PGMaxXMaxYCorner] = NSMakeRect(NSMaxX(r) - PGRoundedCornerSizes[PGMaxXMaxYCorner].width, NSMaxY(r) - PGRoundedCornerSizes[PGMaxXMaxYCorner].height, PGRoundedCornerSizes[PGMaxXMaxYCorner].width, PGRoundedCornerSizes[PGMaxXMaxYCorner].height);
}
- (NSAffineTransform *)_transformWithRotationInDegrees:(CGFloat)val
{
	NSRect const b = [self bounds];
	NSAffineTransform *const t = [NSAffineTransform transform];
	[t translateXBy:NSMidX(b) yBy:NSMidY(b)];
	[t rotateByDegrees:val];
	[t translateXBy:-NSMidX(b) yBy:-NSMidY(b)];
	return t;
}
- (BOOL)_setSize:(NSSize)size
{
	if(NSEqualSizes(size, _immediateSize)) return NO;
	_immediateSize = size;
	[self _updateFrameSize];
	return YES;
}
- (void)_sizeTransitionOneFrame
{
	NSSize const r = NSMakeSize(_size.width - _immediateSize.width, _size.height - _immediateSize.height);
	CGFloat const dist = hypotf(r.width, r.height);
	CGFloat const factor = MIN(1.0f, MAX(0.33f, 20.0f / dist) * PGLagCounteractionSpeedup(&_lastSizeAnimationTime, PGAnimationFramerate));
	if(dist < 1.0f || ![self _setSize:NSMakeSize(_immediateSize.width + r.width * factor, _immediateSize.height + r.height * factor)]) [self stopAnimatedSizeTransition];
}
- (void)_updateFrameSize
{
	NSSize s = _immediateSize;
	CGFloat const r = [self rotationInDegrees] / 180.0f * (CGFloat)pi;
	if(r) s = NSMakeSize(ceil(fabs(cosf(r)) * s.width + fabs(sinf(r)) * s.height), ceil(fabs(cosf(r)) * s.height + fabs(sinf(r)) * s.width));
	if(NSEqualSizes(s, [self frame].size)) return;
	[super setFrameSize:s];
	[self _invalidateCache];
}
- (void)_update
{
	_awaitingUpdate = NO;
	[self setNeedsDisplay:YES];
}

#pragma mark -NSView

- (id)initWithFrame:(NSRect)aRect
{
	if((self = [super initWithFrame:aRect])) {
		_image = [[NSImage alloc] init];
		[_image setCacheMode:NSImageCacheNever]; // We do our own caching.
		_usesCaching = YES;
		_antialiasWhenUpscaling = YES;
		_usesRoundedCorners = YES;
		[NSApp PG_addObserver:self selector:@selector(appDidHide:) name:NSApplicationDidHideNotification];
		[NSApp PG_addObserver:self selector:@selector(appDidUnhide:) name:NSApplicationDidUnhideNotification];
	}
	return self;
}

- (BOOL)wantsDefaultClipping
{
	return !!_cacheLayer;
}
- (BOOL)isOpaque
{
	return self._imageIsOpaque && !self._shouldDrawRoundedCorners && ![self rotationInDegrees];
}
- (void)drawRect:(NSRect)aRect
{
	if(!_rep) return;
	NSRect b = (NSRect){NSZeroPoint, _immediateSize};
	b.origin.x = round(NSMidX([self bounds]) - NSWidth(b) / 2);
	b.origin.y = round(NSMidY([self bounds]) - NSHeight(b) / 2);
	CGFloat const deg = [self rotationInDegrees];
	if(deg) {
		[NSGraphicsContext saveGraphicsState];
		[[self _transformWithRotationInDegrees:deg] concat];
	}
	[self _cache];
	if(_cacheLayer) CGContextDrawLayerAtPoint([[NSGraphicsContext currentContext] graphicsPort], NSPointToCGPoint(b.origin), _cacheLayer);
	else {
		NSInteger count = 0;
		NSRect const *rects = NULL;
		if(!deg) [self getRectsBeingDrawn:&rects count:&count];
		[self _drawImageWithFrame:b compositeCopy:NO rects:rects count:count];
	}
#if PGDebugDrawingModes
	[(_cacheLayer ? [NSColor redColor] : [NSColor blueColor]) set];
	NSFrameRect(b); // Outer frame: Cached
	[([self isOpaque] ? [NSColor redColor] : [NSColor blueColor]) set];
	NSFrameRect(NSInsetRect(b, 2, 2)); // Middle frame 1: View opaque
	[([self _imageIsOpaque] ? [NSColor redColor] : [NSColor blueColor]) set];
	NSFrameRect(NSInsetRect(b, 4, 4)); // Middle frame 2: Image opaque
	[(deg ? [NSColor blueColor] : [NSColor redColor]) set];
	NSFrameRect(NSInsetRect(b, 6, 6)); // Inner frame: Rotated
#endif
	if(deg) [NSGraphicsContext restoreGraphicsState];
}
- (void)setFrameSize:(NSSize)aSize
{
	PGAssertNotReached(@"-[PGImageView setFrameSize:] should not be invoked directly. Use -setSize: instead.");
}
- (void)viewWillStartLiveResize
{
	[super viewWillStartLiveResize];
	[self _invalidateCache];
}
- (void)viewDidEndLiveResize
{
	[super viewDidEndLiveResize];
	[self setNeedsDisplay:YES];
}
- (void)viewWillMoveToWindow:(NSWindow *)aWindow
{
	[super viewWillMoveToWindow:aWindow];
	[self _invalidateCache];
}

#pragma mark -NSView(PGClipViewAdditions)

- (BOOL)PG_acceptsClicksInClipView:(PGClipView *)sender
{
	return NO;
}
- (BOOL)PG_scalesContentWithFrameSizeInClipView:(PGClipView *)sender
{
	return YES;
}

#pragma mark -NSObject

- (id)init
{
	return [self initWithFrame:NSZeroRect];
}
- (void)dealloc
{
	[self PG_cancelPreviousPerformRequests];
	[self PG_removeObserver];
	[self stopAnimatedSizeTransition];
	[self unbind:@"animates"];
	[self unbind:@"antialiasWhenUpscaling"];
	[self unbind:@"usesRoundedCorners"];
	[self setImageRep:nil orientation:PGUpright size:NSZeroSize];
	NSParameterAssert(!_rep);
	[self _invalidateCache];
	[self setAnimates:NO];
	[_image release];
	[super dealloc];
}

@end
