#import "PGFadeOutPanel.h"

// Constants
#define PGFadeOutPanelFrameRate (1.0 / 30.0)
#define PGFadeOutPanelDuration  0.20

@implementation PGFadeOutPanel

#pragma mark Instance Methods

- (BOOL)isFadingOut
{
	return fFrameCount != 0;
}
- (void)fadeOut
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	if(![self isFadingOut]) {
		fAlphaValue = [self alphaValue];
		fIgnoresMouseEvents = [self ignoresMouseEvents];
		[self setIgnoresMouseEvents:YES];
	}
	float const x = ++fFrameCount / (PGFadeOutPanelDuration / PGFadeOutPanelFrameRate) - 1;
	if(x >= 0) return [self close];
	[self setAlphaValue:fAlphaValue * powf(x, 2)];
	[self performSelector:@selector(fadeOut) withObject:nil afterDelay:PGFadeOutPanelFrameRate inModes:[NSArray arrayWithObject:(NSString *)kCFRunLoopCommonModes]];
}
- (void)cancelFadeOut
{
	if(![self isFadingOut]) return;
	[self setAlphaValue:fAlphaValue];
	[self setIgnoresMouseEvents:fIgnoresMouseEvents];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	fFrameCount = 0;
}

#pragma mark NSWindow

- (void)close
{
	[super close];
	[self cancelFadeOut];
}
- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[super dealloc];
}

@end
