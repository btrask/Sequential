#import "NSWindowAdditions.h"

@interface NSWindow (TigerOrLater)

- (float)userSpaceScaleFactor;

@end

@implementation NSWindow (AEAdditions)

- (IBAction)performWindowClose:(id)sender
{
	[self performClose:sender];
}
- (BOOL)AE_isVisible
{
	return [NSApp isActive] || ![self hidesOnDeactivate];
}
- (float)AE_userSpaceScaleFactor
{
	return [self respondsToSelector:@selector(userSpaceScaleFactor)] ? [self userSpaceScaleFactor] : 1.0;
}
- (NSRect)AE_contentRect
{
	return [self contentRectForFrameRect:[self frame]];
}
- (void)AE_setContentRect:(NSRect)aRect
{
	[self setFrame:[self frameRectForContentRect:aRect] display:YES];
}

@end
