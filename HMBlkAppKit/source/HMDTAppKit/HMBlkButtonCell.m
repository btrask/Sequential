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
