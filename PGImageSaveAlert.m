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
#import "PGImageSaveAlert.h"

// Models
#import "PGNode.h"
#import "PGContainerAdapter.h"
#import "PGGenericImageAdapter.h"
#import "PGResourceIdentifier.h"

// Other Sources
#import "PGFoundationAdditions.h"

@implementation PGImageSaveAlert

#pragma mark -PGImageSaveAlert

- (id)initWithRoot:(PGNode *)root initialSelection:(NSSet *)aSet
{
	if(!(self = [super initWithWindowNibName:@"PGImageSave"])) return nil;
	_rootNode = [root retain];
	_initialSelection = [aSet copy];
	_saveNamesByNodePointer = [[NSMutableDictionary alloc] init];
	[[NSProcessInfo processInfo] PG_disableSuddenTermination];
	return self;
}
- (void)beginSheetForWindow:(NSWindow *)window
{
	(void)[self window];
	_firstTime = YES;
	[_openPanel release];
	_openPanel = [[NSOpenPanel alloc] init];
	[_openPanel PG_addObserver:self selector:@selector(windowDidEndSheet:) name:NSWindowDidEndSheetNotification];
	[_openPanel setCanChooseFiles:NO];
	[_openPanel setCanChooseDirectories:YES];
	[_openPanel setCanCreateDirectories:YES];
	[_openPanel setAllowsMultipleSelection:NO];
	[_openPanel setDelegate:self];

	[_openPanel setAccessoryView:accessoryView];
	[accessoryView setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
	[accessoryView setFrame:[[accessoryView superview] bounds]];

	NSSavePanel *const savePanel = [NSSavePanel savePanel];
	[_openPanel setPrompt:[savePanel prompt]];
	[_openPanel setTitle:[savePanel title]];
	[self retain];
	if(window) [_openPanel beginSheetForDirectory:nil file:nil types:nil modalForWindow:window modalDelegate:self didEndSelector:@selector(openPanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	else [self openPanelDidEnd:_openPanel returnCode:[_openPanel runModalForTypes:nil] contextInfo:NULL];
}
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	[panel orderOut:self];
	[_openPanel PG_removeObserver:self name:NSWindowDidEndSheetNotification];
	[_openPanel setDelegate:nil];
	[self release];
}

#pragma mark -

- (NSString *)saveNameForNode:(PGNode *)node
{
	NSString *const modifiedName = [_saveNamesByNodePointer objectForKey:[NSValue valueWithNonretainedObject:node]];
	return modifiedName ? [[modifiedName retain] autorelease] : [[node identifier] naturalDisplayName];
}
- (void)replaceAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if(NSAlertFirstButtonReturn == returnCode) _saveOnSheetClose = YES;
}

#pragma mark -NSObject

- (void)dealloc
{
	[[NSProcessInfo processInfo] PG_enableSuddenTermination];
	[nodesOutline setDataSource:nil];
	[nodesOutline setDelegate:nil];
	[_rootNode release];
	[_initialSelection release];
	[_saveNamesByNodePointer release];
	[_destination release];
	[_openPanel release];
	[super dealloc];
}

#pragma mark -<NSOpenSavePanelDelegate>

- (BOOL)panel:(id)sender isValidFilename:(NSString *)filename
{
	NSUInteger existingFileCount = 0;
	NSString *existingFilename = nil;
	{
		NSIndexSet *const rows = [nodesOutline selectedRowIndexes];
		NSUInteger i = [rows firstIndex];
		for(; NSNotFound != i; i = [rows indexGreaterThanIndex:i]) {
			NSString *const name = [self saveNameForNode:[nodesOutline itemAtRow:i]];
			if(![[NSFileManager defaultManager] fileExistsAtPath:[_destination stringByAppendingPathComponent:name]]) continue;
			existingFileCount++;
			existingFilename = name;
		}
	}
	if(existingFileCount && !_saveOnSheetClose) {
		NSAlert *const alert = [[[NSAlert alloc] init] autorelease];
		[alert setAlertStyle:NSCriticalAlertStyle];
		if(1 == existingFileCount) [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%@ already exists in %@. Do you want to replace it?", @"Replace file alert. The first %@ is replaced with the filename, the second is replaced with the destination name."), existingFilename, [_destination PG_displayName]]];
		else [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%lu pages already exist in %@. Do you want to replace them?", @"Replace multiple files alert. %lu is replaced with a number greater than 1, %@ is replaced with the destination name."), (unsigned long)existingFileCount, [_destination PG_displayName]]];
		[alert setInformativeText:NSLocalizedString(@"Replacing a file overwrites its current contents.", @"Informative text for replacement alerts.")];
		[[alert addButtonWithTitle:NSLocalizedString(@"Replace", nil)] setKeyEquivalent:@""];
		[[alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)] setKeyEquivalent:@"\r"];
		[alert beginSheetModalForWindow:_openPanel modalDelegate:self didEndSelector:@selector(replaceAlertDidEnd:returnCode:contextInfo:) contextInfo:nil];
		return NO;
	}
	NSMutableArray *const unsavedNodes = [NSMutableArray array];
	NSMutableIndexSet *const unsavedRows = [NSMutableIndexSet indexSet];
	NSIndexSet *const rows = [[[nodesOutline selectedRowIndexes] copy] autorelease];
	NSUInteger i = [rows firstIndex];
	for(; NSNotFound != i; i = [rows indexGreaterThanIndex:i]) {
		id const node = [nodesOutline itemAtRow:i];
		NSData *const data = [node data];
		if(data && [data writeToFile:[_destination stringByAppendingPathComponent:[self saveNameForNode:node]] atomically:NO]) continue;
		[unsavedNodes addObject:node];
		[unsavedRows addIndex:i];
	}
	if(![unsavedNodes count]) return YES;
	[nodesOutline reloadData];
	[nodesOutline selectRowIndexes:unsavedRows byExtendingSelection:NO];
	NSAlert *const alert = [[[NSAlert alloc] init] autorelease];
	if(1 == [unsavedNodes count]) [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"The image %@ could not be saved to %@.", @"Single image save failure alert. The first %@ is replaced with the filename, the second is replaced with the destination name."), [self saveNameForNode:[unsavedNodes objectAtIndex:0]], [_destination PG_displayName]]];
	else [alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"%lu images could not be saved to %@.", @"Multiple image save failure alert. %lu is replaced with the number of files, %@ is replaced with the destination name."), (unsigned long)[unsavedNodes count], [_destination PG_displayName]]];
	[alert setInformativeText:NSLocalizedString(@"Make sure the volume is writable and has enough free space.", @"Informative text for save failure alerts.")];
	[alert addButtonWithTitle:NSLocalizedString(@"OK", nil)];
	[alert beginSheetModalForWindow:_openPanel modalDelegate:nil didEndSelector:NULL contextInfo:nil];
	return NO;
}
- (void)panel:(id)sender directoryDidChange:(NSString *)path
{
	[_destination release];
	_destination = [path retain];
	[nodesOutline reloadData];
	if(_firstTime) {
		[nodesOutline expandItem:_rootNode expandChildren:YES];
		_firstTime = NO;
	}

	if(!_initialSelection) return;
	NSMutableIndexSet *const indexes = [NSMutableIndexSet indexSet];
	for(PGNode *const node in _initialSelection) {
		if(![node canSaveData]) continue;
		NSInteger const rowIndex = [nodesOutline rowForItem:node];
		if(-1 != rowIndex) [indexes addIndex:(NSUInteger)rowIndex];
	}
	[nodesOutline selectRowIndexes:indexes byExtendingSelection:NO];
	NSUInteger const firstRow = [indexes firstIndex];
	if(NSNotFound != firstRow) [nodesOutline scrollRowToVisible:firstRow];
	[_initialSelection release];
	_initialSelection = nil;
}

