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
#import "PGActivityPanel.h"

// Controllers
#import "PGDocumentController.h"

static NSString *const PGActivityWindowFrameKey = @"PGActivityWindowFrame";

@implementation PGActivityPanel

#pragma mark NSTableDataSource Protocol

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return 5;
}
- (id)tableView:(NSTableView *)tableView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
      row:(int)row
{
	if(tableColumn == identifierColumn) {
		return [NSNumber numberWithInt:row + 1];
	} else if(tableColumn == progressColumn) {
		return [NSNumber numberWithInt:(row + 1) * 15];
	}
	return nil;
}

#pragma mark NSWindowNotifications Protocol

- (void)windowDidResize:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect([[self window] frame]) forKey:PGActivityWindowFrameKey];
}
- (void)windowDidMove:(NSNotification *)notification
{
	[self windowDidResize:nil];
}

- (void)windowWillClose:(NSNotification *)aNotif
{
	[[PGDocumentController sharedDocumentController] setActivityShown:NO];
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	NSString *const savedFrame = [[NSUserDefaults standardUserDefaults] objectForKey:PGActivityWindowFrameKey]; // We can't use -setFrameFromString: because it doesn't seem to work with NSBorderlessWindowMask.
	if(savedFrame) [[self window] setFrame:NSRectFromString(savedFrame) display:YES];
}

#pragma mark NSObject

- (id)init
{
	return [self initWithWindowNibName:@"PGActivity"];
}

@end
