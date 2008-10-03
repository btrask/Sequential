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
#import "PGLoading.h"

// Views
#import "PGProgressIndicatorCell.h"

// Categories
#import "NSObjectAdditions.h"

@interface PGActivityPanelController (Private)

- (void)_updateOnTimer:(NSTimer *)timer;

@end

@implementation PGActivityPanelController

#pragma mark Instance Methods

- (IBAction)cancelLoad:(id)sender
{
	NSIndexSet *const indexes = [activityOutline selectedRowIndexes];
	unsigned i = [indexes firstIndex];
	for(; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) [[activityOutline itemAtRow:i] cancelLoad];
}

#pragma mark Private Protocol

- (void)_updateOnTimer:(NSTimer *)timer
{
	[activityOutline reloadData];
	if(PGIsLeopardOrLater()) [activityOutline expandItem:nil expandChildren:YES];
	else {
		id load;
		NSEnumerator *const loadEnum = [[[PGLoadManager sharedLoadManager] subloads] objectEnumerator];
		while((load = [loadEnum nextObject])) [activityOutline expandItem:load expandChildren:YES];
	}
}

#pragma mark NSOutlineView Protocol

- (BOOL)outlineView:(NSOutlineView *)outlineView
        isItemExpandable:(id)item
{
	return item ? [[item subloads] count] > 0 : YES;
}
- (NSInteger)outlineView:(NSOutlineView *)outlineView
             numberOfChildrenOfItem:(id)item
{
	return [[(item ? item : [PGLoadManager sharedLoadManager]) subloads] count];
}
- (id)outlineView:(NSOutlineView *)outlineView
      child:(NSInteger)index
      ofItem:(id)item
{
	return [[(item ? item : [PGLoadManager sharedLoadManager]) subloads] objectAtIndex:index];
}
- (id)outlineView:(NSOutlineView *)outlineView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
      byItem:(id)item
{
	if(tableColumn == identifierColumn) {
		static NSDictionary *attrs = nil;
		if(!attrs) {
			NSMutableParagraphStyle *const style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
			[style setTighteningFactorForTruncation:0.3];
			[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
			attrs = [[NSDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
		}
		return [[[NSAttributedString alloc] initWithString:[item loadDescription] attributes:attrs] autorelease];
	} else if(tableColumn == progressColumn) {
		return [NSNumber numberWithFloat:[item loadProgress]];
	}
	return nil;
}

#pragma mark NSOutlineViewDelegate Protocol

- (void)outlineView:(NSOutlineView *)outlineView
        willDisplayCell:(id)cell
        forTableColumn:(NSTableColumn *)tableColumn
        item:(id)item
{
	if(tableColumn == progressColumn) [cell setHidden:(![item loadProgress] || [[item subloads] count])];
}

#pragma mark NSOutlineViewNotifications Protocol

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[cancelButton setEnabled:[[activityOutline selectedRowIndexes] count] > 0];
}

#pragma mark PGFloatingPanelController

- (void)windowWillShow
{
	_updateTimer = [NSTimer timerWithTimeInterval:(1.0 / 12.0) target:self selector:@selector(_updateOnTimer:) userInfo:nil repeats:YES];
	[[NSRunLoop currentRunLoop] addTimer:_updateTimer forMode:PGCommonRunLoopsMode];
	[self _updateOnTimer:nil];
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
	[self outlineViewSelectionDidChange:nil];
}

#pragma mark NSObject

- (void)dealloc
{
	[self windowDidClose];
	[super dealloc];
}

@end
