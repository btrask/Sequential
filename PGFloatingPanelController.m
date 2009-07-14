/* Copyright © 2007-2009, The Sequential Project
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
#import "PGFloatingPanelController.h"

// Models
#import "PGNode.h"

// Controllers
#import "PGDisplayController.h"

// Categories
#import "NSObjectAdditions.h"

@interface PGFloatingPanelController (Private)

- (void)_updateWithDisplayController:(PGDisplayController *)controller;

@end

@implementation PGFloatingPanelController

#pragma mark Instance Methods

- (BOOL)isShown
{
	return _shown;
}
- (void)setShown:(BOOL)flag
{
	if(flag == _shown) return;
	_shown = flag;
	if(flag) {
		[self windowWillShow];
		[super showWindow:self];
	} else {
		[[self window] performClose:self];
		[self windowDidClose];
	}
}
- (void)toggleShown
{
	[self setShown:![self isShown]];
}

#pragma mark -

- (void)windowWillShow {}
- (void)windowDidClose {}

#pragma mark -

- (PGDisplayController *)displayController
{
	return [[_displayController retain] autorelease];
}
- (BOOL)setDisplayController:(PGDisplayController *)controller
{
	if(controller == _displayController) return NO;
	[_displayController release];
	_displayController = [controller retain];
	return YES;
}

#pragma mark -

- (NSString *)nibName
{
	return nil;
}
- (NSString *)windowFrameAutosaveName
{
	NSString *const name = [self nibName];
	return name ? [NSString stringWithFormat:@"%@PanelFrame", name] : nil;
}

#pragma mark -

- (void)windowDidBecomeMain:(NSNotification *)aNotif
{
	[self _updateWithDisplayController:(aNotif ? [[aNotif object] windowController] : [[NSApp mainWindow] windowController])];
}
- (void)windowDidResignMain:(NSNotification *)aNotif
{
	[self _updateWithDisplayController:nil];
}

#pragma mark Private Protocol

- (void)_updateWithDisplayController:(PGDisplayController *)controller
{
	PGDisplayController *const c = controller ? controller : [[NSApp mainWindow] windowController];
	[self setDisplayController:[c isKindOfClass:[PGDisplayController class]] ? c : nil];
}

#pragma mark NSWindowNotifications Protocol

- (void)windowDidResize:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect([[self window] frame]) forKey:[self windowFrameAutosaveName]];
}
- (void)windowDidMove:(NSNotification *)notification
{
	[self windowDidResize:nil];
}

- (void)windowWillClose:(NSNotification *)aNotif
{
	_shown = NO;
}

#pragma mark NSWindowController

- (id)initWithWindowNibName:(NSString *)name
{
	if((self = [super initWithWindowNibName:name])) {
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidBecomeMain:) name:NSWindowDidBecomeMainNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResignMain:) name:NSWindowDidResignMainNotification object:nil];
	}
	return self;
}

#pragma mark -

- (IBAction)showWindow:(id)sender
{
	[self setShown:YES];
}

#pragma mark -

- (BOOL)shouldCascadeWindows
{
	return NO;
}
- (void)windowDidLoad
{
	[super windowDidLoad];
	[self windowDidBecomeMain:nil];
	NSString *const savedFrame = [[NSUserDefaults standardUserDefaults] objectForKey:[self windowFrameAutosaveName]]; // We can't use -setFrameFromString: because it doesn't seem to work with NSBorderlessWindowMask.
	if(savedFrame) [[self window] setFrame:NSRectFromString(savedFrame) display:YES];
}

#pragma mark NSObject

- (id)init
{
	return [self initWithWindowNibName:[self nibName]];
}
- (void)dealloc
{
	[self AE_removeObserver];
	[_displayController release];
	[super dealloc];
}

@end
