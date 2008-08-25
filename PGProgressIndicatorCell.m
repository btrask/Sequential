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
#import "PGProgressIndicatorCell.h"

// Categories
#import "NSBezierPathAdditions.h"

@implementation PGProgressIndicatorCell

#pragma mark Instance Methods

- (BOOL)hidden
{
	return _hidden;
}
- (void)setHidden:(BOOL)flag
{
	_hidden = flag;
}

#pragma mark NSCell

- (void)drawWithFrame:(NSRect)aRect
        inView:(NSView *)aView
{
	if([self hidden]) return;

	[[NSColor colorWithDeviceWhite:0.9 alpha:0.8] set];
	[[NSBezierPath AE_bezierPathWithRoundRect:NSInsetRect(aRect, 0.5, 0.5) cornerRadius:(NSHeight(aRect) - 1) / 2] stroke];

	NSRect r = aRect;
	r.size.width = ceilf(NSWidth(aRect) * [[self objectValue] floatValue]); // For some reason -[NSCell floatValue] doesn't work.
	[NSGraphicsContext saveGraphicsState];
	[[NSBezierPath bezierPathWithRect:r] addClip];
	[[NSBezierPath AE_bezierPathWithRoundRect:NSInsetRect(aRect, 2, 2) cornerRadius:(NSHeight(aRect) - 4) / 2] addClip];
	
	r.size.height = ceilf(NSHeight(r) / 2);
	[[NSColor colorWithDeviceWhite:0.95 alpha:0.8] set];
	NSRectFillUsingOperation(r, NSCompositeSourceOver);
	r.origin.y += NSHeight(r);
	[[NSColor colorWithDeviceWhite:0.85 alpha:0.8] set];
	NSRectFillUsingOperation(r, NSCompositeSourceOver);
	
	[NSGraphicsContext restoreGraphicsState];
}

@end
