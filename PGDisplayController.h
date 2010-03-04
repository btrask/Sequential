/* Copyright © 2007-2009, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */

// Models
@class PGDocument;
@class PGNode;
@class PGBookmark;

// Views
#import "PGDocumentWindow.h"
#import "PGClipView.h"
@class PGImageView;
@class PGBezelPanel;
@class PGLoadingGraphic;
@class PGFindView;
@class PGFindlessTextView;

// Controllers
@class PGThumbnailController;

// Other Sources
#import "PGGeometryTypes.h"

extern NSString *const PGDisplayControllerActiveNodeDidChangeNotification;
extern NSString *const PGDisplayControllerActiveNodeWasReadNotification;
extern NSString *const PGDisplayControllerTimerDidChangeNotification;

@interface PGDisplayController : NSWindowController <
#ifdef MAC_OS_X_VERSION_10_6
NSWindowDelegate,
#endif
PGClipViewDelegate, PGDocumentWindowDelegate>
{
	@private
	IBOutlet PGClipView *clipView;
	IBOutlet PGFindView *findView;
	IBOutlet NSSearchField *searchField;
	IBOutlet NSView *errorView;
	IBOutlet NSTextField *errorLabel;
	IBOutlet NSTextField *errorMessage;
	IBOutlet NSButton *reloadButton;
	IBOutlet NSView *passwordView;
	IBOutlet NSTextField *passwordLabel;
	IBOutlet NSTextField *passwordField;

	PGDocument *_activeDocument;
	PGNode *_activeNode;
	PGImageView *_imageView;
	PGPageLocation _initialLocation;
	BOOL _reading;
	NSUInteger _displayImageIndex;

	PGBezelPanel *_graphicPanel;
	PGLoadingGraphic *_loadingGraphic;
	PGBezelPanel *_infoPanel;

	PGThumbnailController *_thumbnailController;

	PGBezelPanel *_findPanel;
	PGFindlessTextView *_findFieldEditor;

	NSDate *_nextTimerFireDate;
	NSTimer *_timer;
}

+ (NSArray *)pasteboardTypes;

- (IBAction)saveImagesTo:(id)sender;
- (IBAction)setAsDesktopPicture:(id)sender;
- (IBAction)setCopyAsDesktopPicture:(id)sender;
- (IBAction)moveToTrash:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)performFindPanelAction:(id)sender;
- (IBAction)hideFindPanel:(id)sender;

- (IBAction)toggleFullscreen:(id)sender;
- (IBAction)toggleInfo:(id)sender;
- (IBAction)toggleThumbnails:(id)sender;
- (IBAction)changeReadingDirection:(id)sender;
- (IBAction)changeSortOrder:(id)sender;
- (IBAction)changeSortDirection:(id)sender;
- (IBAction)changeSortRepeat:(id)sender;
- (IBAction)revertOrientation:(id)sender;
- (IBAction)changeOrientation:(id)sender;
- (IBAction)toggleAnimation:(id)sender;

- (IBAction)changeImageScaleMode:(id)sender;
- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;
- (IBAction)changeImageScaleFactor:(id)sender;
- (IBAction)minImageScaleFactor:(id)sender;
- (IBAction)maxImageScaleFactor:(id)sender;

- (IBAction)previousPage:(id)sender;
- (IBAction)nextPage:(id)sender;
- (IBAction)firstPage:(id)sender;
- (IBAction)lastPage:(id)sender;

- (IBAction)firstOfPreviousFolder:(id)sender;
- (IBAction)firstOfNextFolder:(id)sender;
- (IBAction)skipBeforeFolder:(id)sender;
- (IBAction)skipPastFolder:(id)sender;
- (IBAction)firstOfFolder:(id)sender;
- (IBAction)lastOfFolder:(id)sender;

- (IBAction)jumpToPage:(id)sender;

- (IBAction)pauseDocument:(id)sender;
- (IBAction)pauseAndCloseDocument:(id)sender;

- (IBAction)reload:(id)sender;
- (IBAction)decrypt:(id)sender;

@property(readonly) PGDocument *activeDocument;
@property(readonly) PGNode *activeNode;
@property(readonly) NSWindow *windowForSheet;
@property(readonly) NSSet *selectedNodes;
@property(readonly) PGNode *selectedNode;
@property(readonly) PGClipView *clipView;
@property(readonly) PGPageLocation initialLocation;
@property(readonly, getter = isReading) BOOL reading;
@property(readonly, getter = isDisplayingImage) BOOL displayingImage;
@property(readonly) BOOL canShowInfo;
@property(readonly) BOOL shouldShowInfo;
@property(readonly) BOOL loadingIndicatorShown;
@property(assign) BOOL findPanelShown;
@property(readonly) NSDate *nextTimerFireDate;
@property(assign) BOOL timerRunning;

- (BOOL)setActiveDocument:(PGDocument *)document closeIfAppropriate:(BOOL)flag; // Returns YES if the window was closed.
- (void)activateDocument:(PGDocument *)document;

- (void)setActiveNode:(PGNode *)aNode forward:(BOOL)flag;
- (BOOL)tryToSetActiveNode:(PGNode *)aNode forward:(BOOL)flag;
- (BOOL)tryToGoForward:(BOOL)forward allowAlerts:(BOOL)flag;
- (void)loopForward:(BOOL)flag;
- (void)prepareToLoop; // Call this before sending -tryToLoop….
- (BOOL)tryToLoopForward:(BOOL)loopForward toNode:(PGNode *)node pageForward:(BOOL)pageForward allowAlerts:(BOOL)flag;
- (void)activateNode:(PGNode *)node;

- (void)showLoadingIndicator;
- (void)offerToOpenBookmark:(PGBookmark *)bookmark;
- (void)advanceOnTimer;

- (void)zoomBy:(CGFloat)factor animate:(BOOL)flag;
- (BOOL)zoomKeyDown:(NSEvent *)firstEvent;

- (void)clipViewFrameDidChange:(NSNotification *)aNotif;

- (void)nodeLoadingDidProgress:(NSNotification *)aNotif;
- (void)nodeReadyForViewing:(NSNotification *)aNotif;

- (void)documentWillRemoveNodes:(NSNotification *)aNotif;
- (void)documentSortedNodesDidChange:(NSNotification *)aNotif;
- (void)documentNodeDisplayNameDidChange:(NSNotification *)aNotif;
- (void)documentNodeIsViewableDidChange:(NSNotification *)aNotif;
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif;

- (void)documentShowsInfoDidChange:(NSNotification *)aNotif;
- (void)documentShowsThumbnailsDidChange:(NSNotification *)aNotif;
- (void)documentReadingDirectionDidChange:(NSNotification *)aNotif;
- (void)documentImageScaleDidChange:(NSNotification *)aNotif;
- (void)documentAnimatesImagesDidChange:(NSNotification *)aNotif;
- (void)documentTimerIntervalDidChange:(NSNotification *)aNotif;

- (void)thumbnailControllerContentInsetDidChange:(NSNotification *)aNotif;
- (void)prefControllerBackgroundPatternColorDidChange:(NSNotification *)aNotif;

@end
