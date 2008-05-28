#import "PGWindowController.h"

// Models
#import "PGDocument.h"

// Categories
#import "NSWindowAdditions.h"

// Other
#import "PGZooming.h"

static NSString *const PGMainWindowFrameKey = @"PGMainWindowFrame";

@implementation PGWindowController

#pragma mark NSWindowNotifications Protocol

- (void)windowDidResize:(NSNotification *)notification
{
	[[NSUserDefaults standardUserDefaults] setObject:[[self window] stringWithSavedFrame] forKey:PGMainWindowFrameKey];
}
- (void)windowDidMove:(NSNotification *)notification
{
	[self windowDidResize:nil];
}

#pragma mark NSWindowDelegate Protocol

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
          defaultFrame:(NSRect)newFrame
{
	return [window PG_zoomedRectWithDefaultFrame:newFrame];
}

#pragma mark PGDisplayController

- (void)setActiveDocument:(PGDocument *)document
        closeIfAppropriate:(BOOL)flag
{
	[[self activeDocument] storeWindowFrame:[[self window] AE_contentRect]];
	[super setActiveDocument:document closeIfAppropriate:NO];
	if(flag && !document && [self activeDocument]) return [[self window] close];
	NSRect frame;
	if([[self activeDocument] getStoredWindowFrame:&frame]) [[self window] AE_setContentRect:frame];
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	[[self window] setFrameFromString:[[NSUserDefaults standardUserDefaults] objectForKey:PGMainWindowFrameKey]];
}

@end
