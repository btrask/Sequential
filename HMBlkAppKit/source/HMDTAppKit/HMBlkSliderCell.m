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
#import "HMBlkSliderCell.h"
#import "HMBlkPanel.h"

@implementation HMBlkSliderCell

#pragma mark -NSSliderCell

- (void)drawWithFrame:(NSRect)aRect inView:(NSView *)aView
{
	BOOL const e = [self isEnabled];
	NSRect const f = NSOffsetRect(NSIntegralRect(NSInsetRect(aRect, NSHeight(aRect) / 2.0f - 1.5f, NSHeight(aRect) / 2.0f - 1.5f)), 0.5f, 0.5f);
	CGFloat const r = NSHeight(f) / 2.0f;
	NSBezierPath *const path = [NSBezierPath bezierPath];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(f) + r, NSMinY(f) + r) radius:r startAngle:90.0f endAngle:270.0f];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(f) - r, NSMinY(f) + r) radius:r startAngle:270.0f endAngle:90.0f];
	[path closePath];
	[[NSColor colorWithDeviceWhite:0.75f alpha:e ? 0.67f : 0.1f] set];
	[path fill];
	[[NSColor colorWithDeviceWhite:0.9f alpha:e ? 0.9f : 0.33f] set];
	[path stroke];
	[self drawInteriorWithFrame:aRect inView:aView];
}
- (void)drawKnob:(NSRect)knobRect
{
	[NSGraphicsContext saveGraphicsState];

	NSShadow *const shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowOffset:NSMakeSize(0.0f, -1.0f)];
	[shadow setShadowBlurRadius:2.0f];
	[shadow set];

	CGContextRef const context = [[NSGraphicsContext currentContext] graphicsPort];
	CGContextBeginTransparencyLayerWithRect(context, NSRectToCGRect(knobRect), NULL);
	BOOL const e = [self isEnabled];
	[[NSColor colorWithDeviceWhite:[self isHighlighted] ? 0.75f : 0.4f alpha:e ? 1.0f : 0.3f] set];
	NSBezierPath *const p = [NSBezierPath bezierPathWithOvalInRect:NSInsetRect(knobRect, 2.5f, 2.5f)];
	[p fill];
	[[NSColor colorWithDeviceWhite:1.0f alpha:e ? 0.9f : 0.27f] set];
	[p stroke];
	CGContextEndTransparencyLayer(context);

	[NSGraphicsContext restoreGraphicsState];

}

@end
