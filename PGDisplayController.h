/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
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

// Other
#import "PGGeometry.h"

extern NSString *const PGDisplayControllerActiveNodeDidChangeNotification;
extern NSString *const PGDisplayControllerTimerDidChangeNotification;

@interface PGDisplayController : NSWindowController
{
	@protected
	IBOutlet PGClipView          *clipView;
	IBOutlet PGImageView         *imageView;
	         PGPageLocation      _initialLocation;

	@private
	         unsigned            _displayImageIndex;

	         PGBezelPanel       *_graphicPanel;
	         PGLoadingGraphic   *_loadingGraphic;
	         PGBezelPanel       *_infoPanel;

	IBOutlet PGFindView          *findView;
	IBOutlet NSSearchField       *searchField;
	         PGBezelPanel       *_findPanel;
	         PGFindlessTextView *_findFieldEditor;

	IBOutlet NSView              *errorView;
	IBOutlet NSTextField         *errorLabel;
	IBOutlet NSTextField         *errorMessage;
	IBOutlet NSButton            *reloadButton;
	IBOutlet NSView              *passwordView;
	IBOutlet NSTextField         *passwordLabel;
	IBOutlet NSTextField         *passwordField;
	IBOutlet NSView              *encodingView;
	IBOutlet NSTextField         *encodingLabel;

	         PGDocument         *_activeDocument;
	         PGNode             *_activeNode;

	         NSTimeInterval      _timerInterval;
	         NSDate             *_nextTimerFireDate;
	         NSTimer            *_timer;
}

+ (NSArray *)pasteboardTypes;

- (IBAction)revealInPathFinder:(id)sender;
- (IBAction)revealInFinder:(id)sender;
- (IBAction)revealInBrowser:(id)sender;
- (IBAction)extractImages:(id)sender;
- (IBAction)moveToTrash:(id)sender;

- (IBAction)copy:(id)sender;
- (IBAction)changeOrientation:(id)sender; // Gets the orientation from [sender tag].
- (IBAction)revertOrientation:(id)sender;
- (IBAction)performFindPanelAction:(id)sender;
- (IBAction)hideFindPanel:(id)sender;

- (IBAction)toggleFullscreen:(id)sender;
- (IBAction)toggleOnScreenDisplay:(id)sender;

- (IBAction)zoomIn:(id)sender;
- (IBAction)zoomOut:(id)sender;

- (IBAction)previousPage:(id)sender;
- (IBAction)nextPage:(id)sender;
- (IBAction)firstPage:(id)sender;
- (IBAction)lastPage:(id)sender;

- (IBAction)skipBeforeFolder:(id)sender;
- (IBAction)skipPastFolder:(id)sender;
- (IBAction)firstOfPreviousFolder:(id)sender;
- (IBAction)firstOfNextFolder:(id)sender;
- (IBAction)firstOfFolder:(id)sender;
- (IBAction)lastOfFolder:(id)sender;

- (IBAction)jumpToPage:(id)sender;

- (IBAction)pauseDocument:(id)sender;
- (IBAction)pauseAndCloseDocument:(id)sender;

- (IBAction)reload:(id)sender;
- (IBAction)decrypt:(id)sender;
- (IBAction)chooseEncoding:(id)sender;

- (PGDocument *)activeDocument;
- (BOOL)setActiveDocument:(PGDocument *)document closeIfAppropriate:(BOOL)flag; // Returns YES if the window was closed.
- (void)activateDocument:(PGDocument *)document; // Abstract.

- (PGNode *)activeNode;
- (void)setActiveNode:(PGNode *)aNode initialLocation:(PGPageLocation)location;
- (BOOL)tryToSetActiveNode:(PGNode *)aNode initialLocation:(PGPageLocation)location;
- (BOOL)tryToGoForward:(BOOL)forward allowAlerts:(BOOL)flag;
- (void)prepareToLoop; // Call this before sending -tryToLoop….
- (BOOL)tryToLoopForward:(BOOL)forward toNode:(PGNode *)node initialLocation:(PGPageLocation)loc allowAlerts:(BOOL)flag;
- (void)showNode:(PGNode *)node;

- (PGImageView *)imageView;
- (void)setImageView:(PGImageView *)aView;
- (void)sendComponentsTo:(PGDisplayController *)controller;

- (BOOL)loadingIndicatorShown;
- (void)showLoadingIndicator;

- (BOOL)findPanelShown;
- (void)setFindPanelShown:(BOOL)flag;

- (NSDate *)nextTimerFireDate;
- (NSTimeInterval)timerInterval;
- (void)setTimerInterval:(NSTimeInterval)time; // 0 for off.
- (void)advanceOnTimer:(NSTimer *)timer;

- (void)clipViewFrameDidChange:(NSNotification *)aNotif;

- (void)nodeLoadingDidProgress:(NSNotification *)aNotif;
- (void)nodeReadyForViewing:(NSNotification *)aNotif;

- (void)documentWillRemoveNodes:(NSNotification *)aNotif;
- (void)documentSortedNodesDidChange:(NSNotification *)aNotif;
- (void)documentNodeDisplayNameDidChange:(NSNotification *)aNotif;
- (void)documentNodeIsViewableDidChange:(NSNotification *)aNotif;
- (void)documentShowsOnScreenDisplayDidChange:(NSNotification *)aNotif;
- (void)documentReadingDirectionDidChange:(NSNotification *)aNotif;
- (void)documentImageScaleDidChange:(NSNotification *)aNotif;
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif;

- (void)prefControllerBackgroundPatternColorDidChange:(NSNotification *)aNotif;

@end
