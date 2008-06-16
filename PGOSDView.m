/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGOSDView.h"

// Views
#import "PGBezelPanel.h"

// Categories
#import "NSBezierPathAdditions.h"
#import "NSObjectAdditions.h"

#define PGGraphicalIndicatorStyle YES
#define PGMarginSize              7.0 // Outside the window.
#define PGPaddingSize             3.0 // Inside the window.
#define PGTotalPaddingSize        (PGPaddingSize * 2)
#define PGTextBottomPadding       (PGPaddingSize - 1.0)
#define PGTextTotalVertPadding    (PGPaddingSize + PGTextBottomPadding)
#define PGTextTotalHorzPadding    2.0
#define PGIndicatorHeight         11.0
#define PGIndicatorRadius         (PGIndicatorHeight / 2)
#define PGMinWidth                (PGGraphicalIndicatorStyle ? 50.0 : 0.0)

@implementation PGOSDView

#pragma mark Instance Methods

- (NSAttributedString *)displayText
{
	NSMutableParagraphStyle *const style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
	[style setAlignment:NSCenterTextAlignment];
	[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
	return [[[NSAttributedString alloc] initWithString:(PGGraphicalIndicatorStyle ? [self messageText] : [NSString stringWithFormat:@"%@ (%u/%u)", [self messageText], [self index] + 1, [self count]]) attributes:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSFont labelFontOfSize:0], NSFontAttributeName,
		[NSColor whiteColor], NSForegroundColorAttributeName,
		style, NSParagraphStyleAttributeName, nil]] autorelease];
}

#pragma mark -

- (NSString *)messageText
{
	return fMessageText ? [[fMessageText retain] autorelease] : @"";
}
- (void)setMessageText:(NSString *)aString
{
	NSString *const string = aString ? aString : @"";
	if(string == fMessageText) return;
	[fMessageText release];
	fMessageText = [string copy];
	[self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO] forKey:PGBezelPanelShouldAnimateKey]];
}

#pragma mark -

- (unsigned)index
{
	return fIndex;
}
- (void)setIndex:(unsigned)anInt
{
	fIndex = anInt;
	[self setNeedsDisplay:YES];
}

- (unsigned)count
{
	return fCount;
}
- (void)setCount:(unsigned)anInt
{
	if(anInt == fCount) return;
	BOOL const showedIndicator = [self displaysProgressIndicator];
	fCount = anInt;
	if(!showedIndicator != ![self displaysProgressIndicator]) [self AE_postNotificationName:PGBezelPanelFrameShouldChangeNotification];
	else [self setNeedsDisplay:YES];
}
- (BOOL)displaysProgressIndicator
{
	return PGGraphicalIndicatorStyle && [self count] > 1;
}

#pragma mark -

- (PGOSDCorner)origin
{
	return fOrigin;
}
- (NSSize)originOffset
{
	return fOriginOffset;
}
- (void)setOrigin:(PGOSDCorner)aSide
        offset:(NSSize)aSize
{
	fOrigin = aSide;
	fOriginOffset = aSize;
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
			NSMinX(aRect) + MAX(scaledMarginSize, fOriginOffset.width),
			NSMinY(aRect) + MAX(scaledMarginSize, fOriginOffset.height),
			MAX(ceilf(messageSize.width + PGTotalPaddingSize + PGTextTotalHorzPadding), PGMinWidth) * scaleFactor,
			ceilf(messageSize.height + PGTextTotalVertPadding + ([self displaysProgressIndicator] ? PGIndicatorHeight + PGPaddingSize : 0)) * scaleFactor),
		NSInsetRect(aRect, scaledMarginSize, scaledMarginSize));
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
	NSRect const b = [self bounds];

	NSBezierPath *const bezel = [NSBezierPath AE_bezierPathWithRoundRect:b cornerRadius:(PGPaddingSize + PGIndicatorRadius)];
	[[NSColor colorWithDeviceWhite:(48.0f / 255.0f) alpha:0.75f] set];
	[bezel fill];

	if([self displaysProgressIndicator]) {
		[[NSColor colorWithDeviceWhite:0.95 alpha:0.9] set];
		[[NSBezierPath AE_bezierPathWithRoundRect:NSMakeRect(0.5 + PGPaddingSize, 0.5 + PGPaddingSize, NSWidth(b) - 1 - PGTotalPaddingSize, PGIndicatorHeight) cornerRadius:PGIndicatorRadius] stroke];

		unsigned const maxValue = [self count] - 1;
		NSBezierPath *const indicator = [NSBezierPath bezierPath];
		float x = roundf(((float)MIN([self index], maxValue) / maxValue) * (NSWidth(b) - 1 - PGTotalPaddingSize - PGIndicatorHeight) + 1);
		if([self origin] == PGMaxXMinYCorner) x = NSMaxX(b) - x - 10 - PGPaddingSize;
		else x += PGPaddingSize;
		[indicator moveToPoint:NSMakePoint(x + 0.5, 6 + PGPaddingSize)];
		[indicator lineToPoint:NSMakePoint(x + 5, 10.5 + PGPaddingSize)];
		[indicator lineToPoint:NSMakePoint(x + 9.5, 6 + PGPaddingSize)];
		[indicator lineToPoint:NSMakePoint(x + 5, 1.5 + PGPaddingSize)];
		[indicator fill];
	}

	float const indicatorHeight = [self displaysProgressIndicator] ? PGIndicatorHeight : 0;
	[[self displayText] drawInRect:NSMakeRect(PGPaddingSize, PGTextBottomPadding + indicatorHeight, NSWidth(b) - PGTotalPaddingSize, NSHeight(b) - PGTextTotalVertPadding - indicatorHeight)];
}

#pragma mark NSObject

- (void)dealloc
{
	[fMessageText release];
	[super dealloc];
}

@end
