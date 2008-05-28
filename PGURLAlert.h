#import <Cocoa/Cocoa.h>

@interface PGURLAlert : NSWindowController
{
	@private
	IBOutlet NSTextField *URLField;
	IBOutlet NSButton    *OKButton;
}

- (IBAction)ok:(id)sender;
- (IBAction)cancel:(id)sender;

- (NSURL *)runModal;

@end
