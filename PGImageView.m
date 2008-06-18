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

// Categories
#import "NSObjectAdditions.h"

#define PGCacheOnSeparateThread false // Not as fast as I thought it would be.

@interface PGImageView (Private)

- (void)_animate:(BOOL)flag;
- (void)_animate; // Should only be called by -_animate:.
- (void)_cache;
#if PGCacheOnSeparateThread
- (void)_threaded_cache:(NSDictionary *)dict;
- (void)_useCache:(NSDictionary *)dict;
#endif

@end

@implementation PGImageView

#pragma mark NSObject

+ (void)initialize
{
	[self exposeBinding:@"animating"];
	[self exposeBinding:@"antialiasWhenUpscaling"];
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
	if(rep != _rep) {
		[_image removeRepresentation:_rep];
		[_image removeRepresentation:_cache];

		[_rep release];
		_rep = nil;
		[_cache release];
		_cache = nil;

		[self setFrameSize:size];

		_rep = [rep retain];
		[_image addRepresentation:_rep];

		_isOpaque = _rep && ![_rep hasAlpha];
		_isPDF = [_rep isKindOfClass:[NSPDFImageRep class]];
		_numberOfFrames = [_rep isKindOfClass:[NSBitmapImageRep class]] ? [[(NSBitmapImageRep *)_rep valueForProperty:NSImageFrameCount] unsignedIntValue] : 1;

		[self _cache];
		[self _animate:YES];
	} else [self setFrameSize:size];
	_orientation = orientation;
	[self setNeedsDisplay:YES];
}

#pragma mark -

- (BOOL)canAnimate
{
	return _numberOfFrames > 1;
}
- (BOOL)isAnimating
{
	return _animating;
}
- (void)setAnimating:(BOOL)flag
{
	if(flag == _animating) return;
	_animating = flag;
	[self _animate:YES]; // Stops the animation if _animating is NO (regardless of its argument).
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

- (void)appDidHide:(NSNotification *)aNotif
{
	[self _animate:NO];
}
- (void)appDidUnhide:(NSNotification *)aNotif
{
	[self _animate:YES];
}

#pragma mark Private Protocol

- (void)_animate:(BOOL)flag
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_animate) object:nil];
	if(flag && _animating && _numberOfFrames > 1) [self AE_performSelector:@selector(_animate) withObject:nil afterDelay:[[(NSBitmapImageRep *)_rep valueForProperty:NSImageCurrentFrameDuration] floatValue]];
}
- (void)_animate
{
	unsigned const i = [[(NSBitmapImageRep *)_rep valueForProperty:NSImageCurrentFrame] unsignedIntValue] + 1;
	[(NSBitmapImageRep *)_rep setProperty:NSImageCurrentFrame withValue:[NSNumber numberWithUnsignedInt:(i < _numberOfFrames ? i : 0)]];
	[self setNeedsDisplay:YES];
	[self _animate:YES];
}
- (void)_cache
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_cache) object:nil];
	if(!_rep || _numberOfFrames > 1 || _isPDF) return;
	[_image removeRepresentation:_cache];
	[_cache release];
	_cache = nil;
	[_image removeRepresentation:_rep];
	NSSize const pixelSize = NSMakeSize([_rep pixelsWide], [_rep pixelsHigh]);
	[_image setSize:pixelSize];
	[_image addRepresentation:_rep];
	if(_orientation & PGRotated90CC) return; // Caching doesn't help rotated images.
	NSSize const scaledSize = [self frame].size;
	if(scaledSize.width > pixelSize.width || scaledSize.height > pixelSize.height) return; // Only cache if the image is smaller than full size, because caching huge images takes FOREVER.
	if([self inLiveResize]) {
		_cheatedDuringLiveResize = YES;
		return; // Don't bother until we stop.
	}
	NSCachedImageRep *const cache = [[NSCachedImageRep alloc] initWithSize:scaledSize depth:[[self window] depthLimit] separate:YES alpha:!_isOpaque];
#if PGCacheOnSeparateThread
	[NSApplication detachDrawingThread:@selector(_threaded_cache:) toTarget:self withObject:[NSDictionary dictionaryWithObjectsAndKeys:
		[cache autorelease], @"Cache",
		_rep, @"Rep",
		[NSNumber numberWithUnsignedInt:[self interpolation]], @"Interpolation",
		nil]];
