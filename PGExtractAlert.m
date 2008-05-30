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
#import "PGExtractAlert.h"

// Models
#import "PGNode.h"
#import "PGContainerAdapter.h"
#import "PGGenericImageAdapter.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

@implementation PGExtractAlert

#pragma mark Instance Methods

- (id)initWithRoot:(PGNode *)root
      initialNode:(PGNode *)aNode
{
	if(!(self = [super initWithWindowNibName:@"PGExtract"])) return nil;
	_rootNode = [root retain];
	_initialNode = [aNode retain];
	_saveNamesByNodePointer = [[NSMutableDictionary alloc] init];
	return self;
}
- (void)beginSheetForWindow:(NSWindow *)window
{
	(void)[self window];
	[_openPanel release];
	_openPanel = [[NSOpenPanel alloc] init];
	[_openPanel AE_addObserver:self selector:@selector(windowDidEndSheet:) name:NSWindowDidEndSheetNotification];
	[_openPanel setCanChooseFiles:NO];
	[_openPanel setCanChooseDirectories:YES];
	[_openPanel setCanCreateDirectories:YES];
	[_openPanel setAllowsMultipleSelection:NO];
	[_openPanel setDelegate:self];
	[_openPanel setAccessoryView:accessoryView];
	[_openPanel setPrompt:NSLocalizedString(@"Choose", nil)];
	[_openPanel setTitle:NSLocalizedString(@"Extract", nil)];
	[self retain];
	if(window) [_openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:window modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	else [self openPanelDidEnd:_openPanel returnCode:[_openPanel runModalForTypes:nil] contextInfo:NULL];
}
- (void)openPanelDidEnd:(NSOpenPanel *)panel
        returnCode:(int)returnCode
        contextInfo:(void *)contextInfo
{
	[panel orderOut:self];
	[_openPanel AE_removeObserver:self name:NSWindowDidEndSheetNotification];
	[_openPanel setDelegate:nil]; // This object should have a shorter lifespan than us, but for some reason it keeps sending us crap long after we've died unless we do this.
	[self release];
}

#pragma mark -

- (NSString *)saveNameForNode:(PGNode *)node
{
	NSString *const modifiedName = [_saveNamesByNodePointer objectForKey:[NSValue valueWithNonretainedObject:node]];
	return modifiedName ? [[modifiedName retain] autorelease] : [[node identifier] displayName];
}

#pragma mark -

- (BOOL)panel:(id)sender
        isValidFilename:(NSString *)filename
{
	unsigned existingFileCount = 0;
	NSString *existingFilename = nil;
	{
		NSIndexSet *const rows = [nodesOutline selectedRowIndexes];
		unsigned i = [rows firstIndex];
		for(; NSNotFound != i; i = [rows indexGreaterThanIndex:i]) {
			NSString *const name = [self saveNameForNode:[nodesOutline itemAtRow:i]];
			if(![[NSFileManager defaultManager] fileExistsAtPath:[_destination stringByAppendingPathComponent:name]]) continue;
			existingFileCount++;
			existingFilename = name;
		}
	}
	if(existingFileCount && !_extractOnSheetClose) {
		NSAlert *const alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSCriticalAlertStyle];
		if(1 == existingFileCount) [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%@ already exists in %@. Do you want to replace it?", nil), existingFilename, [_destination AE_displayName]]];
		else [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%u pages already exist in %@. Do you want to replace them?", nil), existingFileCount, [_destination AE_displayName]]];
		[alert setInformativeText:NSLocalizedString(@"Replacing a file overwrites its current contents.", nil)];
		[[alert addButtonWithTitle:NSLocalizedString(@"Replace", nil)] setKeyEquivalent:@""];
		[[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)] setKeyEquivalent:@"\r"];
		[alert beginSheetModalForWindow:_openPanel modalDelegate:self didEndSelector:@selector(replaceAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		return NO;
	}
	NSMutableArray *const unsavedNodes = [NSMutableArray array];
	NSMutableIndexSet *const unsavedRows = [NSMutableIndexSet indexSet];
	NSIndexSet *const rows = [[[nodesOutline selectedRowIndexes] copy] autorelease];
	unsigned i = [rows firstIndex];
	for(; NSNotFound != i; i = [rows indexGreaterThanIndex:i]) {
		id const node = [nodesOutline itemAtRow:i];
		NSData *data;
		if(PGDataAvailable == [node getImageData:&data] && [data writeToFile:[_destination stringByAppendingPathComponent:[self saveNameForNode:node]] atomically:NO]) continue;
		[unsavedNodes addObject:node];
		[unsavedRows addIndex:i];
	}
	if(![unsavedNodes count]) return YES;
	[nodesOutline reloadData];
	[nodesOutline selectRowIndexes:unsavedRows byExtendingSelection:NO];
	NSAlert *const alert = [[[NSAlert alloc] init] autorelease];
	if(1 == [unsavedNodes count]) [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"The page %@ could not be extracted to %@.", nil), [self saveNameForNode:[unsavedNodes objectAtIndex:0]], [_destination AE_displayName]]];
	else [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%u pages could not be extracted to %@.", nil), [unsavedNodes count], [_destination AE_displayName]]];
	[alert setInformativeText:NSLocalizedString(@"Make sure the volume is writable and has enough free space.", nil)];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
	[alert beginSheetModalForWindow:_openPanel modalDelegate:nil didEndSelector:NULL contextInfo:nil];
	return NO;
}

- (void)panel:(id)sender
        directoryDidChange:(NSString *)path
{
	[_destination release];
	_destination = [path retain];
	[nodesOutline reloadData];
	[nodesOutline expandItem:_rootNode expandChildren:YES];
	if(!_initialNode) return;
	unsigned const defaultRow = [nodesOutline rowForItem:_initialNode];
	if(NSNotFound != defaultRow) {
		[nodesOutline selectRowIndexes:[NSIndexSet indexSetWithIndex:defaultRow] byExtendingSelection:NO];
		[nodesOutline scrollRowToVisible:defaultRow];
	}
	[_initialNode release];
	_initialNode = nil;
}
- (void)replaceAlertDidEnd:(NSAlert *)alert
	returnCode:(int)returnCode
	contextInfo:(void *)contextInfo
{
	if(NSAlertFirstButtonReturn == returnCode) _extractOnSheetClose = YES;
}

#pragma mark NSWindowNotifications Protocol

- (void)windowDidEndSheet:(NSNotification *)notification
{
	if(!_extractOnSheetClose) return;
	[_openPanel ok:self];
	_extractOnSheetClose = NO;
}

#pragma mark NSOutlineViewDataSource Protocol

- (id)outlineView:(NSOutlineView *)outlineView
      child:(int)index
      ofItem:(id)item
{
	return item ? [[item sortedChildren] objectAtIndex:index] : _rootNode;
}
- (BOOL)outlineView:(NSOutlineView *)outlineView
        isItemExpandable:(id)item
{
	return [item isContainer] && [[item unsortedChildren] count];
}
- (int)outlineView:(NSOutlineView *)outlineView
       numberOfChildrenOfItem:(id)item
{
	return item ? [[item unsortedChildren] count] : 1;
}
- (id)outlineView:(NSOutlineView *)outlineView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
      byItem:(id)item
{
	NSString *const saveName = [self saveNameForNode:item];
	if(tableColumn == nameColumn) return saveName;
	else if(tableColumn == errorColumn) if([[NSFileManager defaultManager] fileExistsAtPath:[_destination stringByAppendingPathComponent:saveName]]) return NSLocalizedString(@"File already exists.", nil);
	return nil;
}
- (void)outlineView:(NSOutlineView *)outlineView
        setObjectValue:(id)object
        forTableColumn:(NSTableColumn *)tableColumn
        byItem:(id)item
{
	NSParameterAssert(tableColumn == nameColumn);
	if(object && [object length]) [_saveNamesByNodePointer setObject:object forKey:[NSValue valueWithNonretainedObject:item]];
}

#pragma mark NSOutlineViewDelegate Protocol

- (void)outlineView:(NSOutlineView *)outlineView
        willDisplayCell:(id)cell
        forTableColumn:(NSTableColumn *)tableColumn
        item:(id)item
{
	if(tableColumn == nameColumn) [cell setTextColor:([item canGetImageData] ? [NSColor controlTextColor] : [NSColor disabledControlTextColor])];
}
- (BOOL)outlineView:(NSOutlineView *)outlineView
        shouldEditTableColumn:(NSTableColumn *)tableColumn
        item:(id)item
{
	if(tableColumn != nameColumn) return NO;
	[outlineView editColumn:0 row:[outlineView rowForItem:item] withEvent:nil select:NO];
	NSText *const fieldEditor = [[outlineView window] fieldEditor:NO forObject:outlineView];
	if(!fieldEditor) return NO;
	unsigned const extStart = [[fieldEditor string] rangeOfString:@"." options:NSBackwardsSearch].location;
	if(NSNotFound != extStart) [fieldEditor setSelectedRange:NSMakeRange(0, extStart)];
	return NO;
}
- (BOOL)outlineView:(NSOutlineView *)outlineView
        shouldSelectItem:(id)item
{
	return [item canGetImageData];
}

#pragma mark NSObject

- (void)dealloc
{
	[nodesOutline setDataSource:nil];
	[nodesOutline setDelegate:nil]; // This object should have a shorter lifespan than us, but for some reason it keeps sending us crap long after we've died unless we do this.
	[_rootNode release];
	[_initialNode release];
	[_saveNamesByNodePointer release];
	[_destination release];
	[_openPanel release];
	[super dealloc];
}

@end
