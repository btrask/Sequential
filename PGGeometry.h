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

#pragma mark PGRectEdgeMask

enum {
	PGNoEdges       = 0,
	PGMinXEdgeMask  = 1 << NSMinXEdge,
	PGMinYEdgeMask  = 1 << NSMinYEdge,
	PGMaxXEdgeMask  = 1 << NSMaxXEdge,
	PGMaxYEdgeMask  = 1 << NSMaxYEdge,
	PGHorzEdgesMask = PGMinXEdgeMask | PGMaxXEdgeMask,
	PGVertEdgesMask = PGMinYEdgeMask | PGMaxYEdgeMask,
	PGMinEdgesMask  = PGMinXEdgeMask | PGMinYEdgeMask,
	PGMaxEdgesMask  = PGMaxXEdgeMask | PGMaxYEdgeMask
};
typedef unsigned PGRectEdgeMask;

NSPoint PGRectEdgeMaskToPointWithMagnitude(PGRectEdgeMask mask, float magnitude);
PGRectEdgeMask PGPointToRectEdgeMaskWithThreshhold(NSPoint p, float threshhold);
extern PGRectEdgeMask PGNonContradictoryRectEdges(PGRectEdgeMask mask);
extern BOOL PGHasContradictoryRectEdges(PGRectEdgeMask mask);

#pragma mark PGReadingDirection

enum {
	PGReadingDirectionLeftToRight = 0,
	PGReadingDirectionRightToLeft = 1
};
typedef int PGReadingDirection;

#pragma mark PGPageLocation

enum {
	PGHomeLocation = 0,
	PGEndLocation  = 1
};
typedef int PGPageLocation;

PGRectEdgeMask PGReadingDirectionAndLocationToRectEdgeMask(PGPageLocation loc, PGReadingDirection dir);

#pragma mark PGOrientation

enum {
	PGUpright      = 0,
	PGFlippedVert  = 1 << 0,
	PGFlippedHorz  = 1 << 1,
	PGRotated90CC  = 1 << 2, // Counter-Clockwise.
	PGUpsideDown   = PGFlippedVert | PGFlippedHorz,
	PGRotated270CC = PGFlippedVert | PGFlippedHorz | PGRotated90CC
};
typedef unsigned PGOrientation;

PGOrientation PGAddOrientation(PGOrientation o1, PGOrientation o2);
