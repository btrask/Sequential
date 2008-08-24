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
#import "PGNode.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSScreenAdditions.h"
#import "NSWindowAdditions.h"

// Other
#import "PGZooming.h"

static NSString *const PGMainWindowFrameKey = @"PGMainWindowFrame";

@implementation PGWindowController

#pragma mark NSWindowNotifications Protocol

- (void)windowDidResize:(NSNotification *)notification
{
	if(!_shouldZoomOnNextImageLoad) [[NSUserDefaults standardUserDefaults] setObject:[[self window] stringWithSavedFrame] forKey:PGMainWindowFrameKey];
}
- (void)windowDidMove:(NSNotification *)notification
{
	[self windowDidResize:nil];
}

#pragma mark NSWindowDelegate Protocol

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
          defaultFrame:(NSRect)newFrame
{
	return [window PG_zoomedFrame];
}

#pragma mark PGDisplayController

- (BOOL)setActiveDocument:(PGDocument *)document
        closeIfAppropriate:(BOOL)flag
{
	[[self activeDocument] storeWindowFrame:[[self window] AE_contentRect]];
	if([super setActiveDocument:document closeIfAppropriate:flag]) return YES;
	NSRect frame;
	if([[self activeDocument] getStoredWindowFrame:&frame]) {
		[[self window] AE_setContentRect:frame];
		_shouldZoomOnNextImageLoad = NO;
	}
	return NO;
}
- (void)activateDocument:(PGDocument *)document
{
	NSParameterAssert([self activeDocument] == document);
	[[self window] makeKeyAndOrderFront:self];
}

#pragma mark -

- (void)nodeReadyForViewing:(NSNotification *)aNotif
{
	[super nodeReadyForViewing:aNotif];
	if(!_shouldZoomOnNextImageLoad) return;
	if(![[aNotif userInfo] objectForKey:PGImageRepKey]) return;
	[[self window] setFrame:[[self window] PG_zoomedFrame] display:YES]; // Don't just send -zoom: because that will use the user size if the window is already the system size.
	[clipView scrollToLocation:_initialLocation allowAnimation:NO];
	_shouldZoomOnNextImageLoad = NO;
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	NSWindow *const window = [self window];
	NSString *const savedFrame = [[NSUserDefaults standardUserDefaults] objectForKey:PGMainWindowFrameKey];
	if(savedFrame) [window setFrameFromString:savedFrame];
	else {
		[window setFrame:NSMakeRect(0, 0, 500, 500) display:NO];
		[window center];
	}
	_shouldZoomOnNextImageLoad = [[[NSUserDefaults standardUserDefaults] objectForKey:PGAutozoomsWindowsKey] boolValue];
}

@end
