/* Copyright © 2007-2008, The Sequential Project
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

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
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
