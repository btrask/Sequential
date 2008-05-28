#import <Cocoa/Cocoa.h>

// Models
@class PGBookmark;

@interface PGBookmarkController : NSObject
{
	@private
	IBOutlet NSMenuItem      *bookmarkItem;
	IBOutlet NSMenu          *bookmarkMenu;
	IBOutlet NSMenuItem      *emptyMenuItem;
	         NSMutableArray *_bookmarks;
	         BOOL            _deletesBookmarks;
}

+ (id)sharedBookmarkController;

- (IBAction)open:(id)sender;

- (void)addBookmark:(PGBookmark *)aBookmark;
- (void)removeBookmark:(PGBookmark *)aBookmark;
- (void)addMenuItemForBookmark:(PGBookmark *)aBookmark;

- (BOOL)deletesBookmarks;
- (void)setDeletesBookmarks:(BOOL)flag; // If YES, the "Resume" menu becomes a "Delete" menu.

- (void)bookmarkDidChange:(NSNotification *)aNotif;

@end
