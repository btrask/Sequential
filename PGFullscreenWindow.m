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
#import "PGFullscreenWindow.h"

// Categories
#import "NSWindowAdditions.h"

@implementation PGFullscreenWindow

#pragma mark Instance Methods

- (id)initWithScreen:(NSScreen *)anObject
{
	if((self = [super initWithContentRect:(anObject ? [anObject frame] : NSZeroRect) styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES])) {
		[self setHasShadow:NO];
	}
	return self;
}
- (void)moveToScreen:(NSScreen *)anObject
{
	if(anObject) [self setFrame:[anObject frame] display:YES];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
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
