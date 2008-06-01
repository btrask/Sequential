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
#import "PGWindowController.h"

// Models
#import "PGDocument.h"

// Categories
#import "NSWindowAdditions.h"

// Other
#import "PGZooming.h"

static NSString *const PGMainWindowFrameKey = @"PGMainWindowFrame";

@implementation PGWindowController

#pragma mark NSWindowNotifications Protocol

- (void)windowDidResize:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] setObject:[[self window] stringWithSavedFrame] forKey:PGMainWindowFrameKey];
}
- (void)windowDidMove:(NSNotification *)notification
{
	[self windowDidResize:nil];
}

#pragma mark NSWindowDelegate Protocol

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
          defaultFrame:(NSRect)newFrame
{
	return [window PG_zoomedRectWithDefaultFrame:newFrame];
}

#pragma mark PGDisplayController

- (BOOL)setActiveDocument:(PGDocument *)document
        closeIfAppropriate:(BOOL)flag
{
	[[self activeDocument] storeWindowFrame:[[self window] AE_contentRect]];
	if([super setActiveDocument:document closeIfAppropriate:flag]) return YES;
	NSRect frame;
	if([[self activeDocument] getStoredWindowFrame:&frame]) [[self window] AE_setContentRect:frame];
	return NO;
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	NSString *const savedFrame = [[NSUserDefaults standardUserDefaults] objectForKey:PGMainWindowFrameKey];
	if(savedFrame) [[self window] setFrameFromString:savedFrame];
	else {
		[[self window] setFrame:NSMakeRect(0, 0, 500, 500) display:NO];
		[[self window] center];
	}
}

@end
