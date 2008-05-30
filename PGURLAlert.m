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
#import "PGURLAlert.h"

// Other
#import "PGZooming.h"

// Categories
#import "NSURLAdditions.h"

@implementation PGURLAlert

#pragma mark Instance Methods

- (IBAction)ok:(id)sender
{
	[NSApp stopModalWithCode:NSAlertFirstButtonReturn];
}
- (IBAction)cancel:(id)sender
{
	[NSApp stopModalWithCode:NSAlertSecondButtonReturn];
}

#pragma mark -

- (NSURL *)runModal
{
	BOOL const canceled = [NSApp runModalForWindow:[self window]] == NSAlertSecondButtonReturn;
	[[self window] close];
	if(canceled) return nil;
	return [NSURL AE_URLWithString:[URLField stringValue]];
}

#pragma mark NSControlSubclassNotifications Protocol

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[OKButton setEnabled:[NSURL AE_URLWithString:[URLField stringValue]] != nil];
}

#pragma mark NSWindowDelegate Protocol

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
          defaultFrame:(NSRect)defaultFrame
{
	return [window PG_zoomedRectWithDefaultFrame:defaultFrame];
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self controlTextDidChange:nil];
}

#pragma mark NSObject

- (id)init
{
	return [self initWithWindowNibName:@"PGURL"];
}

@end
