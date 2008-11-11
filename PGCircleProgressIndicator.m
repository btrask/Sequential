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
#import "PGCircleProgressIndicator.h"

@implementation PGCircleProgressIndicator

#pragma mark Instance Methods

- (float)floatValue
{
	return _floatValue;
}
- (void)setFloatValue:(float)val
{
	_floatValue = MIN(MAX(val, 0), 1);
	[self setNeedsDisplay:YES];
}

#pragma mark NSView

- (void)drawRect:(NSRect)aRect
{
	NSRect const b = [self bounds];
	[[NSColor colorWithDeviceWhite:0.9 alpha:0.8] set];
	[[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(b, 0.5, 0.5)] stroke];

	if(_floatValue < 0.001) return;

	[NSGraphicsContext saveGraphicsState];

	NSBezierPath *path = [NSBezierPath bezierPath];
	NSPoint const center = NSMakePoint(NSMidX(b), NSMidY(b));
	[path moveToPoint:center];
	[path appendBezierPathWithArcWithCenter:center radius:NSWidth(b) / 2 - 2 startAngle:90 endAngle:[self floatValue] * -360.0 + 90 clockwise:YES];
	[path addClip];

	[[NSColor colorWithDeviceWhite:0.85 alpha:0.8] set];
	NSRectFillUsingOperation(b, NSCompositeSourceOver);

	[[NSColor colorWithDeviceWhite:1 alpha:0.2] set];
	[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMinX(b), NSMaxY(b) - NSHeight(b) * 0.6, NSWidth(b), NSHeight(b) * 0.75)] fill];

	[NSGraphicsContext restoreGraphicsState];
}
- (BOOL)acceptsFirstMouse:(NSEvent *)anEvent
{
	return YES;
}

@end