#else
	_cache = cache;
	NSView *const view = [[_cache window] contentView];
	if(![view lockFocusIfCanDraw]) return [self AE_performSelector:@selector(_cache) withObject:nil afterDelay:0];
	[[NSGraphicsContext currentContext] setImageInterpolation:[self interpolation]];
	[_rep drawInRect:[_cache rect]];
	[view unlockFocus];
	[_image removeRepresentation:_rep];
	[_image setSize:scaledSize];
	[_image addRepresentation:_cache];
#endif
}
#if PGCacheOnSeparateThread
- (void)_threaded_cache:(NSDictionary *)dict
{
	// We don't need an autorelease pool because we call this with -[NSApplication detachDrawingThread:toTarget:withObject:].
	NSCachedImageRep *const cache = [dict objectForKey:@"Cache"];
	NSImageRep *const rep = [dict objectForKey:@"Rep"];
	NSView *const view = [[cache window] contentView];
	if(![view lockFocusIfCanDraw]) return;
	[[NSGraphicsContext currentContext] setImageInterpolation:[[dict objectForKey:@"Interpolation"] unsignedIntValue]];
	[rep drawInRect:[cache rect]];
	[view unlockFocus];
	[self performSelectorOnMainThread:@selector(_useCache:) withObject:dict waitUntilDone:NO];
}
- (void)_useCache:(NSDictionary *)dict
{
	NSCachedImageRep *const cache = [dict objectForKey:@"Cache"];
	if([dict objectForKey:@"Rep"] != _rep || !NSEqualSizes([cache size], [self frame].size)) return; // Make sure we still care.
	[_cache release];
	_cache = [cache retain];
	[_image removeRepresentation:_rep];
	[_image setSize:[cache size]];
	[_image addRepresentation:cache];
}
#endif

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
		[NSApp AE_addObserver:self selector:@selector(appDidHide:) name:NSApplicationDidHideNotification];
		[NSApp AE_addObserver:self selector:@selector(appDidUnhide:) name:NSApplicationDidUnhideNotification];
	}
	return self;
}

- (BOOL)isOpaque
{
	return _isOpaque;
}
- (BOOL)wantsDefaultClipping
{
	return PGUpright != _orientation;
}
- (void)drawRect:(NSRect)aRect
{
	if(!_cache) [[NSGraphicsContext currentContext] setImageInterpolation:[self interpolation]]; // If we've cached, the interpolation has already been done.
	int count = 0;
	NSRect const *rects = NULL;
	if(_isPDF) {
		[self getRectsBeingDrawn:&rects count:&count];
		[[NSColor whiteColor] set];
		NSRectFillList(rects, count);
	}
	NSCompositingOperation const operation = _isOpaque && !_isPDF ? NSCompositeCopy : NSCompositeSourceOver;
	if(PGUpright == _orientation) {
		NSParameterAssert(![self wantsDefaultClipping]);
		if(!rects) [self getRectsBeingDrawn:&rects count:&count]; // Be sure this gets read.
		float const horz = [_image size].width / [self bounds].size.width;
		float const vert = [_image size].height / [self bounds].size.height;
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
	} else {
		NSParameterAssert([self wantsDefaultClipping]);
		NSRect bounds = [self bounds];
		NSAffineTransform *const orient = [[[NSAffineTransform alloc] init] autorelease];
		[orient translateXBy:NSMidX(bounds) yBy:NSMidY(bounds)];
		if(_orientation & PGRotated90CC) {
			float const swap = bounds.size.width;
			bounds.size.width = bounds.size.height;
			bounds.size.height = swap;
			[orient rotateByDegrees:90];
		}
		[orient scaleXBy:(_orientation & PGFlippedHorz ? -1 : 1) yBy:(_orientation & PGFlippedVert ? -1 : 1)];
		[orient concat];
		bounds.origin.x = NSWidth(bounds) / -2;
		bounds.origin.y = NSHeight(bounds) / -2;
		[_image drawInRect:bounds fromRect:NSZeroRect operation:operation fraction:1.0];
		[orient invert];
		[orient concat];
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

#pragma mark NSObject

- (id)init
{
	return [self initWithFrame:NSZeroRect];
}
- (void)dealloc
{
	[self AE_removeObserver];
	[self setImageRep:nil orientation:PGUpright size:NSZeroSize];
	NSParameterAssert(!_rep);
	NSParameterAssert(!_cache);
	[_image release];
	[self _animate:NO];
	[super dealloc];
}

@end
