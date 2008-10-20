/*
HMBlkContentView.m

Author: Makoto Kinoshita

Copyright 2004-2006 The Shiira Project. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted 
provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice, this list of conditions 
  and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright notice, this list of 
  conditions and the following disclaimer in the documentation and/or other materials provided 
  with the distribution.

THIS SOFTWARE IS PROVIDED BY THE SHIIRA PROJECT ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, 
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE SHIIRA PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
POSSIBILITY OF SUCH DAMAGE.
*/
#import "HMBlkContentView.h"
#import "HMAppKitEx.h"

@implementation HMBlkContentView

static NSImage* _leftBottomImage = nil;
static NSImage* _leftMiddleImage = nil;
static NSImage* _leftTopImage = nil;
static NSImage* _middleBottomImage = nil;
static NSImage* _middleTopImage = nil;
static NSImage* _rightMiddleImage = nil;
static NSImage* _rightTopImage = nil;

static NSRect   _leftBottomRect = {{0, 0}, {0, 0}};
static NSRect   _leftMiddleRect = {{0, 0}, {0, 0}};
static NSRect   _leftTopRect = {{0, 0}, {0, 0}};
static NSRect   _middleBottomRect = {{0, 0}, {0, 0}};
static NSRect   _middleTopRect = {{0, 0}, {0, 0}};
static NSRect   _rightMiddleRect = {{0, 0}, {0, 0}};
static NSRect   _rightTopRect = {{0, 0}, {0, 0}};

#pragma mark Class Methods

+ (void)initialize
{
	if([HMBlkContentView class] != self) return;
	NSBundle *const bundle = [NSBundle bundleForClass:self];

	_leftBottomImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"blkPanelLB"]];
	_leftMiddleImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"blkPanelLM"]];
	_leftTopImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"blkPanelLT"]];
	_middleBottomImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"blkPanelMB"]];
	_middleTopImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"blkPanelMT"]];
	_rightMiddleImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"blkPanelRM"]];
	_rightTopImage = [[NSImage alloc] initWithContentsOfFile:[bundle pathForImageResource:@"blkPanelRT"]];

	_leftBottomRect.size = [_leftBottomImage size];
	_leftMiddleRect.size = [_leftMiddleImage size];
	_leftTopRect.size = [_leftTopImage size];
	_middleBottomRect.size = [_middleBottomImage size];
	_middleTopRect.size = [_middleTopImage size];
	_rightMiddleRect.size = [_rightMiddleImage size];
	_rightTopRect.size = [_rightTopImage size];
}

#pragma mark NSView

