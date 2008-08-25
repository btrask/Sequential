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
	if(flag) [super showWindow:self];
	else [[self window] performClose:self];
}
- (void)toggleShown
{
	[self setShown:![self isShown]];
}

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
