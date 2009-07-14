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

// Views
#import "PGBezelPanel.h"

// Categories
#import "NSBezierPathAdditions.h"
#import "NSColorAdditions.h"
#import "NSObjectAdditions.h"

#define PGGraphicalIndicatorStyle YES
#define PGMarginSize              4.0 // Outside the window.
#define PGPaddingSize             3.0 // Inside the window.
#define PGTotalPaddingSize        (PGPaddingSize * 2.0)
#define PGTextBottomPadding       (PGPaddingSize - 1.0)
#define PGTextTotalVertPadding    (PGPaddingSize + PGTextBottomPadding)
#define PGTextHorzPadding         4.0
#define PGTextTotalHorzPadding    (PGTextHorzPadding * 2.0)
#define PGIndicatorHeight         11.0
#define PGIndicatorRadius         (PGIndicatorHeight / 2.0)
#define PGIndicatorWidth          100.0
#define PGCornerRadius            (PGPaddingSize + PGIndicatorRadius)

@implementation PGInfoView

#pragma mark Instance Methods

- (NSAttributedString *)displayText
{
	NSMutableParagraphStyle *const style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setAlignment:NSCenterTextAlignment];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	if(![self displaysProgressIndicator]) [style setAlignment:NSCenterTextAlignment];
	return [[[NSAttributedString alloc] initWithString:(PGGraphicalIndicatorStyle ? [self messageText] : [NSString stringWithFormat:@"%@ (%u/%u)", [self messageText], [self index] + 1, [self count]]) attributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont labelFontOfSize:0], NSFontAttributeName,
		[NSColor whiteColor], NSForegroundColorAttributeName,
		style, NSParagraphStyleAttributeName, nil]] autorelease];
}

#pragma mark -

- (NSString *)messageText
{
	return _messageText ? [[_messageText retain] autorelease] : @"";
}
- (void)setMessageText:(NSString *)aString
{
	NSString *const string = aString ? aString : @"";
	if(string == _messageText) return;
	[_messageText release];
	_messageText = [string copy];
	[self setNeedsDisplay:YES];
	[self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
}

#pragma mark -

- (unsigned)index
{
	return _index;
}
- (void)setIndex:(unsigned)anInt
{
	if(anInt == _index) return;
	_index = anInt;
	[self setNeedsDisplay:YES];
}

- (unsigned)count
{
	return _count;
}
- (void)setCount:(unsigned)anInt
{
	if(anInt == _count) return;
	BOOL const showedIndicator = [self displaysProgressIndicator];
	_count = anInt;
	if(!showedIndicator != ![self displaysProgressIndicator]) [self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
	else [self setNeedsDisplay:YES];
}

#pragma mark -

- (BOOL)displaysProgressIndicator
{
	return PGGraphicalIndicatorStyle && [self count] > 1;
}

#pragma mark -

- (PGInfoCorner)origin
{
	return _origin;
}
- (void)setOrigin:(PGInfoCorner)aSide
{
	_origin = aSide;
}

#pragma mark PGBezelPanelContentView Protocol

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)scaleFactor
{
	NSSize const messageSize = [[self displayText] size];
	float const scaledMarginSize = PGMarginSize * scaleFactor;
	NSRect frame = NSIntersectionRect(
		NSMakeRect(
			NSMinX(aRect) + scaledMarginSize,
			NSMinY(aRect) + scaledMarginSize,
			ceilf((messageSize.width + PGTextTotalHorzPadding + ([self displaysProgressIndicator] ? PGIndicatorWidth : 0) + PGTotalPaddingSize) * scaleFactor),
			ceilf(MAX(messageSize.height + PGTextTotalVertPadding, ([self displaysProgressIndicator] ? PGIndicatorHeight + PGPaddingSize : 0)) * scaleFactor)),
		NSInsetRect(aRect, scaledMarginSize, scaledMarginSize));
	frame.size.width = MAX(NSWidth(frame), NSHeight(frame)); // Don't allow the panel to be narrower than it is tall.
	if([self origin] == PGMaxXMinYCorner) frame.origin.x = NSMaxX(aRect) - scaledMarginSize - NSWidth(frame);
	return frame;
}

#pragma mark NSView

- (BOOL)isFlipped
{
	return NO;
}
- (void)drawRect:(NSRect)aRect
{
	NSRect const b = [self bounds];
	NSBezierPath *const bezel = [NSBezierPath AE_bezierPathWithRoundRect:b cornerRadius:PGCornerRadius];
	[[NSColor AE_bezelBackgroundColor] set];
	[bezel fill];
	if([self displaysProgressIndicator]) {
		[[NSColor AE_bezelForegroundColor] set];
		[[NSBezierPath AE_bezierPathWithRoundRect:NSMakeRect(([self origin] == PGMinXMinYCorner ? 0.5 + PGPaddingSize : NSWidth(b) - PGIndicatorWidth - PGPaddingSize + 0.5), 0.5 + PGPaddingSize, PGIndicatorWidth - 1, PGIndicatorHeight) cornerRadius:PGIndicatorRadius] stroke];

		unsigned const maxValue = [self count] - 1;
		NSBezierPath *const indicator = [NSBezierPath bezierPath];
		float x = roundf(((float)MIN([self index], maxValue) / maxValue) * (PGIndicatorWidth - 1 - PGIndicatorHeight) + 1);
		if([self origin] == PGMaxXMinYCorner) x = NSMaxX(b) - x - 10 - PGPaddingSize;
		else x += PGPaddingSize;
		[indicator moveToPoint:NSMakePoint(x + 0.5, 6 + PGPaddingSize)];
		[indicator lineToPoint:NSMakePoint(x + 5, 10.5 + PGPaddingSize)];
		[indicator lineToPoint:NSMakePoint(x + 9.5, 6 + PGPaddingSize)];
		[indicator lineToPoint:NSMakePoint(x + 5, 1.5 + PGPaddingSize)];
		[indicator fill];
	}
	float const indicatorWidth = [self displaysProgressIndicator] ? PGIndicatorWidth : 0;
	float const textOffset = [self origin] == PGMinXMinYCorner ? indicatorWidth : 0;
	[[self displayText] drawInRect:NSMakeRect(NSMinX(b) + PGPaddingSize + PGTextHorzPadding + textOffset, NSMinY(b) + PGTextBottomPadding, NSWidth(b) - PGTotalPaddingSize - PGTextTotalHorzPadding - indicatorWidth, NSHeight(b) - PGTextTotalVertPadding)];
}

#pragma mark NSObject

- (void)dealloc
{
	[_messageText release];
	[super dealloc];
}

@end
