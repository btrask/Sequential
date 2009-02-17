/* Copyright © 2007-2008, The Sequential Project
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

enum {
	PGReadingDirectionLeftToRight = 0,
	PGReadingDirectionRightToLeft = 1
};
typedef int PGReadingDirection;

enum {
	PGHomeLocation = 0,
	PGEndLocation  = 1
};
typedef int PGPageLocation;

enum {
	PGUpright      = 0,
	PGFlippedVert  = 1 << 0,
	PGFlippedHorz  = 1 << 1,
	PGRotated90CC  = 1 << 2, // Counter-Clockwise.
	PGUpsideDown   = PGFlippedVert | PGFlippedHorz,
	PGRotated270CC = PGFlippedVert | PGFlippedHorz | PGRotated90CC
};
typedef unsigned PGOrientation;

typedef struct {
	float minX;
	float minY;
	float maxX;
	float maxY;
} PGInset;
