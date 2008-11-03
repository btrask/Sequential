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
#import "PGDocumentWindow.h"

// Views
#import "PGBezelPanel.h"
#import "PGDragHighlightView.h"

@implementation PGDocumentWindow

#pragma mark NSDraggingDestination Protocol

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
	NSDragOperation const op = [[self delegate] window:self dragOperationForInfo:sender];
	if(NSDragOperationNone == op) return NSDragOperationNone;
	_dragHighlightPanel = [[PGDragHighlightView PG_bezelPanel] retain];
	[_dragHighlightPanel displayOverWindow:self];
	return op;
}
- (void)draggingExited:(id<NSDraggingInfo>)sender
{
	[[_dragHighlightPanel autorelease] fadeOut];
	_dragHighlightPanel = nil;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	[self draggingExited:nil];
	return [[self delegate] window:self performDragOperation:sender];
}
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[self draggingExited:nil]; // Just in case.
}

#pragma mark NSKeyboardUI Protocol

- (void)selectKeyViewFollowingView:(NSView *)aView
{
	[super selectKeyViewFollowingView:aView];
	if([[self firstResponder] isKindOfClass:[NSView class]] && [(NSView *)[self firstResponder] isDescendantOf:[self initialFirstResponder]]) [[self delegate] selectNextOutOfWindowKeyView:self];
}
- (void)selectKeyViewPrecedingView:(NSView *)aView
{
	if([aView isDescendantOf:[self initialFirstResponder]]) [[self delegate] selectPreviousOutOfWindowKeyView:self];
	[super selectKeyViewPrecedingView:aView];
}

#pragma mark NSObject

- (void)dealloc
{
	[_dragHighlightPanel release];
	[super dealloc];
}

@end

@implementation NSObject (PGDocumentWindowDelegate)

- (NSDragOperation)window:(PGDocumentWindow *)window
                   dragOperationForInfo:(id<NSDraggingInfo>)info
{
	return NSDragOperationNone;
}
- (BOOL)window:(PGDocumentWindow *)window
        performDragOperation:(id<NSDraggingInfo>)info
{
	return NO;
}
- (void)selectNextOutOfWindowKeyView:(NSWindow *)window {}
- (void)selectPreviousOutOfWindowKeyView:(NSWindow *)window {}

@end
