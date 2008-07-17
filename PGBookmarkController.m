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
#import "PGBookmarkController.h"
#import <Carbon/Carbon.h>

// Models
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSMenuItemAdditions.h"

static NSString *const PGPausedDocumentsKey            = @"PGPausedDocuments3";
static NSString *const PGPausedDocumentsDeprecated2Key = @"PGPausedDocuments2"; // Deprecated after 1.3.2.
static NSString *const PGPausedDocumentsDeprecatedKey  = @"PGPausedDocuments"; // Deprecated after 1.2.2.

static PGBookmarkController *sharedBookmarkController = nil;

static OSStatus PGBookmarkControllerFlagsChanged(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData)
{
	[(PGBookmarkController *)inUserData setDeletesBookmarks:!!(GetCurrentEventKeyModifiers() & optionKey)];
	return noErr;
}

@interface PGBookmarkController (Private)

- (void)_updateMenuItemForBookmark:(PGBookmark *)aBookmark;
- (void)_removeBookmarkAtIndex:(unsigned)index; // Removes without updating.
- (void)_saveBookmarks;

@end

@implementation PGBookmarkController

+ (id)sharedBookmarkController
{
	return sharedBookmarkController ? sharedBookmarkController : [[[self alloc] init] autorelease];
}

#pragma mark Instance Methods

- (IBAction)open:(id)sender
{
	PGBookmark *const bookmark = [sender representedObject];
	if(!_deletesBookmarks && [bookmark isValid]) {
		[[PGDocumentController sharedDocumentController] openDocumentWithBookmark:bookmark display:YES];
		return;
	}
	NSAlert *const alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSInformationalAlertStyle];
	NSButton *const deleteButton = [alert addButtonWithTitle:NSLocalizedString(@"Delete Bookmark", nil)];
	NSButton *const cancelButton = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
	if(_deletesBookmarks) {
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the bookmark %@?", @"Confirmation dialog when the user intentionally deletes a bookmark. %@ is the bookmarked file's name."), [bookmark displayName]]];
		[alert setInformativeText:NSLocalizedString(@"This operation cannot be undone.", @"Confirmation dialog informative text.")];
		[deleteButton setKeyEquivalent:@"\r"];
	} else {
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"The file referenced by the bookmark %@ could not be found.", @"Bookmarked file could not be found error. %@ is replaced with the missing page's saved filename."), [bookmark displayName]]];
		[alert setInformativeText:NSLocalizedString(@"It may have been moved or deleted.", @"Bookmarked file could not be found error informative text.")];
		[deleteButton setKeyEquivalent:@""];
		[cancelButton setKeyEquivalent:@"\r"];
	}
	if([alert runModal] == NSAlertFirstButtonReturn) [self removeBookmark:bookmark];
	else [self _updateMenuItemForBookmark:bookmark];
}

#pragma mark -

- (void)addBookmark:(PGBookmark *)aBookmark
{
	unsigned i;
	while((i = [_bookmarks indexOfObject:aBookmark]) != NSNotFound) [self _removeBookmarkAtIndex:i];
	[_bookmarks addObject:aBookmark];
	[self addMenuItemForBookmark:aBookmark];
	[self _saveBookmarks];
}
- (void)removeBookmark:(PGBookmark *)aBookmark
{
	if(!aBookmark) return;
	[self _removeBookmarkAtIndex:[_bookmarks indexOfObject:aBookmark]];
	[self _saveBookmarks];
}

- (void)addMenuItemForBookmark:(PGBookmark *)aBookmark
{
	NSParameterAssert(aBookmark);
	[emptyMenuItem AE_removeFromMenu];
	if([bookmarkMenu numberOfItems]) [[bookmarkMenu itemAtIndex:0] setKeyEquivalent:@""];
	NSMenuItem *const item = [[[NSMenuItem alloc] init] autorelease];
	[item setTarget:self];
	[item setAction:@selector(open:)];
	[item setRepresentedObject:aBookmark];
	[bookmarkMenu insertItem:item atIndex:0];
	[aBookmark AE_addObserver:self selector:@selector(bookmarkDidUpdate:) name:PGBookmarkDidUpdateNotification];
	[self _updateMenuItemForBookmark:aBookmark];
}

