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
#import "PGExifPanelController.h"

// Models
#import "PGNode.h"
#import "PGExifEntry.h"

// Controllers
#import "PGDocumentController.h"
#import "PGDisplayController.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

@implementation PGExifPanelController

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

#pragma mark -

- (void)displayControllerActiveNodeDidChange:(NSNotification *)aNotif
{
	[_allEntries release];
	_allEntries = [[[[self displayController] activeNode] exifEntries] copy];
	[self changeSearch:nil];
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

#pragma mark PGFloatingPanelController

- (BOOL)setDisplayController:(PGDisplayController *)controller
{
	PGDisplayController *const oldController = [self displayController];
	if(![super setDisplayController:controller]) return NO;
	[oldController AE_removeObserver:self name:PGDisplayControllerActiveNodeDidChangeNotification];
	[[self displayController] AE_addObserver:self selector:@selector(displayControllerActiveNodeDidChange:) name:PGDisplayControllerActiveNodeDidChangeNotification];
	[self displayControllerActiveNodeDidChange:nil];
	return YES;
}
- (NSString *)nibName
{
	return @"PGExif";
}

#pragma mark NSObject

- (void)dealloc
{
	[entriesTable setDelegate:nil];
	[entriesTable setDataSource:nil];
	[_allEntries release];
	[_matchingEntries release];
	[super dealloc];
}

@end
