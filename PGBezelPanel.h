#import <Cocoa/Cocoa.h>
#import <HMDTAppKit/PGFadeOutPanel.h>

extern NSString *const PGBezelPanelFrameShouldChangeNotification;

extern NSString *const PGBezelPanelShouldAnimateKey;

@interface PGBezelPanel : PGFadeOutPanel
{
	@private
	BOOL      _acceptsEvents;
	NSWindow *_parentWindow; // -[NSWindow parentWindow] apparently retains and autoreleases the window before returning it, which is not good when that window is being deallocated and we call it while it's removing us.
}

- (id)initWithContentView:(NSView *)aView;
- (void)displayOverWindow:(NSWindow *)aWindow;

- (BOOL)acceptsEvents;
- (void)setAcceptsEvents:(BOOL)flag;

- (void)changeFrameAnimate:(BOOL)flag;

- (void)frameShouldChange:(NSNotification *)aNotif; // Calls -changeFrameAnimate:.
- (void)windowDidResize:(NSNotification *)aNotif;

@end

@interface NSView (PGBezelPanelContentView)

+ (id)PG_bezelPanel; // Returns a bezel panel with an instance of the receiver as the content view.

// To be overridden.
- (NSRect)bezelPanel:(PGBezelPanel *)sender frameForContentRect:(NSRect)aRect scale:(float)scaleFactor; // By default, returns aRect.

@end
