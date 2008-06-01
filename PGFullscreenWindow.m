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
#import "PGFullscreenWindow.h"

// Categories
#import "NSWindowAdditions.h"

@implementation PGFullscreenWindow

#pragma mark Instance Methods

- (id)initWithScreen:(NSScreen *)anObject
{
	if((self = [super initWithContentRect:[anObject frame] styleMask:(NSBorderlessWindowMask | AEUnscaledWindowMask) backing:NSBackingStoreBuffered defer:YES])) {
		[self setHasShadow:NO];
	}
	return self;
}
- (void)moveToScreen:(NSScreen *)anObject
{
	if(anObject) [self setFrame:[anObject frame] display:YES];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(id<NSMenuItem>)anItem
{
	return [anItem action] == @selector(performClose:) ? YES : [super validateMenuItem:anItem]; // NSWindow doesn't like -performClose: for borderless windows.
}

#pragma mark NSWindow

- (IBAction)performClose:(id)sender
{
	[[self delegate] closeWindowContent:self];
}

#pragma mark -

- (BOOL)canBecomeKeyWindow
{
	return YES;
}
- (BOOL)canBecomeMainWindow
{
	return [self isVisible]; // Return -isVisible because that's (the relevant part of) what NSWindow does.
}

@end

@implementation NSObject (PGFullscreenWindowDelegate)

- (void)closeWindowContent:(PGFullscreenWindow *)sender {}

@end
