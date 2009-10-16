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
#import "PGTimerButton.h"

// Other
#import "PGGeometry.h"

// Categories
#import "PGAppKitAdditions.h"

@implementation PGTimerButton

#pragma mark +NSControl

+ (id)cellClass
{
	return [PGTimerButtonCell class];
}

#pragma mark -PGTimerButton

- (AEIconType)iconType
{
	return [[self cell] iconType];
}
- (void)setIconType:(AEIconType)state
{
	[[self cell] setIconType:state];
	[self setNeedsDisplay:YES];
}
- (CGFloat)progress
{
	return [[self cell] progress];
}
- (void)setProgress:(CGFloat)aFloat
{
	[[self cell] setProgress:aFloat];
	[self setNeedsDisplay:YES];
}

@end

@implementation PGTimerButtonCell

#pragma mark -PGTimerButtonCell

@synthesize iconType = _iconType;
@synthesize progress = _progress;

#pragma mark -NSCell

- (BOOL)isOpaque
{
	return NO;
}
- (void)drawWithFrame:(NSRect)b inView:(NSView *)v
{
	[[NSColor PG_bezelForegroundColor] set];
	[[NSBezierPath bezierPathWithOvalInRect:NSInsetRect(b, 0.5f, 0.5f)] stroke];
	[self drawInteriorWithFrame:b inView:v];
}
- (void)drawInteriorWithFrame:(NSRect)b inView:(NSView *)v
{
	if([self progress] > 0.001f) {
		[NSGraphicsContext saveGraphicsState];
		NSBezierPath *path = [NSBezierPath bezierPath];
		NSPoint const center = NSMakePoint(NSMidX(b), NSMidY(b));
		[path moveToPoint:center];
		[path appendBezierPathWithArcWithCenter:center radius:NSWidth(b) / 2.0f - 2.0f startAngle:270.0f endAngle:[self progress] * 360.0f + 270.0f clockwise:NO];
		[path addClip];

		[[NSColor colorWithDeviceWhite:0.85f alpha:0.8f] set];
		NSRectFillUsingOperation(b, NSCompositeSourceOver);

		[[NSColor colorWithDeviceWhite:1.0f alpha:0.2f] set];
		[[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(NSMinX(b), NSMinY(b) - NSHeight(b) * 0.25f, NSWidth(b), NSHeight(b) * 0.75f)] fill];
		[NSGraphicsContext restoreGraphicsState];
	}

	if(AENoIcon != _iconType) {
		BOOL const e = [self isEnabled];
		NSColor *const color = [self isHighlighted] ? [NSColor colorWithDeviceWhite:0.8f alpha:0.9f] : [NSColor whiteColor];
		[(e ? color : [color colorWithAlphaComponent:0.33f]) set];
		NSShadow *const shadow = [[[NSShadow alloc] init] autorelease];
		[shadow setShadowOffset:NSMakeSize(0.0f, -1.0f)];
		[shadow setShadowBlurRadius:2.0f];
		[shadow setShadowColor:[NSColor colorWithDeviceWhite:0.0f alpha:e ? 1.0f : 0.33f]];
		[shadow set];
		[NSBezierPath PG_drawIcon:_iconType inRect:PGCenteredSizeInRect(NSMakeSize(20.0f, 20.0f), b)];
		[shadow setShadowColor:nil];
		[shadow set];
	}
}

@end
