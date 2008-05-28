#import <Cocoa/Cocoa.h>
#import "PGPrefObject.h"

// Models
@class PGNode;
@class PGResourceIdentifier;
#import "PGExifEntry.h"
@class PGBookmark;

// Controllers
@class PGDisplayController;

extern NSString *const PGDocumentSortedNodesDidChangeNotification;
extern NSString *const PGDocumentNodeIsViewableDidChangeNotification;
extern NSString *const PGDocumentNodeDisplayNameDidChangeNotification;
extern NSString *const PGDocumentBaseOrientationDidChangeNotification;

extern NSString *const PGDocumentOldSortedNodesKey;
extern NSString *const PGDocumentNodeKey;

@interface PGDocument : PGPrefObject
{
	@private
	PGNode              *_node;
	NSMutableArray      *_cachedNodes;
	PGNode              *_storedNode;
	NSPoint              _storedCenter;
	NSRect               _storedFrame;
	PGBookmark          *_openedBookmark;
	PGDisplayController *_displayController;
	NSMenu              *_pageMenu;
	PGOrientation        _baseOrientation;
}

- (id)initWithResourceIdentifier:(PGResourceIdentifier *)ident;
- (id)initWithURL:(NSURL *)aURL;
- (id)initWithBookmark:(PGBookmark *)aBookmark;
- (PGResourceIdentifier *)identifier;
- (PGNode *)node;

- (BOOL)getStoredNode:(out PGNode **)outNode center:(out NSPoint *)outCenter;
- (void)storeNode:(PGNode *)node center:(NSPoint)center;
- (BOOL)getStoredWindowFrame:(out NSRect *)outFrame;
- (void)storeWindowFrame:(NSRect)frame;

- (PGNode *)initialViewableNode;
- (PGBookmark *)openedBookmark;
- (void)setOpenedBookmark:(PGBookmark *)aBookmark;
- (void)deleteOpenedBookmark;

- (PGDisplayController *)displayController;
- (void)setDisplayController:(PGDisplayController *)controller;

- (NSString *)displayName;
- (void)createUI;
- (void)close;
- (void)validate:(BOOL)knownInvalid;

- (BOOL)isOnline;
- (NSMenu *)pageMenu;

- (PGOrientation)baseOrientation;
- (void)addToBaseOrientation:(PGOrientation)anOrientation;

- (void)noteSortedNodesDidChange;
- (void)noteNodeIsViewableDidChange:(PGNode *)node;
- (void)noteNodeDisplayNameDidChange:(PGNode *)node;
- (void)noteNodeDidCache:(PGNode *)node;

@end
