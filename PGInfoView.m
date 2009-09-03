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
#include <tgmath.h>

#define PGGraphicalIndicatorStyle YES
#define PGMarginSize              4.0f // Outside the window.
#define PGPaddingSize             3.0f // Inside the window.
#define PGTotalPaddingSize        (PGPaddingSize * 2.0f)
#define PGTextBottomPadding       (PGPaddingSize - 1.0f)
#define PGTextTotalVertPadding    (PGPaddingSize + PGTextBottomPadding)
#define PGTextHorzPadding         4.0f
#define PGTextTotalHorzPadding    (PGTextHorzPadding * 2.0f)
#define PGIndicatorHeight         11.0f
#define PGIndicatorRadius         (PGIndicatorHeight / 2.0f)
#define PGIndicatorWidth          100.0f
#define PGCornerRadius            (PGPaddingSize + PGIndicatorRadius)

@implementation PGInfoView

#pragma mark Instance Methods

- (NSAttributedString *)displayText
{
	NSMutableParagraphStyle *const style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setAlignment:NSCenterTextAlignment];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	if(![self displaysProgressIndicator]) [style setAlignment:NSCenterTextAlignment];
	return [[[NSAttributedString alloc] initWithString:(PGGraphicalIndicatorStyle ? [self messageText] : [NSString stringWithFormat:@"%@ (%lu/%lu)", [self messageText], (unsigned long)[self index] + 1, (unsigned long)[self count]]) attributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont labelFontOfSize:0.0f], NSFontAttributeName,
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

- (NSUInteger)index
{
	return _index;
}
- (void)setIndex:(NSUInteger)anInt
{
	if(anInt == _index) return;
	_index = anInt;
	[self setNeedsDisplay:YES];
}

- (NSUInteger)count
{
	return _count;
}
- (void)setCount:(NSUInteger)anInt
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
          scale:(CGFloat)scaleFactor
{
	NSSize const messageSize = [[self displayText] size];
	CGFloat const scaledMarginSize = PGMarginSize * scaleFactor;
	NSRect frame = NSIntersectionRect(
		NSMakeRect(
			NSMinX(aRect) + scaledMarginSize,
			NSMinY(aRect) + scaledMarginSize,
			ceil((messageSize.width + PGTextTotalHorzPadding + ([self displaysProgressIndicator] ? PGIndicatorWidth : 0.0f) + PGTotalPaddingSize) * scaleFactor),
			ceil(MAX(messageSize.height + PGTextTotalVertPadding, ([self displaysProgressIndicator] ? PGIndicatorHeight + PGPaddingSize : 0.0f)) * scaleFactor)),
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
		[[NSBezierPath AE_bezierPathWithRoundRect:NSMakeRect(([self origin] == PGMinXMinYCorner ? 0.5f + PGPaddingSize : NSWidth(b) - PGIndicatorWidth - PGPaddingSize + 0.5f), 0.5f + PGPaddingSize, PGIndicatorWidth - 1.0f, PGIndicatorHeight) cornerRadius:PGIndicatorRadius] stroke];

		NSUInteger const maxValue = [self count] - 1;
		NSBezierPath *const indicator = [NSBezierPath bezierPath];
		CGFloat x = round(((CGFloat)MIN([self index], maxValue) / maxValue) * (PGIndicatorWidth - 1 - PGIndicatorHeight) + 1);
		if([self origin] == PGMaxXMinYCorner) x = NSMaxX(b) - x - 10.0f - PGPaddingSize;
		else x += PGPaddingSize;
		[indicator moveToPoint:NSMakePoint(x + 0.5f, PGPaddingSize + 6.0f)];
		[indicator lineToPoint:NSMakePoint(x + 5.0f, PGPaddingSize + 10.5f)];
		[indicator lineToPoint:NSMakePoint(x + 9.5f, PGPaddingSize + 6.0f)];
		[indicator lineToPoint:NSMakePoint(x + 5.0f, PGPaddingSize + 1.5f)];
		[indicator fill];
	}
	CGFloat const indicatorWidth = [self displaysProgressIndicator] ? PGIndicatorWidth : 0.0f;
	CGFloat const textOffset = [self origin] == PGMinXMinYCorner ? indicatorWidth : 0.0f;
	[[self displayText] drawInRect:NSMakeRect(NSMinX(b) + PGPaddingSize + PGTextHorzPadding + textOffset, NSMinY(b) + PGTextBottomPadding, NSWidth(b) - PGTotalPaddingSize - PGTextTotalHorzPadding - indicatorWidth, NSHeight(b) - PGTextTotalVertPadding)];
}

#pragma mark NSObject

- (void)dealloc
{
	[_messageText release];
	[super dealloc];
}

@end
