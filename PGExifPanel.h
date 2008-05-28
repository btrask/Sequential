#import <Cocoa/Cocoa.h>
#import "PGFloatingPanel.h"

@interface PGExifPanel : PGFloatingPanel
{
	IBOutlet NSTableView   *entriesTable;
	IBOutlet NSTableColumn *tagColumn;
	IBOutlet NSTableColumn *valueColumn;
	IBOutlet NSSearchField *searchField;
	         NSArray      *_allEntries;
	         NSArray      *_matchingEntries;
}

- (IBAction)changeSearch:(id)sender;

@end
