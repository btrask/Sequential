#import <Cocoa/Cocoa.h>
#import "PGWindow.h"

@interface PGFullscreenWindow : PGWindow

- (id)initWithScreen:(NSScreen *)anObject;
- (void)moveToScreen:(NSScreen *)anObject;

@end

@interface NSObject (PGFullscreenWindowDelegate)

- (void)closeWindowContent:(PGFullscreenWindow *)sender;

@end
