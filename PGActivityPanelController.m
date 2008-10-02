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
#import "PGActivityPanelController.h"

// Models
#import "PGURLConnection.h"

// Views
#import "PGProgressIndicatorCell.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSObjectAdditions.h"

@interface PGActivityPanelController (Private)

- (void)_updateOnTimer:(NSTimer *)timer;

@end

@implementation PGActivityPanelController

#pragma mark Instance Methods

- (IBAction)cancelLoad:(id)sender
{
	NSMutableArray *const canceledConnections = [NSMutableArray array];
	NSIndexSet *const indexes = [activityTable selectedRowIndexes];
	unsigned i = [indexes firstIndex];
	for(; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) [canceledConnections addObject:[[PGURLConnection connections] objectAtIndex:i]];
	[canceledConnections makeObjectsPerformSelector:@selector(cancel)];
}

#pragma mark Private Protocol

- (void)_updateOnTimer:(NSTimer *)timer
{
	[activityTable reloadData];
}

#pragma mark NSTableDataSource Protocol

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [[PGURLConnection connections] count];
}
- (id)tableView:(NSTableView *)tableView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
      row:(int)row
{
	PGURLConnection *const connection = [[PGURLConnection connections] objectAtIndex:row];
	if(tableColumn == identifierColumn) {
		static NSDictionary *attrs = nil;
		if(!attrs) {
			NSMutableParagraphStyle *const style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
			[style setTighteningFactorForTruncation:0.3];
			[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
			attrs = [[NSDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
		}
		return [[[NSAttributedString alloc] initWithString:[[[connection request] URL] absoluteString] attributes:attrs] autorelease];
	} else if(tableColumn == progressColumn) {
		return [NSNumber numberWithFloat:[connection progress]];
	}
	return nil;
}

#pragma mark NSTableViewDelegate Protocol

- (void)tableView:(NSTableView *)tableView
        willDisplayCell:(id)cell
        forTableColumn:(NSTableColumn *)tableColumn
        row:(int)row
{
	if(tableColumn == progressColumn) [cell setHidden:((unsigned)row >= [[PGURLConnection activeConnections] count])];
}

#pragma mark NSTableViewNotifications Protocol

- (void)tableViewSelectionDidChange:(NSNotification *)aNotif
{
	[cancelButton setEnabled:[[activityTable selectedRowIndexes] count] > 0];
}

#pragma mark PGFloatingPanelController

- (void)windowWillShow
{
	_updateTimer = [NSTimer timerWithTimeInterval:(1.0 / 12.0) target:self selector:@selector(_updateOnTimer:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:_updateTimer forMode:PGCommonRunLoopsMode];
}
- (void)windowDidClose
{
	[_updateTimer invalidate];
	_updateTimer = nil;
}

- (NSString *)nibName
{
	return @"PGActivity";
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	[progressColumn setDataCell:[[[PGProgressIndicatorCell alloc] init] autorelease]];
	[self tableViewSelectionDidChange:nil];
}

#pragma mark NSObject

- (void)dealloc
{
	[self windowDidClose];
	[super dealloc];
}

@end
