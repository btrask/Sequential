#import <Cocoa/Cocoa.h>

// Models
@class PGNode;

@interface PGExtractAlert : NSWindowController
{
	@private
	IBOutlet NSView               *accessoryView;
	IBOutlet NSOutlineView        *nodesOutline;
	IBOutlet NSTableColumn        *nameColumn;
	IBOutlet NSTableColumn        *errorColumn;
		 PGNode              *_rootNode;
	         PGNode              *_initialNode;
	         NSOpenPanel         *_openPanel;
	         NSString            *_destination;
	         NSMutableDictionary *_saveNamesByNodePointer;
	         BOOL                 _extractOnSheetClose;
}

- (id)initWithRoot:(PGNode *)root initialNode:(PGNode *)aNode;
- (void)beginSheetForWindow:(NSWindow *)window; // If 'window' is nil, uses a modal alert instead of a sheet.
- (void)openPanelDidEnd:(NSOpenPanel *)panel returnCode:(int)returnCode contextInfo:(void *)contextInfo;

- (NSString *)saveNameForNode:(PGNode *)node;

@end