#pragma mark -<NSOutlineViewDataSource>

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	return item ? [[item sortedChildren] objectAtIndex:index] : _rootNode;
}
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [item hasSavableChildren];
}
- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	return item ? [[item unsortedChildren] count] : 1;
}
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSString *const saveName = [self saveNameForNode:item];
	if(tableColumn == nameColumn) return saveName;
	else if(tableColumn == errorColumn) if([[NSFileManager defaultManager] fileExistsAtPath:[_destination stringByAppendingPathComponent:saveName]]) return NSLocalizedString(@"File already exists.", @"Appears in the image save alert beside each filename that conflicts with an existing file in the destination folder.");
	return nil;
}
- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)tableColumn byItem:(id)item
{
	NSParameterAssert(tableColumn == nameColumn);
	if([(NSString *)object length]) [_saveNamesByNodePointer setObject:object forKey:[NSValue valueWithNonretainedObject:item]];
}

#pragma mark -<NSOutlineViewDelegate>

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if(tableColumn == nameColumn) {
		[cell setIcon:[[(PGNode *)item identifier] icon]];
		[cell setEnabled:[item canSaveData]];
	}
}
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	if(tableColumn != nameColumn) return NO;
	[outlineView editColumn:0 row:[outlineView rowForItem:item] withEvent:nil select:NO];
	NSText *const fieldEditor = [[outlineView window] fieldEditor:NO forObject:outlineView];
	if(!fieldEditor) return NO;
	NSUInteger const extStart = [[fieldEditor string] rangeOfString:@"." options:NSBackwardsSearch].location;
	if(NSNotFound != extStart) [fieldEditor setSelectedRange:NSMakeRange(0, extStart)];
	return NO;
}
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return [item canSaveData];
}

#pragma mark -<NSWindowDelegate>

- (void)windowDidEndSheet:(NSNotification *)notification
{
	if(!_saveOnSheetClose) return;
	[_openPanel ok:self];
	_saveOnSheetClose = NO;
}

@end
