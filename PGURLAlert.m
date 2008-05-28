#import "PGURLAlert.h"

// Other
#import "PGZooming.h"

// Categories
#import "NSURLAdditions.h"

@implementation PGURLAlert

#pragma mark Instance Methods

- (IBAction)ok:(id)sender
{
	[NSApp stopModalWithCode:NSAlertFirstButtonReturn];
}
- (IBAction)cancel:(id)sender
{
	[NSApp stopModalWithCode:NSAlertSecondButtonReturn];
}

#pragma mark -

- (NSURL *)runModal
{
	BOOL const canceled = [NSApp runModalForWindow:[self window]] == NSAlertSecondButtonReturn;
	[[self window] close];
	if(canceled) return nil;
	return [NSURL AE_URLWithString:[URLField stringValue]];
}

#pragma mark NSControlSubclassNotifications Protocol

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[OKButton setEnabled:[NSURL AE_URLWithString:[URLField stringValue]] != nil];
}

#pragma mark NSWindowDelegate Protocol

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
          defaultFrame:(NSRect)defaultFrame
{
	return [window PG_zoomedRectWithDefaultFrame:defaultFrame];
}

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self controlTextDidChange:nil];
}

#pragma mark NSObject

- (id)init
{
	return [self initWithWindowNibName:@"PGURL"];
}

@end
