#import <Cocoa/Cocoa.h>

// Models
@class PGNode;

@interface PGFloatingPanel : NSWindowController
{
	@private
	PGNode *_node;
}

- (PGNode *)node;
- (void)nodeChanged;

- (void)displayControllerActiveNodeDidChange:(NSNotification *)aNotif;
- (void)windowDidBecomeMain:(NSNotification *)aNotif;
- (void)windowDidResignMain:(NSNotification *)aNotif;

@end
