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
