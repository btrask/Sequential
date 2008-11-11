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
