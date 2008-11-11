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
