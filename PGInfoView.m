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
#import "PGInfoView.h"
#import <tgmath.h>

// Views
#import "PGBezelPanel.h"

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGFoundationAdditions.h"

#define PGGraphicalProgressBarStyle true
#define PGMarginSize 4.0f // Outside the window.
#define PGPaddingSize 3.0f // Inside the window.
#define PGTotalPaddingSize (PGPaddingSize * 2.0f)
#define PGTextBottomPadding (PGPaddingSize - 1.0f)
#define PGTextTotalVertPadding (PGPaddingSize + PGTextBottomPadding)
#define PGTextHorzPadding 4.0f
#define PGTextTotalHorzPadding (PGTextHorzPadding * 2.0f)
#define PGProgressBarMargin 1.0f
#define PGProgressBarBorder (PGPaddingSize + PGProgressBarMargin)
#define PGProgressBarHeight 10.0f
#define PGProgressBarRadius (PGProgressBarHeight / 2.0f)
#define PGProgressBarWidth 100.0f
#define PGProgressKnobSize (PGProgressBarHeight - 2.0f)
#define PGCornerRadius (PGPaddingSize + PGProgressBarRadius)

@implementation PGInfoView

#pragma mark -PGInfoView

- (NSAttributedString *)attributedStringValue
{
	NSMutableParagraphStyle *const style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setAlignment:NSCenterTextAlignment];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	if(![self showsProgressBar]) [style setAlignment:NSCenterTextAlignment];
	NSString *const string = PGGraphicalProgressBarStyle ? [self stringValue] : [NSString stringWithFormat:@"%@ (%lu/%lu)", [self stringValue], (unsigned long)[self index] + 1, (unsigned long)[self count]];
	return [[[NSAttributedString alloc] initWithString:string attributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont labelFontOfSize:0.0f], NSFontAttributeName,
		[NSColor whiteColor], NSForegroundColorAttributeName,
		style, NSParagraphStyleAttributeName,
		nil]] autorelease];
}
- (NSString *)stringValue
{
	return _stringValue ? [[_stringValue retain] autorelease] : @"";
}
- (void)setStringValue:(NSString *)aString
{
	NSString *const string = aString ? aString : @"";
	if(string == _stringValue) return;
	[_stringValue release];
	_stringValue = [string copy];
	[self setNeedsDisplay:YES];
	[self PG_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
}
@synthesize index = _index;
- (void)setIndex:(NSUInteger)anInt
{
	if(anInt == _index) return;
	_index = anInt;
	[self setNeedsDisplay:YES];
}
@synthesize count = _count;
- (void)setCount:(NSUInteger)anInt
{
	if(anInt == _count) return;
	BOOL const showedProgressBar = [self showsProgressBar];
	_count = anInt;
	if(!showedProgressBar != ![self showsProgressBar]) [self PG_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
	else [self setNeedsDisplay:YES];
}
- (BOOL)showsProgressBar
{
	return PGGraphicalProgressBarStyle && [self count] > 1;
}
@synthesize originCorner = _originCorner;

#pragma mark -NSView

- (BOOL)isFlipped
{
	return NO;
}
- (void)drawRect:(NSRect)aRect
{
	NSRect const b = [self bounds];
	NSBezierPath *const bezel = [NSBezierPath PG_bezierPathWithRoundRect:b cornerRadius:PGCornerRadius];
	[[NSColor PG_bezelBackgroundColor] set];
	[bezel fill];
	if([self showsProgressBar]) {
		[[NSColor PG_bezelForegroundColor] set];
		CGFloat const origin = [self originCorner] == PGMaxXMinYCorner ? NSMaxX(b) - 1.0f - PGProgressBarBorder : PGProgressBarBorder;
		NSBezierPath *const progressBarOutline = [NSBezierPath PG_bezierPathWithRoundRect:NSMakeRect(([self originCorner] == PGMinXMinYCorner ? 0.5f + origin : 0.5f + origin - PGProgressBarWidth), 0.5f + PGProgressBarBorder, PGProgressBarWidth, PGProgressBarHeight) cornerRadius:PGProgressBarRadius];

		NSUInteger const maxValue = [self count] - 1;
		CGFloat x = round(((CGFloat)MIN([self index], maxValue) / maxValue) * (PGProgressBarWidth - PGProgressBarHeight) + PGProgressBarHeight / 2.0f);
		if([self originCorner] == PGMaxXMinYCorner) x = -x + origin;
		else x = x + origin;

		[NSGraphicsContext saveGraphicsState];
		[[NSGraphicsContext currentContext] setShouldAntialias:NO];
		NSBezierPath *const knob = [NSBezierPath bezierPath];
		CGFloat const halfKnob = PGProgressKnobSize / 2.0f;
		[knob moveToPoint:NSMakePoint(0.5f + x           , 1.5f + PGProgressBarBorder)];
		[knob lineToPoint:NSMakePoint(0.5f + x - halfKnob, 1.5f + PGProgressBarBorder + halfKnob)];
		[knob lineToPoint:NSMakePoint(0.5f + x           , 1.5f + PGProgressBarBorder + PGProgressKnobSize)];
		[knob lineToPoint:NSMakePoint(0.5f + x + halfKnob, 1.5f + PGProgressBarBorder + halfKnob)];
		[knob closePath];
		[knob fill];
		[NSGraphicsContext restoreGraphicsState];

		[progressBarOutline stroke];
	}
	CGFloat const progressBarWidth = [self showsProgressBar] ? PGProgressBarWidth : 0.0f;
	CGFloat const textOffset = [self originCorner] == PGMinXMinYCorner ? progressBarWidth : 0.0f;
	[[self attributedStringValue] drawInRect:NSMakeRect(NSMinX(b) + PGPaddingSize + PGTextHorzPadding + textOffset, NSMinY(b) + PGTextBottomPadding, NSWidth(b) - PGTotalPaddingSize - PGTextTotalHorzPadding - progressBarWidth, NSHeight(b) - PGTextTotalVertPadding)];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_stringValue release];
	[super dealloc];
}

#pragma mark -<PGBezelPanelContentView>

- (NSRect)bezelPanel:(PGBezelPanel *)sender frameForContentRect:(NSRect)aRect scale:(CGFloat)scaleFactor
{
	NSSize const messageSize = [[self attributedStringValue] size];
	NSSize const progressBarSize = [self showsProgressBar] ? NSMakeSize(PGProgressBarWidth + 1.0f + PGProgressBarMargin * 2.0f, PGProgressBarHeight + 1.0f + PGProgressBarBorder * 2.0f) : NSZeroSize;
	CGFloat const scaledMarginSize = PGMarginSize * scaleFactor;
	NSRect frame = NSIntersectionRect(
		NSMakeRect(
			NSMinX(aRect) + scaledMarginSize,
			NSMinY(aRect) + scaledMarginSize,
			ceilf((messageSize.width + PGTextTotalHorzPadding + progressBarSize.width + PGTotalPaddingSize) * scaleFactor),
			ceilf(MAX(messageSize.height + PGTextTotalVertPadding, progressBarSize.height) * scaleFactor)),
		NSInsetRect(aRect, scaledMarginSize, scaledMarginSize));
	frame.size.width = MAX(NSWidth(frame), NSHeight(frame)); // Don't allow the panel to be narrower than it is tall.
	if([self originCorner] == PGMaxXMinYCorner) frame.origin.x = NSMaxX(aRect) - scaledMarginSize - NSWidth(frame);
	return frame;
}

@end
