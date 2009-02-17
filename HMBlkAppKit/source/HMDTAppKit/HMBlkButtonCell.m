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
#import "HMBlkButtonCell.h"
#import "HMAppKitEx.h"

@implementation HMBlkButtonCell

- (void)drawWithFrame:(NSRect)r
	inView:(NSView *)aView
{
	BOOL const f = [aView isFlipped];
	NSImage *const left = [NSImage HM_imageNamed:([self isHighlighted] ? @"button-left-hilite" : @"button-left") for:self flipped:f];
	[left drawInRect:NSMakeRect(NSMinX(r), NSMinY(r), [left size].width, [left size].height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];
	NSImage *const right = [NSImage HM_imageNamed:([self isHighlighted] ? @"button-right-hilite" : @"button-right") for:self flipped:f];
	[right drawInRect:NSMakeRect(NSMaxX(r) - [right size].width, NSMinY(r), [right size].width, [right size].height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];

	NSImage *const middle = [NSImage HM_imageNamed:([self isHighlighted] ? @"button-middle-hilite" : @"button-middle") for:self flipped:f];
	[middle drawInRect:NSMakeRect(NSMinX(r) + [left size].width, NSMinY(r), NSWidth(r) - [left size].width - [right size].width, [middle size].height) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1];

	[self drawInteriorWithFrame:r inView:aView];
}
- (void)drawInteriorWithFrame:(NSRect)r
        inView:(NSView *)aView
{
	NSMutableAttributedString *const title = [[[self attributedTitle] mutableCopy] autorelease];
	NSRange const titleRange = NSMakeRange(0, [title length]);
	NSShadow *const shadow = [[[NSShadow alloc] init] autorelease];
	[shadow setShadowOffset:NSMakeSize(0, 1)];
	[shadow setShadowBlurRadius:1];
	[title addAttribute:NSShadowAttributeName value:shadow range:titleRange];
	[title addAttribute:NSForegroundColorAttributeName value:([self isEnabled] ? [NSColor whiteColor] : [NSColor disabledControlTextColor]) range:titleRange];
	float const height = [title size].height;
	[title drawInRect:NSMakeRect(NSMinX(r), floorf(NSMidY(r) - height / 2), NSWidth(r), height)];
}

@end
