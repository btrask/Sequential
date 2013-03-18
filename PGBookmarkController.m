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
#import "PGBookmarkController.h"
#import <Carbon/Carbon.h>

// Models
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Controllers
#import "PGDocumentController.h"

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGFoundationAdditions.h"

static NSString *const PGPausedDocumentsKey            = @"PGPausedDocuments3";
static NSString *const PGPausedDocumentsDeprecated2Key = @"PGPausedDocuments2"; // Deprecated after 1.3.2.
static NSString *const PGPausedDocumentsDeprecatedKey  = @"PGPausedDocuments"; // Deprecated after 1.2.2.

static PGBookmarkController *sharedBookmarkController = nil;

#if !__LP64__
static OSStatus PGBookmarkControllerFlagsChanged(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData)
{
	[(PGBookmarkController *)inUserData setDeletesBookmarks:!!(GetCurrentEventKeyModifiers() & optionKey)];
	return noErr;
}
#endif

@interface PGBookmarkController(Private)

- (void)_updateMenuItemForBookmark:(PGBookmark *)aBookmark;
- (void)_removeBookmarkAtIndex:(NSUInteger)index; // Removes without updating.
- (void)_saveBookmarks;

@end

@implementation PGBookmarkController

#pragma mark +PGBookmarkController

+ (id)sharedBookmarkController
{
	return sharedBookmarkController ? sharedBookmarkController : [[[self alloc] init] autorelease];
}

#pragma mark -PGBookmarkController

- (IBAction)open:(id)sender
{
	PGBookmark *const bookmark = [(NSMenuItem *)sender representedObject];
	BOOL const deleteBookmark = _deletesBookmarks || NSAlternateKeyMask & [[NSApp currentEvent] modifierFlags];
	if(!deleteBookmark && [bookmark isValid]) {
		[[PGDocumentController sharedDocumentController] openDocumentWithBookmark:bookmark display:YES];
		return;
	}
	NSAlert *const alert = [[[NSAlert alloc] init] autorelease];
	[alert setAlertStyle:NSInformationalAlertStyle];
	NSButton *const deleteButton = [alert addButtonWithTitle:NSLocalizedString(@"Delete Bookmark", nil)];
	NSButton *const cancelButton = [alert addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
	if(deleteBookmark) return [self removeBookmark:bookmark];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"The file referenced by the bookmark %@ could not be found.", @"Bookmarked file could not be found error. %@ is replaced with the missing page's saved filename."), [[bookmark fileIdentifier] displayName]]];
	[alert setInformativeText:NSLocalizedString(@"It may have been moved or deleted.", @"Bookmarked file could not be found error informative text.")];
	[deleteButton setKeyEquivalent:@""];
	[cancelButton setKeyEquivalent:@"\r"];
	if([alert runModal] == NSAlertFirstButtonReturn) [self removeBookmark:bookmark];
	else [self _updateMenuItemForBookmark:bookmark];
}

#pragma mark -

- (BOOL)deletesBookmarks
{
	return _deletesBookmarks;
}
- (void)setDeletesBookmarks:(BOOL)flag
{
	_deletesBookmarks = flag;
	[bookmarkItem setTitle:flag ? NSLocalizedString(@"Delete", @"The title of the bookmarks menu. Two states.") : NSLocalizedString(@"Resume", @"The title of the bookmarks menu. Two states.")];
}

#pragma mark -

- (void)addBookmark:(PGBookmark *)aBookmark
{
	NSUInteger i;
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
	[emptyMenuItem PG_removeFromMenu];
	if([bookmarkMenu numberOfItems]) [[bookmarkMenu itemAtIndex:0] setKeyEquivalent:@""];
	NSMenuItem *const item = [[[NSMenuItem alloc] init] autorelease];
	[item setTarget:self];
	[item setAction:@selector(open:)];
	[item setRepresentedObject:aBookmark];
	[bookmarkMenu insertItem:item atIndex:0];
	[aBookmark PG_addObserver:self selector:@selector(bookmarkDidUpdate:) name:PGBookmarkDidUpdateNotification];
	[self _updateMenuItemForBookmark:aBookmark];
}
- (PGBookmark *)bookmarkForIdentifier:(PGResourceIdentifier *)ident
{
	for(PGBookmark *const bookmark in _bookmarks) if(PGEqualObjects([bookmark documentIdentifier], ident)) return bookmark;
	return nil;
}

#pragma mark -

- (void)bookmarkDidUpdate:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	[self _updateMenuItemForBookmark:[aNotif object]];
	[self _saveBookmarks];
}

#pragma mark -PGBookmarkController(Private)

- (void)_updateMenuItemForBookmark:(PGBookmark *)aBookmark
{
	NSInteger const index = [bookmarkMenu indexOfItemWithRepresentedObject:aBookmark];
	if(-1 == index) return; // Fail gracefully.
	NSMenuItem *const item = [bookmarkMenu itemAtIndex:index];
	if(![aBookmark isValid]) {
		[item setAttributedTitle:nil];
		[item setTitle:[NSString stringWithFormat:NSLocalizedString(@"Missing File %@", @"Bookmark menu item used when the file named %@ cannot be found."), [[aBookmark fileIdentifier] displayName]]];
		return;
	}
	NSMutableAttributedString *const title = [[[NSMutableAttributedString alloc] init] autorelease];
	[title appendAttributedString:[[aBookmark documentIdentifier] attributedStringWithAncestory:NO]];
	if(!PGEqualObjects([aBookmark documentIdentifier], [aBookmark fileIdentifier])) {
		[[title mutableString] appendFormat:@" %C ", (unichar)0x25B8];
		[title appendAttributedString:[[aBookmark fileIdentifier] attributedStringWithAncestory:NO]];
	}
	[item setAttributedTitle:title];
}
- (void)_removeBookmarkAtIndex:(NSUInteger)index
{
	[[_bookmarks objectAtIndex:index] PG_removeObserver:self name:PGBookmarkDidUpdateNotification];
	[_bookmarks removeObjectAtIndex:index];
	[bookmarkMenu removeItemAtIndex:[bookmarkMenu numberOfItems] - index - 1];
	if(![_bookmarks count]) [bookmarkMenu addItem:emptyMenuItem];
}
- (void)_saveBookmarks
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_bookmarks] forKey:PGPausedDocumentsKey];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super init])) {
		if(!sharedBookmarkController) {
			sharedBookmarkController = [self retain];
#if !__LP64__
			EventTypeSpec const list[] = {{kEventClassKeyboard, kEventRawKeyModifiersChanged}, {kEventClassMenu, kEventMenuOpening}};
			InstallEventHandler(GetUserFocusEventTarget(), PGBookmarkControllerFlagsChanged, 2, list, self, NULL);
#endif
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
	[self PG_removeObserver];
	[emptyMenuItem release];
	[_bookmarks release];
	[super dealloc];
}

#pragma mark -NSObject(NSNibAwaking)

- (void)awakeFromNib
{
	[emptyMenuItem retain];
	for(PGBookmark *const bookmark in _bookmarks) [self addMenuItemForBookmark:bookmark];
}

@end
