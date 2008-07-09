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
#import "PGFloatingPanel.h"

// Models
#import "PGNode.h"

// Controllers
#import "PGDisplayController.h"

// Categories
#import "NSObjectAdditions.h"

@interface PGFloatingPanel (Private)

- (void)_updateNode:(PGDisplayController *)controller;

@end

@implementation PGFloatingPanel

- (PGNode *)node
{
	return [[_node retain] autorelease];
}
- (void)nodeChanged {}

#pragma mark -

- (void)displayControllerActiveNodeDidChange:(NSNotification *)aNotif
{
	[self _updateNode:nil];
}
- (void)windowDidBecomeMain:(NSNotification *)aNotif
{
	PGDisplayController *const c = aNotif ? [[aNotif object] windowController] : [[NSApp mainWindow] windowController];
	[c AE_addObserver:self selector:@selector(displayControllerActiveNodeDidChange:) name:PGDisplayControllerActiveNodeDidChangeNotification];
	[self _updateNode:c];
}
- (void)windowDidResignMain:(NSNotification *)aNotif
{
	[[[aNotif object] windowController] AE_removeObserver:self name:PGDisplayControllerActiveNodeDidChangeNotification];
	[self _updateNode:nil];
}

#pragma mark Private Protocol

- (void)_updateNode:(PGDisplayController *)controller
{
	PGDisplayController *const c = controller ? controller : [[NSApp mainWindow] windowController];
	[_node release];
	_node = [c respondsToSelector:@selector(activeNode)] ? [[c activeNode] retain] : nil;
	[self nodeChanged];
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
- (BOOL)shouldCascadeWindows
{
	return NO;
}
- (void)windowDidLoad
{
	[super windowDidLoad];
	[self windowDidBecomeMain:nil];
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[_node release];
	[super dealloc];
}

@end
