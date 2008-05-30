/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import <Cocoa/Cocoa.h>

// Models
#import "PGPrefObject.h"
@class PGDocument;
@class PGResourceIdentifier;
@class PGBookmark;

// Controllers
@class PGDisplayController;
@class PGFullscreenController;
@class PGExifPanel;

extern NSString *const PGDocumentControllerBackgroundPatternColorDidChangeNotification;
extern NSString *const PGDocumentControllerDisplayScreenDidChangeNotification;

extern NSString *const PGCFBundleTypeExtensionsKey;
extern NSString *const PGCFBundleTypeOSTypesKey;
extern NSString *const PGCFBundleTypeMIMETypesKey;
extern NSString *const PGLSTypeIsPackageKey;
extern NSString *const PGBundleTypeFourCCKey;

OSType PGHFSTypeCodeForPseudoFileType(NSString *type);
NSString *PGPseudoFileTypeForHFSTypeCode(OSType type); // NSFileTypeForHFSTypeCode() uses a private format that's different from what appears in our Info.plist file under CFBundleTypeOSTypes.

@interface PGDocumentController : NSResponder
{
	@private
	IBOutlet NSView                  *colorPanelAccessory;
	IBOutlet NSButton                *checkerboardBackground;
	IBOutlet NSMenu                  *screenMenu;

	IBOutlet NSMenuItem              *precedingSwitchItem;
	IBOutlet NSMenuItem              *switchToPathFinder;
	IBOutlet NSMenuItem              *switchToFinder;
	IBOutlet NSMenuItem              *precedingRevealItem;
	IBOutlet NSMenuItem              *revealInPathFinder;
	IBOutlet NSMenuItem              *revealInFinder;
	IBOutlet NSMenuItem              *revealInBrowser;
	         NSCountedSet           *_runningApps;
	         BOOL                    _revealsInBrowser;

	IBOutlet NSMenu                  *recentMenu;
	         NSMenuItem             *_recentMenuSeparatorItem;

	IBOutlet NSMenuItem              *toggleFullscreen;
	IBOutlet NSMenuItem              *toggleInfo;
	IBOutlet NSMenuItem              *toggleExif;

	IBOutlet NSMenuItem              *rotateRight;
	IBOutlet NSMenuItem              *rotateLeft;
	IBOutlet NSMenuItem              *rotate180;
	IBOutlet NSMenuItem              *flipHorz;
	IBOutlet NSMenuItem              *flipVert;

	IBOutlet NSMenuItem              *fitToView;
	IBOutlet NSMenuItem              *zoomIn;

	IBOutlet NSMenuItem              *pageMenuItem;
	IBOutlet NSMenu                  *defaultPageMenu;
	IBOutlet NSMenuItem              *firstPage;
	IBOutlet NSMenuItem              *previousPage;
	IBOutlet NSMenuItem              *nextPage;
	IBOutlet NSMenuItem              *lastPage;

	IBOutlet NSMenuItem              *windowsMenuItem;
	IBOutlet NSMenu                  *windowsMenu;
	IBOutlet NSMenuItem              *tabsMenuItem;
	IBOutlet NSMenu                  *tabsMenu;
	IBOutlet NSMenuItem              *tabsSeparator;

	         BOOL                    _prefsLoaded;
	         NSArray                *_recentDocumentIdentifiers;
	         NSColor                *_backgroundColor;
	         PGPatternType           _backgroundPattern;
	         BOOL                    _fullscreen;
	         NSScreen               *_displayScreen;
	         BOOL                    _exifShown;
	         BOOL                    _usesDirectionalMouseButtonMapping;

	         PGDocument             *_currentDocument;
	         NSMutableArray         *_documents;
	         PGFullscreenController *_fullscreenController;
	         BOOL                    _inFullscreen;
	         PGExifPanel            *_exifPanel;
}

+ (PGDocumentController *)sharedDocumentController;

