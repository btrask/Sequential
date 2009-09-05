/* Copyright © 2007-2009, The Sequential Project
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

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGActivityPanelController.h"

// Models
#import "PGLoading.h"

// Views
#import "PGProgressIndicatorCell.h"

// Other
#import "PGDelayedPerforming.h"
#import "PGGeometry.h"

// Categories
#import "NSObjectAdditions.h"

@interface PGActivityPanelController(Private)

- (void)_update;

@end

@implementation PGActivityPanelController

#pragma mark -PGActivityPanelController

- (IBAction)cancelLoad:(id)sender
{
	NSIndexSet *const indexes = [activityOutline selectedRowIndexes];
	NSUInteger i = [indexes firstIndex];
	for(; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) [[activityOutline itemAtRow:i] cancelLoad];
}

#pragma mark -PGActivityPanelController(Private)

- (void)_update
{
	[activityOutline reloadData];
	[activityOutline expandItem:nil expandChildren:YES];
}

#pragma mark -NSObject(NSOutlineViewNotifications)

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[cancelButton setEnabled:[[activityOutline selectedRowIndexes] count] > 0];
}

#pragma mark -PGFloatingPanelController

- (NSString *)nibName
{
	return @"PGActivity";
}
- (void)windowWillShow
{
	_updateTimer = [[self PG_performSelector:@selector(_update) withObject:nil fireDate:nil interval:PGAnimationFramerate / 2.0f options:PGRetainTarget] retain];
	[self _update];
}
- (void)windowDidClose
{
	[_updateTimer invalidate];
	[_updateTimer release];
	_updateTimer = nil;
}

#pragma mark -NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	[progressColumn setDataCell:[[[PGProgressIndicatorCell alloc] init] autorelease]];
	[self outlineViewSelectionDidChange:nil];
}

#pragma mark -NSObject

- (void)dealloc
{
	[self windowDidClose];
	[super dealloc];
}

#pragma mark -<NSOutlineViewDataSource>

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return item ? [[item subloads] count] > 0 : YES;
}
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	return [[(item ? item : [PGLoadManager sharedLoadManager]) subloads] count];
}
- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	return [[(item ? item : [PGLoadManager sharedLoadManager]) subloads] objectAtIndex:index];
}
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	if(tableColumn == identifierColumn) {
		static NSDictionary *attrs = nil;
		if(!attrs) {
			NSMutableParagraphStyle *const style = [[[NSParagraphStyle defaultParagraphStyle] mutableCopy] autorelease];
			[style setTighteningFactorForTruncation:0.3f];
			[style setLineBreakMode:NSLineBreakByTruncatingMiddle];
			attrs = [[NSDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
		}
		return [[[NSAttributedString alloc] initWithString:[item loadDescription] attributes:attrs] autorelease];
	} else if(tableColumn == progressColumn) {
		return [NSNumber numberWithDouble:[item loadProgress]];
	}
	return nil;
}

#pragma mark -<NSOutlineViewDelegate>

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if(tableColumn == progressColumn) [cell setHidden:![item loadProgress] || [[item subloads] count]];
}

@end
