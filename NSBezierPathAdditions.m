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
#import "NSBezierPathAdditions.h"

// Categories
#import "NSColorAdditions.h"

@implementation NSBezierPath (AEAdditions)

#pragma mark Class Methods

+ (NSBezierPath *)AE_bezierPathWithRoundRect:(NSRect)aRect
                  cornerRadius:(CGFloat)radius
{
	NSBezierPath *const path = [self bezierPath];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(aRect) - radius, NSMaxY(aRect) - radius) radius:radius startAngle:0.0f endAngle:90.0f];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(aRect) + radius, NSMaxY(aRect) - radius) radius:radius startAngle:90.0f endAngle:180.0f];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(aRect) + radius, NSMinY(aRect) + radius) radius:radius startAngle:180.0f endAngle:270.0f];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(aRect) - radius, NSMinY(aRect) + radius) radius:radius startAngle:270.0f endAngle:0.0f];
	[path closePath];
	return path;
}
+ (void)AE_drawIcon:(AEIconType)type
        inRect:(NSRect)b
{
	NSBezierPath *const p = [self bezierPath];
	CGFloat const scale = MIN(NSWidth(b), NSHeight(b));
	switch(type) {
		case AEPlayIcon:
		{
			CGFloat const r = scale / 10.0f;
			[p appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(b) - r, NSMidY(b)) radius:r startAngle:60.0f endAngle:-60.0f clockwise:YES];
			[p appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(b) + NSWidth(b) * 0.1f + r, NSMinY(b) + NSHeight(b) * 0.05f + r * 1.0f) radius:r startAngle:-60.0f endAngle:180.0f clockwise:YES];
			[p appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(b) + NSWidth(b) * 0.1f + r, NSMinY(b) + NSHeight(b) * 0.95f - r * 1.0f) radius:r startAngle:180.0f endAngle:60.0f clockwise:YES];
			[p fill];
			break;
		}
		case AEPauseIcon:
			[p setLineWidth:scale / 4.0f];
			[p setLineCapStyle:NSRoundLineCapStyle];
			[p moveToPoint:NSMakePoint(NSMinX(b) + NSWidth(b) * 0.25f, NSMinY(b) + NSHeight(b) * 0.85f)];
			[p lineToPoint:NSMakePoint(NSMinX(b) + NSWidth(b) * 0.25f, NSMinY(b) + NSHeight(b) * 0.15f)];
			[p moveToPoint:NSMakePoint(NSMinX(b) + NSWidth(b) * 0.75f, NSMinY(b) + NSHeight(b) * 0.85f)];
			[p lineToPoint:NSMakePoint(NSMinX(b) + NSWidth(b) * 0.75f, NSMinY(b) + NSHeight(b) * 0.15f)];
			[p stroke];
			break;
		case AEStopIcon:
			NSRectFillUsingOperation(NSIntegralRect(NSInsetRect(b, NSWidth(b) * 0.15f, NSHeight(b) * 0.15f)), NSCompositeSourceOver);
			break;
		default: return;
	}
}
+ (void)AE_drawSpinnerInRect:(NSRect)r
        startAtPetal:(NSInteger)petal
{
	[NSBezierPath setDefaultLineWidth:MIN(NSWidth(r), NSHeight(r)) / 11.0f];
	[NSBezierPath setDefaultLineCapStyle:NSRoundLineCapStyle];
	NSUInteger i = 0;
	for(; i < 12; i++) {
		[[[NSColor AE_bezelForegroundColor] colorWithAlphaComponent:petal < 0.0f ? 0.1f : ((petal + i) % 12) / -12.0f + 1.0f] set];
		[NSBezierPath strokeLineFromPoint:NSMakePoint(NSMidX(r) + cosf((CGFloat)pi * 2.0f * i / 12.0f) * NSWidth(r) / 4.0f, NSMidY(r) + sinf((CGFloat)pi * 2.0f * i / 12.0f) * NSHeight(r) / 4.0f) toPoint:NSMakePoint(NSMidX(r) + cosf((CGFloat)pi * 2.0f * i / 12.0f) * NSWidth(r) / 2.0f, NSMidY(r) + sinf((CGFloat)pi * 2.0f * i / 12.0f) * NSHeight(r) / 2.0f)];
	}
	[NSBezierPath setDefaultLineWidth:1];
	[NSBezierPath setDefaultLineCapStyle:NSMiterLineJoinStyle];
}

#pragma mark Instance Methods

- (void)AE_fillUsingOperation:(NSCompositingOperation)op
{
	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setCompositingOperation:op];
	[self fill];
	[NSGraphicsContext restoreGraphicsState];
}

@end
