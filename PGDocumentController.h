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
#import <Cocoa/Cocoa.h>

// Models
#import "PGPrefObject.h"
@class PGDocument;
@class PGResourceIdentifier;
@class PGBookmark;

// Controllers
#import "PGDisplayControlling.h"
@class PGDisplayController;
@class PGFullscreenController;
@class PGExifPanelController;
@class PGTimerPanelController;
@class PGActivityPanelController;

extern NSString *const PGAntialiasWhenUpscalingKey;
extern NSString *const PGRoundsImageCornersKey;
extern NSString *const PGAutozoomsWindowsKey;
extern NSString *const PGOnlyAutozoomsSingleImagesKey;
extern NSString *const PGBackgroundColorKey;
extern NSString *const PGBackgroundPatternKey;
extern NSString *const PGMouseClickActionKey;
extern NSString *const PGEscapeKeyMappingKey;
extern NSString *const PGDimOtherScreensKey;
extern NSString *const PGBackwardsInitialLocationKey;

enum {
	PGNextPreviousAction = 0,
	PGLeftRightAction    = 1,
	PGRightLeftAction    = 2
};
enum {
	PGFullscreenMapping = 0,
	PGQuitMapping       = 1
};

OSType PGHFSTypeCodeForPseudoFileType(NSString *type);
NSString *PGPseudoFileTypeForHFSTypeCode(OSType type); // NSFileTypeForHFSTypeCode() uses a private format that's different from what appears in our Info.plist file under CFBundleTypeOSTypes.

@interface PGDocumentController : NSResponder <NSApplicationDelegate, NSMenuDelegate, PGDisplayControlling>
{
	@private
	IBOutlet NSMenu *recentMenu;
	NSMenuItem *_recentMenuSeparatorItem;

	IBOutlet NSMenuItem *rotate90CC;
	IBOutlet NSMenuItem *rotate270CC;
	IBOutlet NSMenuItem *rotate180;
	IBOutlet NSMenuItem *mirrorHorz;
	IBOutlet NSMenuItem *mirrorVert;

	IBOutlet NSMenuItem *toggleFullscreen;
	IBOutlet NSMenuItem *toggleInfo;
	IBOutlet NSMenuItem *zoomIn;
	IBOutlet NSMenuItem *zoomOut;

	IBOutlet NSMenuItem *pageMenuItem;
	IBOutlet NSMenu *defaultPageMenu;
	IBOutlet NSMenuItem *firstPage;
	IBOutlet NSMenuItem *previousPage;
	IBOutlet NSMenuItem *nextPage;
	IBOutlet NSMenuItem *lastPage;

	IBOutlet NSMenu *windowsMenu;
	IBOutlet NSMenuItem *windowsMenuSeparator;
	IBOutlet NSMenuItem *selectPreviousDocument;
	IBOutlet NSMenuItem *selectNextDocument;

	NSTimer *_updateTimer;
	NSArray *_recentDocumentIdentifiers;
	BOOL _fullscreen;

	PGDocument *_currentDocument;
	NSMutableArray *_documents;
	PGFullscreenController *_fullscreenController;
	BOOL _inFullscreen;

	PGExifPanelController *_exifPanel;
	PGTimerPanelController *_timerPanel;
	PGActivityPanelController *_activityPanel;

	NSMutableDictionary *_classesByExtension;
}

+ (PGDocumentController *)sharedDocumentController;

- (IBAction)orderFrontStandardAboutPanel:(id)sender;
- (IBAction)installUpdate:(id)sender;
- (IBAction)showPreferences:(id)sender;
- (IBAction)switchToFileManager:(id)sender;

- (IBAction)open:(id)sender;
- (IBAction)openURL:(id)sender;
- (IBAction)openRecentDocument:(id)sender;
- (IBAction)clearRecentDocuments:(id)sender;
- (IBAction)closeAll:(id)sender;

- (IBAction)changeImageScaleMode:(id)sender; // PGImageScaleMode from [sender tag].
- (IBAction)changeImageScaleConstraint:(id)sender; // PGImageScaleConstraint from [sender tag].
- (IBAction)changeImageScaleFactor:(id)sender; // 2 to the power of [sender tag].

- (IBAction)changeSortOrder:(id)sender; // PGSortOrder from [sender tag].
- (IBAction)changeSortDirection:(id)sender; // PGSortDescendingMask from [sender tag].
- (IBAction)changeSortRepeat:(id)sender; // PGSortOrder from [sender tag].
- (IBAction)changeReadingDirection:(id)sender; // PGReadingDirection from [sender tag].

- (IBAction)toggleExif:(id)sender;
- (IBAction)toggleTimer:(id)sender;
- (IBAction)toggleActivity:(id)sender;
- (IBAction)selectPreviousDocument:(id)sender;
- (IBAction)selectNextDocument:(id)sender;
- (IBAction)activateDocument:(id)sender;

- (IBAction)showKeyboardShortcuts:(id)sender;

- (BOOL)performEscapeKeyAction;
- (BOOL)performZoomIn;
- (BOOL)performZoomOut;
- (BOOL)performToggleFullscreen;
- (BOOL)performToggleInfo;

@property(copy) NSArray *recentDocumentIdentifiers;
@property(readonly) NSUInteger maximumRecentDocumentCount;
@property(readonly) PGDisplayController *displayControllerForNewDocument;
@property(assign, getter = isFullscreen) BOOL fullscreen;
@property(readonly) BOOL canToggleFullscreen;
@property(readonly) NSArray *documents;
@property(readonly) NSMenu *defaultPageMenu;
@property(readonly) PGPrefObject *currentPrefObject;
@property(assign) PGDocument *currentDocument;
@property(readonly) BOOL pathFinderRunning;

- (void)addDocument:(PGDocument *)document;
- (void)removeDocument:(PGDocument *)document;
- (PGDocument *)documentForIdentifier:(PGResourceIdentifier *)ident;
- (PGDocument *)next:(BOOL)flag documentBeyond:(PGDocument *)document;
- (NSMenuItem *)windowsMenuItemForDocument:(PGDocument *)document;

- (id)openDocumentWithContentsOfIdentifier:(PGResourceIdentifier *)ident display:(BOOL)flag;
- (id)openDocumentWithContentsOfURL:(NSURL *)URL display:(BOOL)flag;
- (id)openDocumentWithBookmark:(PGBookmark *)aBookmark display:(BOOL)flag;
- (void)noteNewRecentDocument:(PGDocument *)document;

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;

- (void)recentDocumentIdentifierDidChange:(NSNotification *)aNotif;
- (void)readingDirectionDidChange:(NSNotification *)aNotif;

@end