- (BOOL)isOpaque
{
	return YES;
}
- (void)drawRect:(NSRect)rect
{
	NSRect frame = [self frame];
	NSRect imageRect;
	NSImage *const rightBottomImage = [NSImage HM_imageNamed:([[self window] isResizable] ? @"blkPanelRBResizable" : @"blkPanelRB") for:self flipped:NO];
	NSRect rightBottomRect = (NSRect){NSZeroPoint, [rightBottomImage size]};

	// Draw left bottom
	imageRect.origin = NSZeroPoint;
	imageRect.size = _leftBottomRect.size;
	if (NSIntersectsRect(imageRect, rect)) {
		[_leftBottomImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
	}

	// Draw left middle
	imageRect.origin.x = 0;
	imageRect.origin.y = _leftBottomRect.size.height;
	imageRect.size.width = _leftMiddleRect.size.width;
	imageRect.size.height = frame.size.height - _leftBottomRect.size.height - _leftTopRect.size.height;
	if (NSIntersectsRect(imageRect, rect)) {
		[_leftMiddleImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
	}

	// Draw left top
	imageRect.origin.x = 0;
	imageRect.origin.y = frame.size.height - _leftTopRect.size.height;
	imageRect.size = _leftTopRect.size;
	if (NSIntersectsRect(imageRect, rect)) {
		[_leftTopImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
	}

	// Draw middle bottom
	imageRect.origin.x = _leftBottomRect.size.width;
	imageRect.origin.y = 0;
	imageRect.size.width = frame.size.width - _leftBottomRect.size.width - rightBottomRect.size.width;
	imageRect.size.height = _middleBottomRect.size.height;
	if (NSIntersectsRect(imageRect, rect)) {
		[_middleBottomImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
	}

	// Draw middle middle
	[[NSColor colorWithDeviceWhite:(48.0f / 255.0f) alpha:(227.0f / 255.0f)] set];
	NSRectFill(NSIntersectionRect(NSMakeRect(NSWidth(_leftMiddleRect), NSHeight(_middleBottomRect), NSWidth(frame) - NSWidth(_leftMiddleRect) - NSWidth(_rightMiddleRect), NSHeight(frame) - NSHeight(_middleBottomRect) - NSHeight(_middleTopRect)), rect));

	// Draw middle top
	imageRect.origin.x = _leftTopRect.size.width;
	imageRect.origin.y = frame.size.height - _middleTopRect.size.height;
	imageRect.size.width = frame.size.width - _leftTopRect.size.width - _rightTopRect.size.width;
	imageRect.size.height = _middleTopRect.size.height;
	if (NSIntersectsRect(imageRect, rect)) {
		[_middleTopImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
	}

	// Draw right bottom
	imageRect.origin.x = frame.size.width - rightBottomRect.size.width;
	imageRect.origin.y = 0;
	imageRect.size.width = rightBottomRect.size.width;
	imageRect.size.height = rightBottomRect.size.height;
	if(NSIntersectsRect(imageRect, rect)) {
		[rightBottomImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
	}

	// Draw right middle
	imageRect.origin.x = frame.size.width - _rightMiddleRect.size.width;
	imageRect.origin.y = rightBottomRect.size.height;
	imageRect.size.width = _rightMiddleRect.size.width;
	imageRect.size.height = frame.size.height - rightBottomRect.size.height - _rightTopRect.size.height;
	if (NSIntersectsRect(imageRect, rect)) {
		[_rightMiddleImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
	}

	// Draw right top
	imageRect.origin.x = frame.size.width - _rightTopRect.size.width;
	imageRect.origin.y = frame.size.height - _rightTopRect.size.height;
	imageRect.size.width = _rightTopRect.size.width;
	imageRect.size.height = _rightTopRect.size.height;
	if (NSIntersectsRect(imageRect, rect)) {
		[_rightTopImage drawInRect:imageRect fromRect:NSZeroRect operation:NSCompositeCopy fraction:1.0f];
	}

	static NSDictionary *attrs = nil;
	if(!attrs) {
		NSMutableParagraphStyle *const style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
		[style setAlignment:NSCenterTextAlignment];
		[style setLineBreakMode:NSLineBreakByTruncatingTail];
		attrs = [[NSDictionary alloc] initWithObjectsAndKeys:
			[NSFont systemFontOfSize:11.0f], NSFontAttributeName, 
			[NSColor colorWithCalibratedWhite:1.0f alpha:0.8f], NSForegroundColorAttributeName, 
			style, NSParagraphStyleAttributeName, nil];
	}
	[[[self window] title] drawInRect:NSMakeRect(36, NSHeight(frame) - 22, NSWidth(frame) - 72, 16) withAttributes:attrs];
}
- (BOOL)acceptsFirstMouse:(NSEvent *)anEvent
{
	return YES;
}

#pragma mark NSResponder

- (void)mouseDown:(NSEvent*)anEvent
{
	NSRect const b = [self bounds];
	NSPoint const mousePoint = [self convertPoint:[anEvent locationInWindow] fromView:nil];
	NSWindow *const w = [self window];
	if([self mouse:mousePoint inRect:NSMakeRect(8, 12, NSWidth(b) - 16, NSHeight(b) - 16)] && ![w HM_trackResize:[w isResizable] && [self mouse:mousePoint inRect:[[self window] HM_resizeRectForView:self]] withEvent:anEvent]) [w makeFirstResponder:self];
}

@end
