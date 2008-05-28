#import <Cocoa/Cocoa.h>

@interface PGFadeOutPanel : NSPanel
{
	@private
	unsigned fFrameCount;
	float    fAlphaValue;
	BOOL     fIgnoresMouseEvents;
}

- (BOOL)isFadingOut;
- (void)fadeOut;
- (void)cancelFadeOut;

@end
