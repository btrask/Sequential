#import <Cocoa/Cocoa.h>

enum {
	AEUnscaledWindowMask = 1 << 11 // Equivalent to NSUnscaledWindowMask but available on Panther.
};

@interface NSWindow (AEAdditions)

- (IBAction)performWindowClose:(id)sender;
- (BOOL)AE_isVisible; // Works around a bug with -[NSWindow isVisible] on Tiger.
- (float)AE_userSpaceScaleFactor; // Returns 1.0 if not supported.
- (NSRect)AE_contentRect;
- (void)AE_setContentRect:(NSRect)aRect;

@end
