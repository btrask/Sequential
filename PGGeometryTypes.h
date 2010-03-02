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
typedef NSUInteger PGRectEdgeMask;

enum {
	PGReadingDirectionLeftToRight = 0,
	PGReadingDirectionRightToLeft = 1
};
typedef NSInteger PGReadingDirection;

enum {
	PGPreserveLocation = -1,
	PGHomeLocation = 0,
	PGEndLocation = 1,
	PGEndTopLocation = 2
};
typedef NSInteger PGPageLocation;

enum {
	PGUpright      = 0,
	PGFlippedVert  = 1 << 0,
	PGFlippedHorz  = 1 << 1,
	PGRotated90CCW  = 1 << 2, // Counter-Clockwise.
	PGUpsideDown   = PGFlippedVert | PGFlippedHorz,
	PGRotated90CW = PGFlippedVert | PGFlippedHorz | PGRotated90CCW
};
typedef NSUInteger PGOrientation;

typedef struct {
	CGFloat minX;
	CGFloat minY;
	CGFloat maxX;
	CGFloat maxY;
} PGInset;

enum {
	PGMinXMinYCorner = 0,
	PGMaxXMinYCorner = 1,
	PGMinXMaxYCorner = 2,
	PGMaxXMaxYCorner = 3
};
typedef NSUInteger PGRectCorner;
