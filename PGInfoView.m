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
#import "PGInfoView.h"

// Views
#import "PGBezelPanel.h"

// Categories
#import "NSBezierPathAdditions.h"
#import "NSObjectAdditions.h"

#define PGGraphicalIndicatorStyle YES
#define PGAutohides               YES
#define PGMarginSize              4.0 // Outside the window.
#define PGPaddingSize             3.0 // Inside the window.
#define PGTotalPaddingSize        (PGPaddingSize * 2.0)
#define PGTextBottomPadding       (PGPaddingSize - 1.0)
#define PGTextTotalVertPadding    (PGPaddingSize + PGTextBottomPadding)
#define PGTextHorzPadding         1.0
#define PGTextTotalHorzPadding    (PGTextHorzPadding * 2.0)
#define PGIndicatorHeight         11.0
#define PGIndicatorRadius         (PGIndicatorHeight / 2.0)
#define PGIndicatorWidth          150.0
#define PGCornerRadius            (PGPaddingSize + PGIndicatorRadius)

@implementation PGInfoView

#pragma mark Instance Methods

- (NSAttributedString *)displayText
{
	NSMutableParagraphStyle *const style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setAlignment:([self origin] == PGMinXMinYCorner ? NSLeftTextAlignment : NSRightTextAlignment)];
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
	[self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:PGBezelPanelShouldAnimateKey]]; // The animation happens syncrhonously, which slows down page switching.
}

#pragma mark -

- (unsigned)index
{
	return _index;
}
- (void)setIndex:(unsigned)anInt
{
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

- (BOOL)shouldAutohide
{
	return PGAutohides && _allowsAutohide && [self count] <= 1;
}
- (void)setAllowsAutohide:(BOOL)flag
{
	_allowsAutohide = flag;
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
- (NSSize)originOffset
{
	return _originOffset;
}
- (void)setOrigin:(PGInfoCorner)aSide
        offset:(NSSize)aSize
{
	_origin = aSide;
	_originOffset = aSize;
}

#pragma mark PGBezelPanelContentView Protocol

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)scaleFactor
{
	if([self shouldAutohide]) return NSZeroRect;
	NSSize const messageSize = [[self displayText] size];
	float const scaledMarginSize = PGMarginSize * scaleFactor;
	NSRect frame = NSIntersectionRect(
		NSMakeRect(
			NSMinX(aRect) + MAX(scaledMarginSize, _originOffset.width),
			NSMinY(aRect) + MAX(scaledMarginSize, _originOffset.height),
			ceilf(MAX(messageSize.width + PGTextTotalHorzPadding, ([self displaysProgressIndicator] ? PGIndicatorWidth : 0)) + PGTotalPaddingSize) * scaleFactor,
			ceilf(messageSize.height + PGTextTotalVertPadding + ([self displaysProgressIndicator] ? PGIndicatorHeight + PGPaddingSize : 0)) * scaleFactor),
		NSInsetRect(aRect, scaledMarginSize, scaledMarginSize));
	frame.size.width = MAX(NSWidth(frame), NSHeight(frame)); // Don't allow the panel to be narrower than it is tall.
	frame.size.width = MIN(NSWidth(frame), NSWidth(aRect) / 2 - scaledMarginSize); // Don't allow the panel to be more than half the width of the window.
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
	if([self shouldAutohide]) return;
	NSRect const b = [self bounds];
	NSBezierPath *const bezel = [NSBezierPath AE_bezierPathWithRoundRect:b cornerRadius:PGCornerRadius];
	[[NSColor colorWithDeviceWhite:(48.0f / 255.0f) alpha:0.75f] set];
	[bezel fill];
	if([self displaysProgressIndicator]) {
		[[NSColor colorWithDeviceWhite:0.95 alpha:0.9] set];
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
	float const indicatorHeight = [self displaysProgressIndicator] ? PGIndicatorHeight : 0;
	[[self displayText] drawInRect:NSMakeRect(PGPaddingSize + PGTextHorzPadding, PGTextBottomPadding + indicatorHeight, NSWidth(b) - PGTotalPaddingSize - PGTextTotalHorzPadding, NSHeight(b) - PGTextTotalVertPadding - indicatorHeight)];
}

#pragma mark NSObject

- (void)dealloc
{
	[_messageText release];
	[super dealloc];
}

@end
