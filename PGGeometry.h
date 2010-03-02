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
#import "PGGeometryTypes.h"

#pragma mark NSPoint

extern NSPoint PGIntegralPoint(NSPoint aPoint);
extern NSPoint PGOffsetPointBySize(NSPoint aPoint, NSSize aSize);
extern NSPoint PGOffsetPointByXY(NSPoint aPoint, CGFloat x, CGFloat y);
extern NSSize PGPointDiff(NSPoint p1, NSPoint p2);

#pragma mark NSSize

extern NSSize PGScaleSizeByXY(NSSize size, CGFloat scaleX, CGFloat scaleY);
extern NSSize PGScaleSizeByFloat(NSSize size, CGFloat scale);
extern NSSize PGIntegralSize(NSSize s);

#pragma mark NSRect

extern NSRect PGCenteredSizeInRect(NSSize s, NSRect r);
extern BOOL PGIntersectsRectList(NSRect rect, NSRect const *list, NSUInteger count);
extern NSRect PGIntegralRect(NSRect r); // NSIntegralRect() expands the rectangle in all directions. It's better to round the origin and width separately.
extern void PGGetRectDifference(NSRect diff[4], NSUInteger *count, NSRect minuend, NSRect subtrahend);
extern NSRect PGScaleRect(NSRect r, CGFloat scaleX, CGFloat scaleY);

#pragma mark PGRectEdgeMask

extern NSSize PGRectEdgeMaskToSizeWithMagnitude(PGRectEdgeMask mask, CGFloat magnitude);
extern NSPoint PGRectEdgeMaskToPointWithMagnitude(PGRectEdgeMask mask, CGFloat magnitude);
extern NSPoint PGPointOfPartOfRect(NSRect r, PGRectEdgeMask mask);
extern PGRectEdgeMask PGPointToRectEdgeMaskWithThreshhold(NSPoint p, CGFloat threshhold);
extern PGRectEdgeMask PGNonContradictoryRectEdges(PGRectEdgeMask mask);
extern BOOL PGHasContradictoryRectEdges(PGRectEdgeMask mask);

#pragma mark PGPageLocation

extern PGRectEdgeMask PGReadingDirectionAndLocationToRectEdgeMask(PGPageLocation loc, PGReadingDirection dir);

#pragma mark PGOrientation

extern PGOrientation PGOrientationWithTIFFOrientation(NSUInteger orientation);
extern PGOrientation PGAddOrientation(PGOrientation o1, PGOrientation o2);
extern NSString *PGLocalizedStringWithOrientation(PGOrientation orientation);

#pragma mark PGInset

extern PGInset const PGZeroInset;

extern PGInset PGMakeInset(CGFloat minX, CGFloat minY, CGFloat maxX, CGFloat maxY);
extern PGInset PGScaleInset(PGInset i, CGFloat s);
extern PGInset PGInvertInset(PGInset inset);
extern NSPoint PGInsetPoint(NSPoint p, PGInset i);
extern NSSize PGInsetSize(NSSize s, PGInset i);
extern NSRect PGInsetRect(NSRect r, PGInset i);
extern PGInset PGAddInsets(PGInset a, PGInset b);

#pragma mark Animation

#define PGAnimationFramesPerSecond 30.0f
#define PGAnimationFramerate (1.0f / PGAnimationFramesPerSecond)

extern NSTimeInterval PGUptime(void);
extern CGFloat PGLagCounteractionSpeedup(NSTimeInterval *timeOfFrame, CGFloat desiredFramerate); // On input, timeOfFrame should be the PGUptime() from the last frame or 0. On return, it is the current PGUptime().
