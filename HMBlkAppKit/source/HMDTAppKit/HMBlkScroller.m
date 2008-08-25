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
#import "HMBlkScroller.h"
#import "HMAppKitEx.h"

@implementation HMBlkScroller

#pragma mark NSScroller

- (void)drawKnobSlotInRect:(NSRect)rect
        highlight:(BOOL)flag
{
	[[NSImage HM_imageNamed:@"scroller-vert-track" for:self flipped:NO] drawInRect:rect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
}
- (void)drawArrow:(int)top
		highlightPart:(int)pressedArrow
{
	NSString *variant = [[NSUserDefaults standardUserDefaults] objectForKey:@"AppleScrollBarVariant"];
	if(!variant) variant = @"DoubleMax";
	if(top) {
		if([@"DoubleBoth" isEqualToString:variant] || [@"DoubleMin" isEqualToString:variant]) {
			[[NSImage HM_imageNamed:(pressedArrow == 1 ? @"scroller-vert-outer-hilite" : @"scroller-vert-outer") for:self flipped:NO] drawInRect:NSMakeRect(0, 0, 15, 17) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
			[[NSImage HM_imageNamed:(pressedArrow == 0 ? @"scroller-vert-inner-hilite" : @"scroller-vert-inner") for:self flipped:NO] drawInRect:NSMakeRect(0, 17, 15, 24) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
		} else if([@"Single" isEqualToString:variant]) {
			[[NSImage HM_imageNamed:(pressedArrow != -1 ? @"scroller-vert-end-hilite" : @"scroller-vert-end") for:self flipped:YES] drawInRect:NSMakeRect(0, 0, 15, 24) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
		} else {
			[[NSImage HM_imageNamed:@"scroller-vert-cap" for:self flipped:YES] drawInRect:NSMakeRect(0, 0, 15, 14) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
		}
	} else {
		float const h = NSMaxY([self bounds]);
		if([@"DoubleBoth" isEqualToString:variant] || [@"DoubleMax" isEqualToString:variant]) {
			[[NSImage HM_imageNamed:(pressedArrow == 0 ? @"scroller-vert-outer-hilite" : @"scroller-vert-outer") for:self flipped:YES] drawInRect:NSMakeRect(0, h - 17, 15, 17) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
			[[NSImage HM_imageNamed:(pressedArrow == 1 ? @"scroller-vert-inner-hilite" : @"scroller-vert-inner") for:self flipped:YES] drawInRect:NSMakeRect(0, h - 41, 15, 24) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
		} else if([@"Single" isEqualToString:variant]) {
			[[NSImage HM_imageNamed:(pressedArrow != -1 ? @"scroller-vert-end-hilite" : @"scroller-vert-end") for:self flipped:NO] drawInRect:NSMakeRect(0, h - 24, 15, 24) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
		} else {
			[[NSImage HM_imageNamed:@"scroller-vert-cap" for:self flipped:NO] drawInRect:NSMakeRect(0, h - 14, 15, 14) fromRect:NSZeroRect operation:NSCompositeCopy fraction:1];
		}
	}
}
- (void)drawKnob
{
	NSRect const r = [self rectForPart:NSScrollerKnob];
	[[NSImage HM_imageNamed:@"blkScrollerKnobVT" for:self flipped:YES] drawInRect:NSMakeRect(1, NSMinY(r) + 3, 13, 6) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f];
	[[NSImage HM_imageNamed:@"blkScrollerKnobVM" for:self flipped:YES] drawInRect:NSMakeRect(1, NSMinY(r) + 9, 13, NSHeight(r) - 18) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f];
	[[NSImage HM_imageNamed:@"blkScrollerKnobVB" for:self flipped:YES] drawInRect:NSMakeRect(1, NSMaxY(r) - 9, 13, 6) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f];
}

#pragma mark NSView

- (BOOL)isFlipped
{
	return YES; // Just to be sure.
}

@end
