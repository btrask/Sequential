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

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
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
