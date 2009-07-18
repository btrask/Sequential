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
#import "PGAttachments.h"

static void PGEnsureWindowCreatedHack(void)
{
	// The icons fail to draw on Tiger if there has never been a window loaded. Defer must be NO. The specific error is "-[_NSExistingCGSContext focusView:inWindow:]: selector not recognized" in -drawWithFrame:inView:.
	static BOOL createdWindow = NO;
	if(createdWindow) return;
	(void)[[[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO] autorelease];
	createdWindow = YES;
}

@interface PGFileIconAttachmentCell : NSTextAttachmentCell

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
	return [self PG_attributedStringWithAttachmentCell:[[[PGFileIconAttachmentCell alloc] initImageCell:anImage] autorelease] label:fileName];
}

@end

@implementation PGRotatedMenuIconCell

#pragma mark Instance Methods

- (id)initWithMenuItem:(NSMenuItem *)anItem
      rotation:(float)angle
{
	if((self = [super init])) {
		if(!PGIsTigerOrLater()) {
			[self release];
			return nil;
		}
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
	[image drawInRect:aRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:enabled ? 1.0f : 0.5f];
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
	BOOL const highlighted = [_item respondsToSelector:@selector(isHighlighted)] ? [_item isHighlighted] : NO;
	[self drawWithFrame:NSMakeRect(NSWidth(aRect) / -2, NSHeight(aRect) / -2, NSWidth(aRect), NSHeight(aRect)) enabled:(!_item || [_item isEnabled]) highlighted:highlighted];
	[NSGraphicsContext restoreGraphicsState];
}
- (NSSize)cellSize
{
	return NSMakeSize(16.0f, 16.0f);
}
- (NSPoint)cellBaselineOffset
{
	return NSMakePoint(0.0f, -3.0f);
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

- (void)drawWithFrame:(NSRect)aRect
        inView:(NSView *)aView
{
	[NSGraphicsContext saveGraphicsState];
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
	[[self image] setFlipped:YES];
	[[self image] drawInRect:aRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f];
	[NSGraphicsContext restoreGraphicsState];
}
- (NSSize)cellSize
{
	return NSMakeSize(16.0f, 16.0f);
}
- (NSPoint)cellBaselineOffset
{
	return NSMakePoint(0.0f, -3.0f);
}

#pragma mark NSCell

- (id)initImageCell:(NSImage *)anImage
{
	if(!(self = [super initImageCell:anImage])) return nil;
	if(!anImage || !PGIsTigerOrLater()) {
		[self release];
		return nil;
	}
	PGEnsureWindowCreatedHack();
	return self;
}

@end
