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
#import "HMBlkSliderCell.h"
#import "HMBlkPanel.h"

@implementation HMBlkSliderCell

#pragma mark NSSliderCell

- (void)drawWithFrame:(NSRect)aRect
        inView:(NSView *)aView
{
	BOOL const e = [self isEnabled];
	NSRect const f = NSInsetRect(aRect, NSHeight(aRect) / 2 - 2, NSHeight(aRect) / 2 - 2);
	float const r = NSHeight(f) / 2;
	NSBezierPath *const path = [NSBezierPath bezierPath];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(f) + r, NSMinY(f) + r) radius:r startAngle:90 endAngle:270];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(f) - r, NSMinY(f) + r) radius:r startAngle:270 endAngle:90];
	[path closePath];
	[[NSColor colorWithDeviceWhite:0.9 alpha:(e ? 0.3 : 0.1)] set];
	[path fill];
	[[[HMBlkPanel majorGridColor] colorWithAlphaComponent:(e ? 1.0 : 0.33)] set];
	[path stroke];
	[self drawInteriorWithFrame:aRect inView:aView];
}
- (void)drawKnob:(NSRect)knobRect
{
	BOOL const e = [self isEnabled];
	[NSGraphicsContext saveGraphicsState];
	NSShadow *const shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowOffset:NSMakeSize(0, -2)];
	[shadow setShadowBlurRadius:2];
	[shadow setShadowColor:[NSColor colorWithDeviceWhite:0 alpha:(e ? 1.0 : 0.33)]];
	[shadow set];
	[[NSColor colorWithDeviceWhite:0.2 alpha:(e ? 0.9 : 0.3)] set];
	[[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(knobRect, 4, 4)] fill];
	[NSGraphicsContext restoreGraphicsState];
	[[NSColor colorWithDeviceWhite:1 alpha:(e ? 0.8 : 0.27)] set];
	[[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(knobRect, 3.5, 3.5)] stroke];
}

@end
