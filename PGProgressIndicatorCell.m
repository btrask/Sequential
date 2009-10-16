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
#import "PGProgressIndicatorCell.h"
#import <tgmath.h>

// Categories
#import "PGAppKitAdditions.h"

@implementation PGProgressIndicatorCell

#pragma mark -PGProgressIndicatorCell

@synthesize hidden = _hidden;

#pragma mark -NSCell

- (void)drawWithFrame:(NSRect)aRect inView:(NSView *)aView
{
	if([self hidden]) return;

	[[NSColor colorWithDeviceWhite:0.9f alpha:0.8f] set];
	[[NSBezierPath PG_bezierPathWithRoundRect:NSInsetRect(aRect, 0.5f, 0.5f) cornerRadius:(NSHeight(aRect) - 1.0f) / 2.0f] stroke];

	NSRect r = aRect;
	r.size.width = (CGFloat)ceil(NSWidth(aRect) * [[self objectValue] doubleValue]);
	[NSGraphicsContext saveGraphicsState];
	NSRectClip(r);
	[[NSBezierPath PG_bezierPathWithRoundRect:NSInsetRect(aRect, 2.0f, 2.0f) cornerRadius:(NSHeight(aRect) - 4.0f) / 2.0f] addClip];
	
	r.size.height = ceil(NSHeight(r) / 2.0f);
	[[NSColor colorWithDeviceWhite:0.95f alpha:0.8f] set];
	NSRectFillUsingOperation(r, NSCompositeSourceOver);
	r.origin.y += NSHeight(r);
	[[NSColor colorWithDeviceWhite:0.85f alpha:0.8f] set];
	NSRectFillUsingOperation(r, NSCompositeSourceOver);
	
	[NSGraphicsContext restoreGraphicsState];
}

@end