- (IBAction)orderFrontColorPanel:(id)sender;
- (IBAction)changeBackgroundColor:(id)sender;
- (IBAction)changeBackgroundPattern:(id)sender;
- (IBAction)useScreen:(id)sender;
- (IBAction)provideFeedback:(id)sender;

- (IBAction)switchToPathFinder:(id)sender;
- (IBAction)switchToFinder:(id)sender;

- (IBAction)openDocument:(id)sender;
- (IBAction)openURL:(id)sender;
- (IBAction)openRecentDocument:(id)sender;
- (IBAction)clearRecentDocuments:(id)sender;

- (IBAction)toggleExif:(id)sender;

- (IBAction)changeImageScalingMode:(id)sender; // PGImageScalingMode from [sender tag].
- (IBAction)changeImageScalingConstraint:(id)sender; // PGImageScalingConstraint from [sender tag].
- (IBAction)changeImageScaleFactor:(id)sender; // 2 to the power of [sender tag].

- (IBAction)changeSortOrder:(id)sender; // PGSortOrder from [sender tag].
- (IBAction)changeSortDirection:(id)sender; // PGSortDescendingMask from [sender tag].
- (IBAction)changeSortRepeat:(id)sender; // PGSortOrder from [sender tag].
- (IBAction)changeReadingDirection:(id)sender; // PGReadingDirection from [sender tag].

- (NSArray *)recentDocumentIdentifiers;
- (void)setRecentDocumentIdentifiers:(NSArray *)anArray;
- (unsigned)maximumRecentDocumentCount;

- (NSColor *)backgroundPatternColor;
- (NSColor *)backgroundColor;
- (void)setBackgroundColor:(NSColor *)aColor;
- (PGPatternType)backgroundPattern;
- (void)setBackgroundPattern:(PGPatternType)aPattern;

- (PGDisplayController *)displayControllerForNewDocument; // Returns either the shared fullscreen controller or a new regular window controller.
- (BOOL)fullscreen;
- (void)setFullscreen:(BOOL)flag;
- (NSScreen *)displayScreen;
- (void)setDisplayScreen:(NSScreen *)anObject;

- (BOOL)exifShown;
- (void)setExifShown:(BOOL)flag;

- (BOOL)usesDirectionalMouseButtonMapping;
- (void)setUsesDirectionalMouseButtonMapping:(BOOL)flag;

- (NSArray *)documents;
- (void)addDocument:(PGDocument *)document;
- (void)removeDocument:(PGDocument *)document;
- (id)documentForResourceIdentifier:(PGResourceIdentifier *)ident;
- (NSMenuItem *)tabMenuItemForDocument:(PGDocument *)document;

- (NSMenu *)defaultPageMenu;
- (PGPrefObject *)currentPrefObject; // Current doc or PGGlobalPrefObject().
- (PGDocument *)currentDocument;
- (void)setCurrentDocument:(PGDocument *)document;

- (NSArray *)documentTypeDictionaries;
- (NSArray *)supportedExtensions;
- (NSDictionary *)documentTypeDictionaryWhereAttribute:(NSString *)key matches:(id)value; // First tries -containsObject:, then -isEqual:. Returns the first applicable type. If 'key' is nil, returns the first type. If 'value' is nil, returns nil.
- (Class)resourceAdapterClassWhereAttribute:(NSString *)key matches:(id)value;
- (Class)resourceAdapterClassForExtension:(NSString *)ext;

- (id)openDocumentWithContentsOfURL:(NSURL *)URL display:(BOOL)display;
- (id)openDocumentWithBookmark:(PGBookmark *)aBookmark display:(BOOL)display;
- (void)noteNewRecentDocument:(PGDocument *)document;

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;

- (void)workspaceDidLaunchApplication:(NSNotification *)aNotif;
- (void)workspaceDidTerminateApplication:(NSNotification *)aNotif;
- (void)readingDirectionDidChange:(NSNotification *)aNotif;
- (void)showsOnScreenDisplayDidChange:(NSNotification *)aNotif;

@end
