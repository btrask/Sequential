#import <Cocoa/Cocoa.h>

// Views
@class PGBezelPanel;

@interface PGWindow : NSWindow
{
	@private
	PGBezelPanel *fDragHighlightPanel;
}

@end

@interface NSObject (PGWindowDelegate)

- (NSDragOperation)window:(PGWindow *)window dragOperationForInfo:(id<NSDraggingInfo>)info;
- (BOOL)window:(PGWindow *)window performDragOperation:(id<NSDraggingInfo>)info;

- (void)selectNextOutOfWindowKeyView:(NSWindow *)window;
- (void)selectPreviousOutOfWindowKeyView:(NSWindow *)window;

@end