#pragma mark -

- (BOOL)deletesBookmarks
{
	return _deletesBookmarks;
}
- (void)setDeletesBookmarks:(BOOL)flag
{
	_deletesBookmarks = flag;
	[bookmarkItem setTitle:NSLocalizedString((flag ? @"Delete..." : @"Resume"), @"The title of the bookmarks menu. Two states.")];
	[bookmarkItem setTitle:[bookmarkItem title]]; // Set it twice so that Panther can keep up with us.
}

#pragma mark -

- (void)bookmarkDidUpdate:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	[self _updateMenuItemForBookmark:[aNotif object]];
	[self _saveBookmarks];
}

#pragma mark Private Protocol

- (void)_updateMenuItemForBookmark:(PGBookmark *)aBookmark
{
	NSMenuItem *const item = [bookmarkMenu itemAtIndex:[bookmarkMenu indexOfItemWithRepresentedObject:aBookmark]];
	if(![aBookmark isValid]) {
		[item setAttributedTitle:nil];
		[item setTitle:[NSString stringWithFormat:NSLocalizedString(@"Missing File %@", @"Bookmark menu item used when the file named %@ cannot be found."), [aBookmark displayName]]];
		return;
	}
	NSMutableAttributedString *const title = [[[NSMutableAttributedString alloc] init] autorelease];
	[title appendAttributedString:[[aBookmark documentIdentifier] attributedStringWithWithAncestory:NO]];
	if(![[aBookmark documentIdentifier] isEqual:[aBookmark fileIdentifier]]) {
		[[title mutableString] appendFormat:@" %C ", 0x25B9];
		[title appendAttributedString:[[aBookmark fileIdentifier] attributedStringWithWithAncestory:NO]];
	}
	[item setAttributedTitle:title];
}
- (void)_removeBookmarkAtIndex:(unsigned)index
{
	[[_bookmarks objectAtIndex:index] AE_removeObserver:self name:PGBookmarkDidUpdateNotification];
	[_bookmarks removeObjectAtIndex:index];
	[bookmarkMenu removeItemAtIndex:[bookmarkMenu numberOfItems] - index - 1];
	if(![_bookmarks count]) [bookmarkMenu addItem:emptyMenuItem];
}
- (void)_saveBookmarks
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_bookmarks] forKey:PGPausedDocumentsKey];
}

#pragma mark NSNibAwaking Protocol

- (void)awakeFromNib
{
	[emptyMenuItem retain];
	PGBookmark *bookmark;
	NSEnumerator *const bookmarkEnum = [_bookmarks objectEnumerator];
	while((bookmark = [bookmarkEnum nextObject])) [self addMenuItemForBookmark:bookmark];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		if(!sharedBookmarkController) {
			sharedBookmarkController = [self retain];
			EventTypeSpec const list[] = {{kEventClassKeyboard, kEventRawKeyModifiersChanged}, {kEventClassMenu, kEventMenuOpening}};
			InstallEventHandler(GetUserFocusEventTarget(), PGBookmarkControllerFlagsChanged, 2, list, self, NULL);
		}
		NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
		NSData *bookmarksData = [defaults objectForKey:PGPausedDocumentsKey];
		if(!bookmarksData) {
			bookmarksData = [defaults objectForKey:PGPausedDocumentsDeprecated2Key];
			[defaults removeObjectForKey:PGPausedDocumentsDeprecated2Key];
		}
		if(!bookmarksData) {
			bookmarksData = [defaults objectForKey:PGPausedDocumentsDeprecatedKey];
			[defaults removeObjectForKey:PGPausedDocumentsDeprecatedKey];
		}
		_bookmarks = bookmarksData ? [[NSKeyedUnarchiver unarchiveObjectWithData:bookmarksData] retain] : [[NSMutableArray alloc] init];
		[self _saveBookmarks];
	}
	return self;
}
- (void)dealloc
{
	[self AE_removeObserver];
	[emptyMenuItem release];
	[_bookmarks release];
	[super dealloc];
}

@end
