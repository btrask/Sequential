#import <Cocoa/Cocoa.h>
#import "PGDisplayController.h"

@interface PGFullscreenController : PGDisplayController
{
	@private
	BOOL _isExitingFullscreen;
}

- (IBAction)nextTab:(id)sender;
- (IBAction)previousTab:(id)sender;
- (IBAction)activateTab:(id)sender;

- (void)prepareToExitFullscreen;

- (void)displayScreenDidChange:(NSNotification *)aNotif;

@end
