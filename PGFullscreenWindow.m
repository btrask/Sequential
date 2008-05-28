#import "PGFullscreenWindow.h"

// Categories
#import "NSWindowAdditions.h"

@implementation PGFullscreenWindow

#pragma mark Instance Methods

- (id)initWithScreen:(NSScreen *)anObject
{
	if((self = [super initWithContentRect:[anObject frame] styleMask:(NSBorderlessWindowMask | AEUnscaledWindowMask) backing:NSBackingStoreBuffered defer:YES])) {
		[self setHasShadow:NO];
	}
	return self;
}
- (void)moveToScreen:(NSScreen *)anObject
{
	if(anObject) [self setFrame:[anObject frame] display:YES];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(id<NSMenuItem>)anItem
{
	return [anItem action] == @selector(performClose:) ? YES : [super validateMenuItem:anItem]; // NSWindow doesn't like -performClose: for borderless windows.
}

#pragma mark NSWindow AEAdditions Protocol

- (IBAction)performWindowClose:(id)sender
{
	[self close];
}

#pragma mark NSWindow

- (IBAction)performClose:(id)sender
{
	[[self delegate] closeWindowContent:self];
}

#pragma mark -

- (BOOL)canBecomeKeyWindow
{
	return YES;
}
- (BOOL)canBecomeMainWindow
{
	return [self isVisible]; // Return -isVisible because that's (the relevant part of) what NSWindow does.
}

@end

@implementation NSObject (PGFullscreenWindowDelegate)

- (void)closeWindowContent:(PGFullscreenWindow *)sender {}

@end
