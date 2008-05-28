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
static NSString *const PGPausedDocumentsDeprecatedKey  = @"PGPausedDocuments";
static NSString *const PGPausedDocumentsDeprecated2Key = @"PGPausedDocuments2";

static PGBookmarkController *sharedBookmarkController = nil;

static OSStatus PGBookmarkControllerFlagsChanged(EventHandlerCallRef inHandlerCallRef, EventRef inEvent, void *inUserData)
{
	[(PGBookmarkController *)inUserData setDeletesBookmarks:!!(GetCurrentEventKeyModifiers() & optionKey)];
	return noErr;
}

@interface PGBookmarkController (Private)

- (void)_updateMenuItemForBookmark:(PGBookmark *)aBookmark;
- (void)_removeBookmark:(PGBookmark *)aBookmark; // Removes without updating.

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
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"Are you sure you want to delete the bookmark %@?", nil), [bookmark displayName]]];
		[alert setInformativeText:NSLocalizedString(@"This operation cannot be undone.", nil)];
		[deleteButton setKeyEquivalent:@"\r"];
	} else {
		[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"The file referenced by the bookmark %@ could not be found.", nil), [bookmark displayName]]];
		[alert setInformativeText:NSLocalizedString(@"It may have been moved or deleted.", nil)];
		[deleteButton setKeyEquivalent:@""];
		[cancelButton setKeyEquivalent:@"\r"];
	}
	if([alert runModal] == NSAlertFirstButtonReturn) [self removeBookmark:bookmark];
	else [self _updateMenuItemForBookmark:bookmark];
}

#pragma mark -

- (void)addBookmark:(PGBookmark *)aBookmark
{
	PGBookmark *bookmark;
	NSEnumerator *const bookmarkEnum = [[[_bookmarks copy] autorelease] objectEnumerator];
	while((bookmark = [bookmarkEnum nextObject])) if([bookmark isEqual:aBookmark]) [self _removeBookmark:bookmark];;
	[_bookmarks addObject:aBookmark];
	[self addMenuItemForBookmark:aBookmark];
//	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_bookmarks] forKey:PGPausedDocumentsKey];
}
- (void)removeBookmark:(PGBookmark *)aBookmark
{
	if(!aBookmark) return;
	[self _removeBookmark:aBookmark];
//	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_bookmarks] forKey:PGPausedDocumentsKey];
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
//	[aBookmark AE_addObserver:self selector:@selector(bookmarkDidChange:) name:PGBookmarkDidChangeNotification];
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
	[bookmarkItem setTitle:(flag ? NSLocalizedString(@"Delete...", nil) : NSLocalizedString(@"Resume", nil))];
}

#pragma mark -

- (void)bookmarkDidChange:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	[self _updateMenuItemForBookmark:[aNotif object]];
}

#pragma mark Private Protocol

- (void)_updateMenuItemForBookmark:(PGBookmark *)aBookmark
{
	NSMenuItem *const item = [bookmarkMenu itemAtIndex:[bookmarkMenu indexOfItemWithRepresentedObject:aBookmark]];
	if(![aBookmark isValid]) {
		[item setAttributedTitle:nil];
		[item setTitle:[NSString stringWithFormat:NSLocalizedString(@"Missing File %@", nil), [aBookmark displayName]]];
		return;
	}
	NSMutableAttributedString *const title = [[[NSMutableAttributedString alloc] init] autorelease];
	PGResourceIdentifier *const identifier = [aBookmark documentIdentifier];
	if(identifier) {
		[title appendAttributedString:[identifier attributedStringWithWithAncestory:NO]];
		[[title mutableString] appendFormat:@" %C ", 0x25B9];
	}
	[title appendAttributedString:[[aBookmark fileIdentifier] attributedStringWithWithAncestory:NO]];
	[item setAttributedTitle:title];
}
- (void)_removeBookmark:(PGBookmark *)aBookmark
{
	NSParameterAssert(aBookmark);
	[aBookmark retain]; // Regular retain-autorelease was giving a user problems. I honestly don't understand it but he said it's working after this change.
//	[aBookmark AE_removeObserver:self name:PGBookmarkDidChangeNotification];
	[_bookmarks removeObjectIdenticalTo:aBookmark];
	[bookmarkMenu removeItemAtIndex:[bookmarkMenu indexOfItemWithRepresentedObject:aBookmark]];
	if(![_bookmarks count]) [bookmarkMenu addItem:emptyMenuItem];
	[aBookmark release];
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
/*		NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
		NSData *bookmarksData = [defaults objectForKey:PGPausedDocumentsKey];
		if(!bookmarksData) {
			bookmarksData = [defaults objectForKey:PGPausedDocumentsOldKey];
			[defaults removeObjectForKey:PGPausedDocumentsOldKey];
		}
		// load from PGPausedDocumentsDeprecated2Key too.
		_bookmarks = bookmarksData ? [[NSKeyedUnarchiver unarchiveObjectWithData:bookmarksData] retain] : [[NSMutableArray alloc] init];
		[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_bookmarks] forKey:PGPausedDocumentsKey];*/
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
