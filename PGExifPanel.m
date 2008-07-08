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
#import "PGExifPanel.h"

// Models
#import "PGNode.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSStringAdditions.h"

static NSString *const PGExifWindowFrameKey = @"PGExifWindowFrame";

@implementation PGExifPanel

#pragma mark Instance Methods

- (IBAction)changeSearch:(id)sender
{
	NSMutableArray *const e = [NSMutableArray array];
	NSArray *const terms = [[searchField stringValue] AE_searchTerms];
	PGExifEntry *entry;
	NSEnumerator *const entryEnum = [_allEntries objectEnumerator];
	while((entry = [entryEnum nextObject])) if([[entry label] AE_matchesSearchTerms:terms] || [[entry value] AE_matchesSearchTerms:terms]) [e addObject:entry];
	[_matchingEntries release];
	_matchingEntries = [e retain];
	[entriesTable reloadData];
}
- (IBAction)copy:(id)sender
{
	NSMutableString *const string = [NSMutableString string];
	NSIndexSet *const indexes = [entriesTable selectedRowIndexes];
	unsigned i = [indexes firstIndex];
	for(; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) {
		PGExifEntry *const entry = [_matchingEntries objectAtIndex:i];
		[string appendFormat:@"%@: %@\n", [entry label], [entry value]];
	}
	NSPasteboard *const pboard = [NSPasteboard generalPasteboard];
	[pboard declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
	[pboard setString:string forType:NSStringPboardType];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	SEL const action = [anItem action];
	if(@selector(copy:) == action && ![[entriesTable selectedRowIndexes] count]) return NO;
	return [super validateMenuItem:anItem];
}

#pragma mark NSTableViewDelegate Protocol

- (void)tableView:(NSTableView *)tableView
		willDisplayCell:(id)cell
        forTableColumn:(NSTableColumn *)tableColumn
        row:(int)row
{
	if(tableColumn == tagColumn) {
		[cell setAlignment:NSRightTextAlignment];
		[cell setFont:[[NSFontManager sharedFontManager] convertFont:[cell font] toHaveTrait:NSBoldFontMask]];
	}
}

#pragma mark NSTableDataSource Protocol

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [_matchingEntries count];
}
- (id)tableView:(NSTableView *)tableView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
      row:(int)row
{
	PGExifEntry *const entry = [_matchingEntries objectAtIndex:row];
	if(tableColumn == tagColumn) {
		return [entry label];
	} else if(tableColumn == valueColumn) {
		return [entry value];
	}
	return nil;
}

#pragma mark NSWindowNotifications Protocol

- (void)windowDidResize:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect([[self window] frame]) forKey:PGExifWindowFrameKey];
}
- (void)windowDidMove:(NSNotification *)notification
{
	[self windowDidResize:nil];
}

- (void)windowWillClose:(NSNotification *)aNotif
{
	[[PGDocumentController sharedDocumentController] setExifShown:NO];
}

#pragma mark PGFloatingPanel

- (void)nodeChanged
{
	[_allEntries release];
	_allEntries = [[[self node] exifEntries] copy];
	[self changeSearch:nil];
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	NSString *const savedFrame = [[NSUserDefaults standardUserDefaults] objectForKey:PGExifWindowFrameKey]; // We can't use -setFrameFromString: because it doesn't seem to work with NSBorderlessWindowMask.
	if(savedFrame) [[self window] setFrame:NSRectFromString(savedFrame) display:YES];
	[self windowDidBecomeMain:nil];
}

#pragma mark NSObject

- (id)init
{
	return [self initWithWindowNibName:@"PGExif"];
}
- (void)dealloc
{
	[entriesTable setDelegate:nil];
	[entriesTable setDataSource:nil];
	[_allEntries release];
	[_matchingEntries release];
	[super dealloc];
}

@end
