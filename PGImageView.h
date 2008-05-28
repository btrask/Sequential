#import <Cocoa/Cocoa.h>

// Models
#import "PGExifEntry.h"

@interface PGImageView : NSView
{
	@private
	NSImage          *_image;
	NSImageRep       *_rep;
	NSCachedImageRep *_cache;
	BOOL              _isOpaque;
	BOOL              _isPDF;
	PGOrientation     _orientation;
	unsigned          _numberOfFrames;
	BOOL              _animating;
}

- (NSImage *)image;
- (NSImageRep *)rep; // The image's representations may be changed by PGImageView. This method is guaranteed to return the original.
- (PGOrientation)orientation;
- (void)setImage:(NSImage *)anImage orientation:(PGOrientation)orientation;

- (BOOL)canAnimate;
- (BOOL)isAnimating; // Can return YES even if the current image isn't animated.
- (void)setAnimating:(BOOL)flag;

- (void)appDidHide:(NSNotification *)aNotif;
- (void)appDidUnhide:(NSNotification *)aNotif;
- (void)appDidResignActive:(NSNotification *)aNotif;
- (void)appDidBecomeActive:(NSNotification *)aNotif;

@end
