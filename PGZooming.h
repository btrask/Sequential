#import <Cocoa/Cocoa.h>

@interface NSWindow (PGZooming)

- (NSRect)PG_zoomedRectWithDefaultFrame:(NSRect)newFrame;

@end

@interface NSView (PGZooming)

- (NSSize)PG_zoomedFrameSize;
- (NSSize)PG_zoomedBoundsSize;

@end

@interface NSTableColumn (PGZooming)

- (float)PG_zoomedWidth;

@end
