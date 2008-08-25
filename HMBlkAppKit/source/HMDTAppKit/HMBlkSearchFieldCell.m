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
#import "HMBlkSearchFieldCell.h"
#import "HMAppKitEx.h"
#import "HMBlkPanel.h"

@implementation HMBlkSearchFieldCell

#pragma mark NSNibAwaking Protocol

- (void)awakeFromNib
{
	NSImage *const searchIcon = [NSImage HM_imageNamed:@"search-icon" for:self flipped:NO];
	[[self searchButtonCell] setImage:searchIcon];
	[[self searchButtonCell] setAlternateImage:searchIcon];
	[[self cancelButtonCell] setImage:[NSImage HM_imageNamed:@"search-cancel" for:self flipped:NO]];
	[[self cancelButtonCell] setAlternateImage:[NSImage HM_imageNamed:@"search-cancel-hilite" for:self flipped:NO]];
	[self setBackgroundColor:[NSColor colorWithDeviceWhite:0.25 alpha:0.8]];
}

#pragma mark NSTextFieldCell

- (NSText *)setUpFieldEditorAttributes:(NSText *)textObj
{
	NSText *const t = [super setUpFieldEditorAttributes:textObj];
	if([t respondsToSelector:@selector(setInsertionPointColor:)]) [(NSTextView *)t setInsertionPointColor:[NSColor whiteColor]];
	return t;
}

#pragma mark NSCell

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view
{
	NSRect const f = NSInsetRect(frame, 0.5, 0.5);
	float const r = NSHeight(f) / 2;
	NSBezierPath *const path = [NSBezierPath bezierPath];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(f) + r, NSMinY(f) + r) radius:r startAngle:90 endAngle:270];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(f) - r, NSMinY(f) + r) radius:r startAngle:270 endAngle:90];
	[path closePath];
	NSWindow *const window = [view window];
	id const responder = [window firstResponder];
	if([window isKeyWindow] && [responder isKindOfClass:[NSView class]] && [(NSView *)responder isDescendantOf:view]) {
		[NSGraphicsContext saveGraphicsState];
		NSSetFocusRingStyle(NSFocusRingOnly);
		[path stroke];
		[NSGraphicsContext restoreGraphicsState];
	}
	[NSGraphicsContext saveGraphicsState];
	[path addClip];
	[[self backgroundColor] set];
	NSRectFill(frame); // Use NSCompositeCopy.
	[NSGraphicsContext restoreGraphicsState];
	[[HMBlkPanel majorGridColor] set];
	[path stroke];
	[self drawInteriorWithFrame:frame inView:view];
}

@end
