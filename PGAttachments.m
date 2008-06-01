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
#import "PGAttachments.h"

static void PGEnsureWindowCreatedHack(void)
{
	// This is the ugliest hack I have ever written. The icons fail to draw if there has never been a window loaded. Defer must be NO.
	// The specific error is "-[_NSExistingCGSContext focusView:inWindow:]: selector not recognized" in -[NSTextAttachmentCell drawWithFrame:inView:].
	static BOOL createdWindow = NO;
	if(createdWindow) return;
	[[[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO] release];
	createdWindow = YES;
}

@interface PGFileIconAttachmentCell : NSTextAttachmentCell

- (id)initImageCell:(NSImage *)anImage;

@end

@implementation NSAttributedString (PGAdditions)

#pragma mark Instance Methods

+ (NSMutableAttributedString *)PG_attributedStringWithAttachmentCell:(NSTextAttachmentCell *)cell
                               label:(NSString *)label
{
	NSMutableAttributedString *const result = [[[NSMutableAttributedString alloc] init] autorelease];
	if(cell) {
		NSTextAttachment *const attachment = [[[NSTextAttachment alloc] init] autorelease];
		[attachment setAttachmentCell:cell];
		[result appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
		if(label) [[result mutableString] appendString:@" "];
	}
	if(label) [[result mutableString] appendString:label];
	[result addAttribute:NSFontAttributeName value:[NSFont menuFontOfSize:14] range:NSMakeRange(0, [result length])]; // Use 14 instead of 0 (default) for the font size because the default seems to be 13, which is wrong.
	return result;
}
+ (NSMutableAttributedString *)PG_attributedStringWithFileIcon:(NSImage *)anImage
                             name:(NSString *)fileName
{
	return [self PG_attributedStringWithAttachmentCell:(anImage ? [[[PGFileIconAttachmentCell alloc] initImageCell:anImage] autorelease] : nil) label:fileName];
}

@end

@implementation PGRotatedMenuIconCell

#pragma mark Instance Methods

- (id)initWithMenuItem:(NSMenuItem *)anItem
      rotation:(float)angle
{
	if((self = [super init])) {
		PGEnsureWindowCreatedHack();
		_item = anItem;
		_angle = angle;
	}
	return self;
}
- (void)drawWithFrame:(NSRect)aRect
        enabled:(BOOL)enabled
        highlighted:(BOOL)highlighted
{
	NSImage *const image = [NSImage imageNamed:[self imageNameHighlighted:highlighted]];
	[image setFlipped:YES];
	[image drawInRect:aRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:(enabled ? 1.0 : 0.5)];
}
- (NSString *)imageNameHighlighted:(BOOL)flag
{
	return nil;
}

#pragma mark NSTextAttachmentCell

- (void)drawWithFrame:(NSRect)aRect
        inView:(NSView *)aView
{
	[NSGraphicsContext saveGraphicsState];
	NSAffineTransform *const t = [[[NSAffineTransform alloc] init] autorelease];
	[t translateXBy:NSMidX(aRect) yBy:NSMidY(aRect)];
	[t rotateByDegrees:_angle];
	[t concat];
	[self drawWithFrame:NSMakeRect(NSWidth(aRect) / -2, NSHeight(aRect) / -2, NSWidth(aRect), NSHeight(aRect)) enabled:[_item isEnabled] highlighted:[[NSReadPixel(NSZeroPoint) colorUsingColorSpaceName:NSCalibratedWhiteColorSpace] whiteComponent] < 0.5]; // Yes, we use NSReadPixel to determine whether or not we're highlighted or not. Believe me, I've tried everything from aView to -isHighlighted to LMGetTheMenu() (don't ask).
	[NSGraphicsContext restoreGraphicsState];
}
- (NSSize)cellSize
{
	return NSMakeSize(16, 16);
}
- (NSPoint)cellBaselineOffset
{
	return NSMakePoint(0, -3);
}

@end

@implementation PGRotationMenuIconCell

#pragma mark PGRotatedMenuIconCell

- (NSString *)imageNameHighlighted:(BOOL)flag
{
	return flag ? @"Silhouette-White" : @"Silhouette-Black";
}

@end

@implementation PGMirrorMenuIconCell

#pragma mark PGRotatedMenuIconCell

- (NSString *)imageNameHighlighted:(BOOL)flag
{
	return flag ? @"Mirror-White" : @"Mirror-Black";
}

@end

@implementation PGFileIconAttachmentCell

#pragma mark NSTextAttachmentCell

- (NSPoint)cellBaselineOffset
{
	return NSMakePoint(0, -3);
}

#pragma mark NSCell

- (id)initImageCell:(NSImage *)anImage
{
	PGEnsureWindowCreatedHack();
	[anImage setScalesWhenResized:YES];
	[anImage setSize:NSMakeSize(16, 16)];
	return [super initImageCell:anImage];
}

@end
