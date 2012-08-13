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

@interface PGImageView : NSView
{
	@private
	NSImageRep *_rep;
	PGOrientation _orientation;
	NSSize _size;
	NSSize _immediateSize;
	NSTimeInterval _lastSizeAnimationTime;
	NSTimer *_sizeTransitionTimer;
	CGFloat _rotationInDegrees;
	BOOL _antialiasWhenUpscaling;
	BOOL _usesRoundedCorners;
	BOOL _usesCaching;

	BOOL _animates;
	NSUInteger _pauseCount;

	NSImage *_image;
	BOOL _isPDF;
	NSUInteger _numberOfFrames;
	CGLayerRef _cacheLayer;
	BOOL _awaitingUpdate;
}

+ (NSArray *)pasteboardTypes;

@property(readonly) NSImageRep *rep;
@property(readonly) PGOrientation orientation;
@property(readonly) NSSize size;
@property(readonly) NSSize originalSize;
@property(readonly) CGFloat averageScaleFactor;
@property(assign, nonatomic) CGFloat rotationInDegrees;
@property(assign, nonatomic) BOOL antialiasWhenUpscaling;
@property(readonly) NSImageInterpolation interpolation;
@property(assign, nonatomic) BOOL usesRoundedCorners;
@property(assign, nonatomic) BOOL usesCaching;

@property(readonly) BOOL canAnimateRep;
@property(assign, nonatomic) BOOL animates;
@property(assign, nonatomic, getter = isPaused) BOOL paused;

- (void)setImageRep:(NSImageRep *)rep orientation:(PGOrientation)orientation size:(NSSize)size;
- (void)setSize:(NSSize)size allowAnimation:(BOOL)flag; // Use this function to control how big the image is displayed. PGImageView manages its own frame size.
- (void)stopAnimatedSizeTransition;
- (NSPoint)rotateByDegrees:(CGFloat)val adjustingPoint:(NSPoint)aPoint;

- (BOOL)writeToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;

- (void)appDidHide:(NSNotification *)aNotif;
- (void)appDidUnhide:(NSNotification *)aNotif;

@end
