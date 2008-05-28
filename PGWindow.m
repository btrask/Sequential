#import "PGWindow.h"

// Views
#import "PGBezelPanel.h"
#import "PGDragHighlightView.h"

@implementation PGWindow

#pragma mark NSDraggingDestination Protocol

- (NSDragOperation)draggingEntered:(id<NSDraggingInfo>)sender
{
	NSDragOperation const op = [[self delegate] window:self dragOperationForInfo:sender];
	if(NSDragOperationNone == op) return NSDragOperationNone;
	fDragHighlightPanel = [[PGDragHighlightView PG_bezelPanel] retain];
	[fDragHighlightPanel displayOverWindow:self];
	return op;
}
- (void)draggingExited:(id<NSDraggingInfo>)sender
{
	[[fDragHighlightPanel autorelease] fadeOut];
	fDragHighlightPanel = nil;
}

- (BOOL)performDragOperation:(id<NSDraggingInfo>)sender
{
	[self draggingExited:nil];
	return [[self delegate] window:self performDragOperation:sender];
}
- (void)concludeDragOperation:(id <NSDraggingInfo>)sender
{
	[self draggingExited:nil]; // Just in case.
}

#pragma mark -

- (void)selectKeyViewFollowingView:(NSView *)aView
{
	[super selectKeyViewFollowingView:aView];
	if([[self firstResponder] isKindOfClass:[NSView class]] && [(NSView *)[self firstResponder] isDescendantOf:[self initialFirstResponder]]) [[self delegate] selectNextOutOfWindowKeyView:self];
}
- (void)selectKeyViewPrecedingView:(NSView *)aView
{
	if([aView isDescendantOf:[self initialFirstResponder]]) [[self delegate] selectPreviousOutOfWindowKeyView:self];
	[super selectKeyViewPrecedingView:aView];
}

#pragma mark NSObject

- (void)dealloc
{
	[fDragHighlightPanel release];
	[super dealloc];
}

@end

@implementation NSObject (PGWindowDelegate)

- (NSDragOperation)window:(PGWindow *)window
                   dragOperationForInfo:(id<NSDraggingInfo>)info
{
	return NSDragOperationNone;
}
- (BOOL)window:(PGWindow *)window
        performDragOperation:(id<NSDraggingInfo>)info
{
	return NO;
}
- (void)selectNextOutOfWindowKeyView:(NSWindow *)window {}
- (void)selectPreviousOutOfWindowKeyView:(NSWindow *)window {}

@end
