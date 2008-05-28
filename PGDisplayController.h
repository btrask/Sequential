#import <Cocoa/Cocoa.h>

// Models
@class PGDocument;
@class PGNode;

// Views
#import "PGClipView.h"
@class PGImageView;
@class PGBezelPanel;
@class PGLoadingGraphic;
@class PGFindView;
@class PGFindlessTextView;

extern NSString *const PGDisplayControllerActiveNodeDidChangeNotification;

@interface PGDisplayController : NSWindowController
{
	@protected
	IBOutlet PGClipView          *clipView;
	IBOutlet PGImageView         *imageView;

	@private
	         PGClipViewLocation  _initialLocation;
	         unsigned            _displayImageIndex;

	         PGBezelPanel       *_graphicPanel;
	         PGLoadingGraphic   *_loadingGraphic;
	         PGBezelPanel       *_infoPanel;

	IBOutlet PGFindView          *findView;
	IBOutlet NSSearchField       *searchField;
	         PGBezelPanel       *_findPanel;
	         PGFindlessTextView *_findFieldEditor;

	IBOutlet NSView              *passwordView;
	IBOutlet NSTextField         *passwordLabel;
	IBOutlet NSTextField         *passwordField;
	IBOutlet NSView              *encodingView;
	IBOutlet NSTextField         *encodingLabel;

	         PGDocument         *_activeDocument;
	         PGNode             *_activeNode;

	         NSTimeInterval      _timerInterval;
}

+ (NSArray *)pasteboardTypes;

- (IBAction)revealInPathFinder:(id)sender;
- (IBAction)revealInFinder:(id)sender;
- (IBAction)revealInBrowser:(id)sender;
- (IBAction)extractImages:(id)sender;
- (IBAction)moveToTrash:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)changeOrientation:(id)sender; // Gets the orientation from [sender tag].
- (IBAction)performFindPanelAction:(id)sender;
- (IBAction)hideFindPanel:(id)sender;

- (IBAction)toggleFullscreen:(id)sender;
- (IBAction)toggleOnScreenDisplay:(id)sender;

- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;

- (IBAction)changeTimerInterval:(id)sender; // Gets the interval in seconds from [sender tag].

- (IBAction)previousPage:(id)sender;
- (IBAction)nextPage:(id)sender;
- (IBAction)firstPage:(id)sender;
- (IBAction)lastPage:(id)sender;
- (IBAction)jumpToPage:(id)sender;

- (IBAction)pauseDocument:(id)sender;
- (IBAction)pauseAndCloseDocument:(id)sender;

- (IBAction)decrypt:(id)sender;
- (IBAction)chooseEncoding:(id)sender;

- (PGDocument *)activeDocument;
- (void)setActiveDocument:(PGDocument *)document closeIfAppropriate:(BOOL)flag;

- (PGNode *)activeNode;
- (void)setActiveNode:(PGNode *)aNode initialLocation:(PGClipViewLocation)location;
- (BOOL)tryToSetActiveNode:(PGNode *)aNode initialLocation:(PGClipViewLocation)location;
- (BOOL)tryToGoForward:(BOOL)forward allowAlerts:(BOOL)showAlerts;

- (BOOL)loadingIndicatorShown;
- (void)showLoadingIndicator;

- (BOOL)findPanelShown;
- (void)setFindPanelShown:(BOOL)flag;

- (NSTimeInterval)timerInterval;
- (void)setTimerInterval:(NSTimeInterval)time; // 0 for off.
- (void)advanceOnTimer;

- (void)clipViewFrameDidChange:(NSNotification *)aNotif;

- (void)nodeLoadingDidProgress:(NSNotification *)aNotif;
- (void)nodeReadyForViewing:(NSNotification *)aNotif;

- (void)documentSortedNodesDidChange:(NSNotification *)aNotif;
- (void)documentNodeDisplayNameDidChange:(NSNotification *)aNotif;
- (void)documentNodeIsViewableDidChange:(NSNotification *)aNotif;
- (void)documentShowsOnScreenDisplayDidChange:(NSNotification *)aNotif;
- (void)documentReadingDirectionDidChange:(NSNotification *)aNotif;
- (void)documentImageScaleDidChange:(NSNotification *)aNotif;
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif;
- (void)documentAnimatesImagesDidChange:(NSNotification *)aNotif;

- (void)documentControllerBackgroundPatternColorDidChange:(NSNotification *)aNotif;

@end
