/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

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
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGGeometry.h"

#pragma mark PGRectEdgeMask

NSPoint PGRectEdgeMaskToPointWithMagnitude(PGRectEdgeMask mask, float magnitude)
{
	float const m = fabs(magnitude);
	NSCParameterAssert(!PGHasContradictoryRectEdges(mask));
	NSPoint location = NSZeroPoint;
	if(mask & PGMinXEdgeMask) location.x = -m;
	else if(mask & PGMaxXEdgeMask) location.x = m;
	if(mask & PGMinYEdgeMask) location.y = -m;
	else if(mask & PGMaxYEdgeMask) location.y = m;
	return location;
}
PGRectEdgeMask PGPointToRectEdgeMaskWithThreshhold(NSPoint p, float threshhold)
{
	float const t = fabs(threshhold);
	PGRectEdgeMask direction = PGNoEdges;
	if(p.x <= -t) direction |= PGMinXEdgeMask;
	else if(p.x >= t) direction |= PGMaxXEdgeMask;
	if(p.y <= -t) direction |= PGMinYEdgeMask;
	else if(p.y >= t) direction |= PGMaxYEdgeMask;
	return direction;
}
PGRectEdgeMask PGNonContradictoryRectEdges(PGRectEdgeMask mask)
{
	PGRectEdgeMask r = mask;
	if((r & PGHorzEdgesMask) == PGHorzEdgesMask) r &= ~PGHorzEdgesMask;
	if((r & PGVertEdgesMask) == PGVertEdgesMask) r &= ~PGVertEdgesMask;
	return r;
}
BOOL PGHasContradictoryRectEdges(PGRectEdgeMask mask)
{
	return PGNonContradictoryRectEdges(mask) != mask;
}

#pragma mark PGPageLocation

PGRectEdgeMask PGReadingDirectionAndLocationToRectEdgeMask(PGPageLocation loc, PGReadingDirection dir)
{
	BOOL const ltr = dir == PGReadingDirectionLeftToRight;
	if(PGHomeLocation == loc) return PGMaxYEdgeMask | (ltr ? PGMinXEdgeMask : PGMaxXEdgeMask);
	else return PGMinYEdgeMask | (ltr ? PGMaxXEdgeMask : PGMinXEdgeMask);
}

#pragma mark PGOrientation

PGOrientation PGAddOrientation(PGOrientation o1, PGOrientation o2)
{
	PGOrientation n1 = o1, n2 = o2;
	if(o1 & PGRotated90CC && !(o2 & PGRotated90CC)) n2 = ((o2 & PGFlippedHorz) >> 1) | ((o2 & PGFlippedVert) << 1);
	PGOrientation r = n1 ^ n2;
	if(o1 & PGRotated90CC && o2 & PGRotated90CC) r ^= PGUpsideDown;
	return r;
}

#pragma mark Other

NSTimeInterval PGUptime(void)
{
	return (NSTimeInterval)UnsignedWideToUInt64(AbsoluteToNanoseconds(UpTime())) * 1e-9;
}
float PGLagCounteractionSpeedup(NSTimeInterval *timeOfFrame, float desiredFramerate)
{
	NSCParameterAssert(timeOfFrame);
	NSTimeInterval const currentTime = PGUptime();
	float const speedup = *timeOfFrame ? desiredFramerate / (currentTime - *timeOfFrame) : 1;
	*timeOfFrame = currentTime;
	return speedup;
}
