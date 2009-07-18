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
#import <Cocoa/Cocoa.h>

// Other
#import "PGGeometryTypes.h"

@interface PGImageView : NSView
{
	@private
	NSImage          *_image;
	NSImageRep       *_rep;
	BOOL              _isPDF;
	PGOrientation     _orientation;
	unsigned          _numberOfFrames;

	NSSize            _size;
	NSSize            _immediateSize;
	NSTimeInterval    _lastSizeAnimationTime;
	NSTimer          *_sizeTransitionTimer;

	NSCachedImageRep *_cache;
	BOOL              _usesCaching;
	BOOL              _cached;

	float             _rotationInDegrees;
	BOOL              _animates;
	unsigned          _pauseCount;
	BOOL              _antialias;
	BOOL              _drawsRoundedCorners;
}

+ (NSArray *)pasteboardTypes;

- (NSImageRep *)rep;
- (PGOrientation)orientation;
- (void)setImageRep:(NSImageRep *)rep orientation:(PGOrientation)orientation size:(NSSize)size;

- (NSSize)size; // Use this function to control how big the image is displayed. PGImageView manages its own frame size.
- (void)setSize:(NSSize)size allowAnimation:(BOOL)flag;
- (void)stopAnimatedSizeTransition;
- (NSSize)originalSize;
- (float)averageScaleFactor;

- (BOOL)usesCaching;
- (void)setUsesCaching:(BOOL)flag;

- (float)rotationInDegrees;
- (void)setRotationInDegrees:(float)val;
- (NSPoint)rotateByDegrees:(float)val adjustingPoint:(NSPoint)aPoint;

- (BOOL)canAnimateRep;
- (BOOL)animates;
- (void)setAnimates:(BOOL)flag;
- (void)pauseAnimation;
- (void)resumeAnimation;

- (BOOL)antialiasWhenUpscaling;
- (void)setAntialiasWhenUpscaling:(BOOL)flag;
- (NSImageInterpolation)interpolation; // The image interpolation to use.

- (BOOL)drawsRoundedCorners;
- (void)setDrawsRoundedCorners:(BOOL)flag;

- (BOOL)writeToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;

- (void)appDidHide:(NSNotification *)aNotif;
- (void)appDidUnhide:(NSNotification *)aNotif;

@end
