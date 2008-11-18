/* Copyright © 2007-2008, The Sequential Project
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

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGDocumentController.h"
#import <Carbon/Carbon.h>
#import <sys/resource.h>
#import <objc/Protocol.h>

// Models
#import "PGDocument.h"
#import "PGResourceAdapter.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Controllers
#import "PGPrefController.h"
#import "PGDisplayController.h"
#import "PGWindowController.h"
#import "PGFullscreenController.h"
#import "PGExifPanelController.h"
#import "PGTimerPanelController.h"
#import "PGActivityPanelController.h"
#import "PGURLAlert.h"

// Other
#import "PGAttachments.h"
#import "PGKeyboardLayout.h"
#import "PGLegacy.h"

// Categories
#import "NSArrayAdditions.h"
#import "NSColorAdditions.h"
#import "NSMenuItemAdditions.h"
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"
#import "NSUserDefaultsAdditions.h"

NSString *const PGAntialiasWhenUpscalingKey    = @"PGAntialiasWhenUpscaling";
NSString *const PGRoundsImageCornersKey        = @"PGRoundsImageCorners";
NSString *const PGAutozoomsWindowsKey          = @"PGAutozoomsWindows";
NSString *const PGOnlyAutozoomsSingleImagesKey = @"PGOnlyAutozoomsSingleImages";
NSString *const PGBackgroundColorKey           = @"PGBackgroundColor";
NSString *const PGBackgroundPatternKey         = @"PGBackgroundPattern";
NSString *const PGMouseClickActionKey          = @"PGMouseClickAction";
NSString *const PGEscapeKeyMappingKey          = @"PGEscapeKeyMapping";

static NSString *const PGRecentItemsKey            = @"PGRecentItems2";
static NSString *const PGRecentItemsDeprecated2Key = @"PGRecentItems"; // Deprecated after 1.3.2
static NSString *const PGRecentItemsDeprecatedKey  = @"PGRecentDocuments"; // Deprecated after 1.2.2.
static NSString *const PGFullscreenKey             = @"PGFullscreen";

static NSString *const PGPathFinderApplicationName = @"Path Finder";

OSType PGHFSTypeCodeForPseudoFileType(NSString *type)
{
	return type ? CFSwapInt32BigToHost(*(OSType *)[[type dataUsingEncoding:NSUTF8StringEncoding] bytes]) : '????';
}
NSString *PGPseudoFileTypeForHFSTypeCode(OSType type)
{
	OSType const swapped = CFSwapInt32HostToBig(type);
	return [[[NSString alloc] initWithBytes:(const void *)&swapped length:4 encoding:NSUTF8StringEncoding] autorelease];
}

static PGDocumentController *PGSharedDocumentController = nil;

@interface PGDocumentController (Private)

- (void)_setFullscreen:(BOOL)flag;
- (void)_setPageMenu:(NSMenu *)aMenu;
- (PGDocument *)_openNew:(BOOL)flag document:(PGDocument *)document display:(BOOL)display;

@end

@implementation PGDocumentController

#pragma mark Class Methods

+ (PGDocumentController *)sharedDocumentController
{
	return PGSharedDocumentController ? PGSharedDocumentController : [[self alloc] init];
}

#pragma mark NSObject

+ (void)initialize
{
	if([PGDocumentController class] != self) return;
	NSNumber *const yes = [NSNumber numberWithBool:YES], *no = [NSNumber numberWithBool:NO];
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		yes, PGAntialiasWhenUpscalingKey,
		yes, PGRoundsImageCornersKey,
		yes, PGAutozoomsWindowsKey,
		yes, PGOnlyAutozoomsSingleImagesKey,
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]], PGBackgroundColorKey,
		[NSNumber numberWithUnsignedInt:PGNoPattern], PGBackgroundPatternKey,
		[NSNumber numberWithInt:PGNextPreviousAction], PGMouseClickActionKey,
		[NSNumber numberWithUnsignedInt:1], PGMaxDepthKey,
		no, PGFullscreenKey,
		[NSNumber numberWithInt:PGFullscreenMapping], PGEscapeKeyMappingKey,
		nil]];
}

#pragma mark Instance Methods

- (IBAction)provideFeedback:(id)sender
{
	if(![[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:sequential@comcast.net"]]) NSBeep();
}
- (IBAction)showPreferences:(id)sender
{
	[[PGPrefController sharedPrefController] showWindow:self];
}
- (IBAction)switchToFileManager:(id)sender
{
	if(![[[[NSAppleScript alloc] initWithSource:([self pathFinderRunning] ? @"tell application \"Path Finder\" to activate" : @"tell application \"Finder\" to activate")] autorelease] executeAndReturnError:NULL]) NSBeep();
}

#pragma mark -

- (IBAction)open:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	NSOpenPanel *const openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	NSURL *const URL = [[[self currentDocument] identifier] URL];
	NSString *const path = [URL isFileURL] ? [URL path] : nil;
	if([openPanel runModalForDirectory:[path stringByDeletingLastPathComponent] file:[path lastPathComponent] types:[PGResourceAdapter supportedExtensionsWhichMustAlwaysLoad:NO]] == NSOKButton) [self application:NSApp openFiles:[openPanel filenames]];
}
- (IBAction)openURL:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	NSURL *const URL = [(PGURLAlert *)[[[PGURLAlert alloc] init] autorelease] runModal];
	if(URL) [self openDocumentWithContentsOfURL:URL display:YES];
}
- (IBAction)openRecentDocument:(id)sender
{
	NSURL *const URL = [[sender representedObject] URL];
	if(URL) [self openDocumentWithContentsOfURL:URL display:YES];
}
- (IBAction)clearRecentDocuments:(id)sender
{
	[self setRecentDocumentIdentifiers:[NSArray array]];
}
- (IBAction)closeAll:(id)sender
{
	[[_fullscreenController window] close];
	PGDocument *doc;
	NSEnumerator *const docEnum = [[self documents] objectEnumerator];
	while((doc = [docEnum nextObject])) [[[doc displayController] window] performClose:self];
}

#pragma mark -

- (IBAction)changeImageScaleMode:(id)sender
{
	[[self currentPrefObject] setImageScaleMode:[sender tag]];
}
- (IBAction)changeImageScaleConstraint:(id)sender
{
	[[self currentPrefObject] setImageScaleConstraint:[sender tag]];
}
- (IBAction)changeImageScaleFactor:(id)sender
{
	[[self currentPrefObject] setImageScaleFactor:powf(2, [sender tag])];
}

#pragma mark -

- (IBAction)changeSortOrder:(id)sender
{
	[[self currentPrefObject] setSortOrder:(([sender tag] & PGSortOrderMask) | ([[self currentPrefObject] sortOrder] & PGSortOptionsMask))];
}
- (IBAction)changeSortDirection:(id)sender
{
	[[self currentPrefObject] setSortOrder:(([[self currentPrefObject] sortOrder] & ~PGSortDescendingMask) | [sender tag])];
}
- (IBAction)changeSortRepeat:(id)sender
{
	[[self currentPrefObject] setSortOrder:(([[self currentPrefObject] sortOrder] & ~PGSortRepeatMask) | [sender tag])];
}
- (IBAction)changeReadingDirection:(id)sender
{
	[[self currentPrefObject] setReadingDirection:[sender tag]];
}

#pragma mark -

- (IBAction)toggleExif:(id)sender
{
	[_exifPanel toggleShown];
}
- (IBAction)toggleTimer:(id)sender
{
	[_timerPanel toggleShown];
}
- (IBAction)toggleActivity:(id)sender
{
	[_activityPanel toggleShown];
}
- (IBAction)selectPreviousDocument:(id)sender
{
	PGDocument *const doc = [self next:NO documentBeyond:[self currentDocument]];
	[[doc displayController] activateDocument:doc];
}
- (IBAction)selectNextDocument:(id)sender
{
	PGDocument *const doc = [self next:YES documentBeyond:[self currentDocument]];
	[[doc displayController] activateDocument:doc];
}
- (IBAction)activateDocument:(id)sender
{
	PGDocument *const doc = [sender representedObject];
	[[doc displayController] activateDocument:doc];
}

#pragma mark -

- (IBAction)showKeyboardShortcuts:(id)sender
{
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"shortcuts" inBook:@"Sequential Help"];
}

#pragma mark -

- (BOOL)performEscapeKeyAction
{
	switch([[[NSUserDefaults standardUserDefaults] objectForKey:PGEscapeKeyMappingKey] intValue]) {
		case PGFullscreenMapping: return [self performToggleFullscreen];
		case PGQuitMapping: [NSApp terminate:self]; return YES;
	}
	return NO;
}
- (BOOL)performZoomIn
{
	return [zoomIn AE_performAction];
}
- (BOOL)performZoomOut
{
	return [zoomOut AE_performAction];
}
- (BOOL)performToggleFullscreen
{
	return [toggleFullscreen AE_performAction];
}
- (BOOL)performToggleInfo
{
	return [toggleInfo AE_performAction];
}

#pragma mark -

- (BOOL)pathFinderRunning
{
	NSDictionary *dict;
	NSEnumerator *const dictEnum = [[[NSWorkspace sharedWorkspace] launchedApplications] objectEnumerator];
	while((dict = [dictEnum nextObject])) if([PGPathFinderApplicationName isEqualToString:[dict objectForKey:@"NSApplicationName"]]) return YES;
	return NO;
}

#pragma mark -

- (NSArray *)recentDocumentIdentifiers
{
	return [[_recentDocumentIdentifiers retain] autorelease];
}
- (void)setRecentDocumentIdentifiers:(NSArray *)anArray
{
	NSParameterAssert(anArray);
	if(_prefsLoaded && [anArray isEqual:_recentDocumentIdentifiers]) return;
	[_recentDocumentIdentifiers AE_removeObjectObserver:self name:PGResourceIdentifierIconDidChangeNotification];
	[_recentDocumentIdentifiers AE_removeObjectObserver:self name:PGResourceIdentifierDisplayNameDidChangeNotification];
	[_recentDocumentIdentifiers release];
	_recentDocumentIdentifiers = [[anArray subarrayWithRange:NSMakeRange(0, MIN([anArray count], [self maximumRecentDocumentCount]))] retain];
	[_recentDocumentIdentifiers AE_addObjectObserver:self selector:@selector(recentDocumentIdentifierDidChange:) name:PGResourceIdentifierIconDidChangeNotification];
	[_recentDocumentIdentifiers AE_addObjectObserver:self selector:@selector(recentDocumentIdentifierDidChange:) name:PGResourceIdentifierDisplayNameDidChangeNotification];
	[self recentDocumentIdentifierDidChange:nil];
}
- (unsigned)maximumRecentDocumentCount
{
	return 10;
}

#pragma mark -

- (PGDisplayController *)displayControllerForNewDocument
{
	if([self fullscreen]) {
		if(!_fullscreenController) _fullscreenController = [[PGFullscreenController alloc] init];
		return _fullscreenController;
	}
	return [[[PGWindowController alloc] init] autorelease];
}
- (BOOL)fullscreen
{
	return _fullscreen;
}
- (void)setFullscreen:(BOOL)flag
{
	if(_prefsLoaded && flag == _fullscreen) return;
	_fullscreen = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGFullscreenKey];
	[self _setFullscreen:flag];
}

#pragma mark -

- (NSArray *)documents
{
	return [[_documents copy] autorelease];
}
- (void)addDocument:(PGDocument *)document
{
	NSParameterAssert([_documents indexOfObjectIdenticalTo:document] == NSNotFound);
	if(![_documents count]) [windowsMenu addItem:windowsMenuSeparator];
	[_documents addObject:document];
	NSMenuItem *const item = [[[NSMenuItem alloc] init] autorelease];
	[item setRepresentedObject:document];
	[item setAction:@selector(activateDocument:)];
	[item setTarget:self];
	[windowsMenu addItem:item];
	[self _setFullscreen:YES];
}
- (void)removeDocument:(PGDocument *)document
{
	NSParameterAssert(!document || [_documents indexOfObjectIdenticalTo:document] != NSNotFound);
	if(document == [self currentDocument]) [self setCurrentDocument:nil];
	if(!document) return;
	[_documents removeObject:document];
	unsigned const i = [windowsMenu indexOfItemWithRepresentedObject:document];
	if(NSNotFound != i) [windowsMenu removeItemAtIndex:i];
	if(![_documents count]) [windowsMenuSeparator AE_removeFromMenu];
	[self _setFullscreen:[_documents count] > 0];
}
- (PGDocument *)documentForResourceIdentifier:(PGResourceIdentifier *)ident
{
	PGDocument *doc;
	NSEnumerator *const docEnum = [_documents objectEnumerator];
	while((doc = [docEnum nextObject])) if([[doc identifier] isEqual:ident]) return doc;
	return nil;
}
- (PGDocument *)next:(BOOL)flag
                documentBeyond:(PGDocument *)document
{
	NSArray *const docs = [[PGDocumentController sharedDocumentController] documents];
	unsigned const count = [docs count];
	if(count <= 1) return nil;
	unsigned i = [docs indexOfObjectIdenticalTo:[self currentDocument]];
	if(NSNotFound == i) return nil;
	if(flag) {
		if([docs count] == ++i) i = 0;
	} else if(0 == i--) i = [docs count] - 1;
	return [docs objectAtIndex:i];
}
- (NSMenuItem *)windowsMenuItemForDocument:(PGDocument *)document
{
	int const i = [windowsMenu indexOfItemWithRepresentedObject:document];
	return -1 == i ? nil : [windowsMenu itemAtIndex:i];
}

#pragma mark -

- (NSMenu *)defaultPageMenu
{
	return [[defaultPageMenu retain] autorelease];
}
- (PGPrefObject *)currentPrefObject
{
	return _currentDocument ? _currentDocument : [PGPrefObject globalPrefObject];
}
- (PGDocument *)currentDocument
{
	return _currentDocument;
}
- (void)setCurrentDocument:(PGDocument *)document
{
	[[self currentPrefObject] AE_removeObserver:self name:PGPrefObjectReadingDirectionDidChangeNotification];
	_currentDocument = document;
	[self _setPageMenu:(_currentDocument ? [_currentDocument pageMenu] : [self defaultPageMenu])];
	[[self currentPrefObject] AE_addObserver:self selector:@selector(readingDirectionDidChange:) name:PGPrefObjectReadingDirectionDidChangeNotification];
	[self readingDirectionDidChange:nil];
}

#pragma mark -

- (id)openDocumentWithContentsOfURL:(NSURL *)URL
      display:(BOOL)display
{
	PGResourceIdentifier *const identifier = [URL AE_resourceIdentifier];
	PGDocument *const doc = [self documentForResourceIdentifier:identifier];
	return [self _openNew:!doc document:(doc ? doc : [[[PGDocument alloc] initWithResourceIdentifier:identifier] autorelease]) display:display];
}
- (id)openDocumentWithBookmark:(PGBookmark *)aBookmark
      display:(BOOL)display
{
	PGDocument *const doc = [self documentForResourceIdentifier:[aBookmark documentIdentifier]];
	[doc openBookmark:aBookmark];
	return [self _openNew:!doc document:(doc ? doc : [[[PGDocument alloc] initWithBookmark:aBookmark] autorelease]) display:display];
}
- (void)noteNewRecentDocument:(PGDocument *)document
{
	PGResourceIdentifier *const identifier = [document identifier];
	if(!identifier) return;
	NSMutableArray *const identifiers = [[[self recentDocumentIdentifiers] mutableCopy] autorelease];
	[identifiers removeObject:identifier];
	[identifiers insertObject:identifier atIndex:0];
	[self setRecentDocumentIdentifiers:identifiers];
}

#pragma mark -

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event
        withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	if([event eventClass] == kInternetEventClass && [event eventID] == kAEGetURL) [self openDocumentWithContentsOfURL:[NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]] display:YES];
}

#pragma mark -

- (void)recentDocumentIdentifierDidChange:(NSNotification *)aNotif
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_recentDocumentIdentifiers] forKey:PGRecentItemsKey];
}

- (void)readingDirectionDidChange:(NSNotification *)aNotif
{
	NSString *prev, *next;
	if([[self currentPrefObject] readingDirection] == PGReadingDirectionLeftToRight) prev = @"[", next = @"]";
	else prev = @"]", next = @"[";
	[previousPage setKeyEquivalent:prev];
	[nextPage setKeyEquivalent:next];
	[firstPage setKeyEquivalent:prev];
	[lastPage setKeyEquivalent:next];
	[previousPage setKeyEquivalentModifierMask:0];
	[nextPage setKeyEquivalentModifierMask:0];
}

#pragma mark Private Protocol

- (void)_setFullscreen:(BOOL)flag
{
	if(flag == _inFullscreen) return;
	NSDisableScreenUpdates();
	if(!flag) {
		_inFullscreen = flag;
		[_fullscreenController prepareToExitFullscreen];
		NSMutableArray *const docs = [[[self documents] mutableCopy] autorelease];
		PGDocument *const currentDoc = [_fullscreenController activeDocument];
		if(currentDoc) {
			[docs removeObjectIdenticalTo:currentDoc];
			[docs addObject:currentDoc];
		}
		PGDocument *doc;
		NSEnumerator *const docEnum = [docs objectEnumerator];
		while((doc = [docEnum nextObject])) {
			[doc setDisplayController:[self displayControllerForNewDocument]];
			[[doc displayController] showWindow:self];
		}
		[[_fullscreenController window] close];
		[_fullscreenController release];
		_fullscreenController = nil;
	} else if([[self documents] count] && [self fullscreen]) {
		_inFullscreen = flag;
		PGDocument *const currentDoc = [self currentDocument];
		_fullscreenController = [[PGFullscreenController alloc] init];
		PGDocument *doc;
		NSEnumerator *const docEnum = [[self documents] objectEnumerator];
		while((doc = [docEnum nextObject])) {
			PGDisplayController *const oldController = [doc displayController];
			if(!oldController) continue;
			[doc setDisplayController:_fullscreenController];
			[[oldController window] close];
		}
		[_fullscreenController setActiveDocument:currentDoc closeIfAppropriate:NO];
		[_fullscreenController showWindow:self];
	}
	NSEnableScreenUpdates();
}
- (void)_setPageMenu:(NSMenu *)aMenu
{
	NSMenu *const mainMenu = [NSApp mainMenu];
	unsigned const pageMenuItemIndex = [mainMenu indexOfItem:[[pageMenuItem retain] autorelease]];
	if(!PGIsLeopardOrLater()) [mainMenu removeItemAtIndex:pageMenuItemIndex]; // Works around a Tiger bug where two Page menus appear.

	NSMenu *const oldMenu = [pageMenuItem submenu];
	NSMenu *const newMenu = aMenu ? aMenu : defaultPageMenu;
	if(!PGIsLeopardOrLater()) [newMenu setTitle:[pageMenuItem title]]; // Otherwise the title can get changed.
	firstPage = [newMenu itemAtIndex:[oldMenu indexOfItem:firstPage]]; // Since we change the whole menu, make sure to get the current menu's items.
	previousPage = [newMenu itemAtIndex:[oldMenu indexOfItem:previousPage]];
	nextPage = [newMenu itemAtIndex:[oldMenu indexOfItem:nextPage]];
	lastPage = [newMenu itemAtIndex:[oldMenu indexOfItem:lastPage]];
	[pageMenuItem setSubmenu:newMenu];

	if(!PGIsLeopardOrLater()) [mainMenu insertItem:pageMenuItem atIndex:pageMenuItemIndex];
	[self readingDirectionDidChange:nil];
}
- (PGDocument *)_openNew:(BOOL)flag
                document:(PGDocument *)document
                display:(BOOL)display
{
	if(!document) return nil;
	if(flag) [self addDocument:document];
	if(display) [document createUI];
	return document;
}

#pragma mark NSNibAwakening Protocol

- (void)awakeFromNib
{
	[defaultPageMenu retain];
	[windowsMenuSeparator retain];
	[windowsMenuSeparator AE_removeFromMenu];

	[rotate90CC setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGRotationMenuIconCell alloc] initWithMenuItem:rotate90CC rotation:90] autorelease] label:[rotate90CC title]]];
	[rotate270CC setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGRotationMenuIconCell alloc] initWithMenuItem:rotate270CC rotation:-90] autorelease] label:[rotate270CC title]]];
	[rotate180 setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGRotationMenuIconCell alloc] initWithMenuItem:rotate180 rotation:180] autorelease] label:[rotate180 title]]];

	[mirrorHorz setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGMirrorMenuIconCell alloc] initWithMenuItem:mirrorHorz rotation:0] autorelease] label:[mirrorHorz title]]];
	[mirrorVert setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGMirrorMenuIconCell alloc] initWithMenuItem:mirrorVert rotation:90] autorelease] label:[mirrorVert title]]];

	[zoomIn setKeyEquivalent:@"+"];
	[zoomIn setKeyEquivalentModifierMask:0];
	[zoomOut setKeyEquivalent:@"-"];
	[zoomOut setKeyEquivalentModifierMask:0];

	[selectPreviousDocument setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x21E1]];
	[selectPreviousDocument setKeyEquivalentModifierMask:NSCommandKeyMask];
	[selectNextDocument setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x21E3]];
	[selectNextDocument setKeyEquivalentModifierMask:NSCommandKeyMask];

	NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
	[self setFullscreen:[[defaults objectForKey:PGFullscreenKey] boolValue]];
	_prefsLoaded = YES;

	[self setCurrentDocument:nil];
	[self readingDirectionDidChange:nil];
}

#pragma mark PGDisplayControlling Protocol

- (IBAction)reveal:(id)sender {}
- (IBAction)toggleFullscreen:(id)sender {}
- (IBAction)toggleInfo:(id)sender {}
- (IBAction)toggleThumbnails:(id)sender {}

#pragma mark NSMenuValidation Protocol

#define PGFuzzyEqualityToCellState(a, b) ({ double __a = (double)(a); double __b = (double)(b); (fabs(__a - __b) < 0.001f ? NSOnState : (fabs(round(__a) - round(__b)) < 0.1f ? NSMixedState : NSOffState)); })
- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	id const pref = [self currentPrefObject];
	SEL const action = [anItem action];
	int const tag = [anItem tag];

	if([@protocol(PGDisplayControlling) descriptionForInstanceMethod:action]) {
		if(@selector(reveal:) == action) [anItem setTitle:NSLocalizedString(([self pathFinderRunning] ? @"Reveal in Path Finder" : @"Reveal in Finder"), @"Reveal in Finder, Path Finder (www.cocoatech.com) or web browser. Three states of the same item.")];
		if(@selector(toggleFullscreen:) == action) [anItem setTitle:NSLocalizedString((_fullscreen ? @"Exit Full Screen" : @"Enter Full Screen"), @"Enter/exit full screen. Two states of the same item.")];
		if(@selector(toggleInfo:) == action) [anItem setTitle:NSLocalizedString(([[self currentPrefObject] showsInfo] ? @"Hide Info" : @"Show Info"), @"Lets the user toggle the on-screen display. Two states of the same item.")];
		if(@selector(toggleThumbnails:) == action) [anItem setTitle:NSLocalizedString(([[self currentPrefObject] showsThumbnails] ? @"Hide Thumbnails" : @"Show Thumbnails"), @"Lets the user toggle whether thumbnails are shown. Two states of the same item.")];
		return NO;
	}

	if(@selector(switchToFileManager:) == action) [anItem setTitle:NSLocalizedString(([self pathFinderRunning] ? @"Switch to Path Finder" : @"Switch to Finder"), @"Switch to Finder or Path Finder (www.cocoatech.com). Two states of the same item.")];
	else if(@selector(changeReadingDirection:) == action) [anItem setState:[pref readingDirection] == tag];
	else if(@selector(changeImageScaleMode:) == action) {
		if(PGViewFitScale == tag) [anItem setTitle:NSLocalizedString((_fullscreen ? @"Fit to Screen" : @"Fit to Window"), @"Scale image down so the entire thing fits menu item. Two labels, depending on mode.")];
		if(PGConstantFactorScale == tag) [anItem setState:([pref imageScaleMode] == tag ? PGFuzzyEqualityToCellState(0, log2f([pref imageScaleFactor])) : NSOffState)];
		else [anItem setState:[pref imageScaleMode] == tag];
	} else if(@selector(changeImageScaleFactor:) == action) [anItem setState:PGFuzzyEqualityToCellState(tag, log2f([pref imageScaleFactor]))];
	else if(@selector(changeImageScaleConstraint:) == action) [anItem setState:[pref imageScaleConstraint] == tag];
	else if(@selector(changeSortOrder:) == action) [anItem setState:(PGSortOrderMask & [pref sortOrder]) == tag];
	else if(@selector(changeSortDirection:) == action) {
		[anItem setState:tag == (PGSortDescendingMask & [pref sortOrder])];
		if(([pref sortOrder] & PGSortOrderMask) == PGSortShuffle) return NO;
	} else if(@selector(changeSortRepeat:) == action) [anItem setState:(PGSortRepeatMask & [pref sortOrder]) == tag];
	else if(@selector(activateDocument:) == action) [anItem setState:([anItem representedObject] == [self currentDocument])];

	if([[self documents] count] <= 1) {
		if(@selector(selectPreviousDocument:) == action) return NO;
		if(@selector(selectNextDocument:) == action) return NO;
	}
	if(![self currentDocument]) {
		if(@selector(changeReadingDirection:) == action) return NO;
		if(@selector(changeImageScaleMode:) == action) return NO;
		if(@selector(changeImageScaleFactor:) == action) return NO;
		if(@selector(changeImageScaleConstraint:) == action) return NO;
		if(@selector(changeSortOrder:) == action) return NO;
		if(@selector(changeSortDirection:) == action) return NO;
		if(@selector(changeSortRepeat:) == action) return NO;
	}
	return [super validateMenuItem:anItem];
}

#pragma mark NSMenuDelegate Protocol

- (int)numberOfItemsInMenu:(NSMenu *)menu
{
	if(menu == recentMenu) {
		[_recentMenuSeparatorItem AE_removeFromMenu]; // The separator gets moved around as we rebuild the menu.
		NSMutableArray *const identifiers = [NSMutableArray array];
		PGResourceIdentifier *identifier;
		NSEnumerator *const identifierEnum = [[self recentDocumentIdentifiers] objectEnumerator];
		while((identifier = [identifierEnum nextObject])) if([identifier URL]) [identifiers addObject:identifier]; // Make sure the URLs are valid.
		[self setRecentDocumentIdentifiers:identifiers];
		return [identifiers count] + 1;
	}
	return -1;
}
- (BOOL)menu:(NSMenu *)menu
        updateItem:(NSMenuItem *)item
        atIndex:(int)index
        shouldCancel:(BOOL)shouldCancel
{
	NSString *title = @"";
	NSAttributedString *attributedTitle = nil;
	SEL action = NULL;
	id representedObject = nil;
	if(menu == recentMenu) {
		NSArray *const identifiers = [self recentDocumentIdentifiers];
		if((unsigned)index < [identifiers count]) {
			PGResourceIdentifier *const identifier = [identifiers objectAtIndex:index];
			NSString *const name = [identifier displayName];

			BOOL uniqueName = YES;
			PGResourceIdentifier *comparisonIdentifier;
			NSEnumerator *const comparisonIdentifierEnum = [identifiers objectEnumerator];
			while(uniqueName && (comparisonIdentifier = [comparisonIdentifierEnum nextObject])) if(comparisonIdentifier != identifier && [[comparisonIdentifier displayName] isEqual:name]) uniqueName = NO;

			attributedTitle = [identifier attributedStringWithWithAncestory:!uniqueName];
			action = @selector(openRecentDocument:);
			representedObject = identifier;
		} else {
			title = NSLocalizedString(@"Clear Menu", @"Clear the Open Recent menu. Should be the same as the standard text.");
			if(index) {
				if(!_recentMenuSeparatorItem) _recentMenuSeparatorItem = [[NSMenuItem separatorItem] retain];
				[menu insertItem:_recentMenuSeparatorItem atIndex:index];
				action = @selector(clearRecentDocuments:);
			}
		}
	}
	[item setTitle:title];
	[item setAttributedTitle:attributedTitle];
	[item setAction:action];
	[item setRepresentedObject:representedObject];
	return YES;
}

#pragma mark NSApplicationNotifications Protocol

- (BOOL)application:(NSApplication *)sender
        openFile:(NSString *)filename
{
	return !![self openDocumentWithContentsOfURL:[filename AE_fileURL] display:YES];
}
- (void)application:(NSApplication *)sender
        openFiles:(NSArray *)filenames
{
	NSString *filename;
	NSEnumerator *filenameEnum = [filenames objectEnumerator];
	while((filename = [filenameEnum nextObject])) [self openDocumentWithContentsOfURL:[filename AE_fileURL] display:YES];
	[sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

#pragma mark NSResponder

- (BOOL)performKeyEquivalent:(NSEvent *)anEvent
{
	if(!([anEvent modifierFlags] & (NSCommandKeyMask | NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask))) switch([anEvent keyCode]) {
		case PGKeyEscape: [self performEscapeKeyAction]; break;
		case PGKeyQ: [NSApp terminate:self]; return YES;
	}
	return NO;
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];

		id recentItemsData = [defaults objectForKey:PGRecentItemsKey];
		if(!recentItemsData) {
			recentItemsData = [defaults objectForKey:PGRecentItemsDeprecated2Key];
			[defaults removeObjectForKey:PGRecentItemsDeprecated2Key]; // Don't leave unused data around.
		}
		if(!recentItemsData) {
			recentItemsData = [defaults objectForKey:PGRecentItemsDeprecatedKey];
			[defaults removeObjectForKey:PGRecentItemsDeprecatedKey]; // Don't leave unused data around.
		}
		[self setRecentDocumentIdentifiers:(recentItemsData ? [NSKeyedUnarchiver unarchiveObjectWithData:recentItemsData] : [NSArray array])];

		_documents = [[NSMutableArray alloc] init];
		_classesByExtension = [[NSMutableDictionary alloc] init];

		_exifPanel = [[PGExifPanelController alloc] init];
		_timerPanel = [[PGTimerPanelController alloc] init];
		_activityPanel = [[PGActivityPanelController alloc] init];

		if(!PGSharedDocumentController) {
			PGSharedDocumentController = [self retain];
			[[NSAppleEventManager sharedAppleEventManager] setEventHandler:self andSelector:@selector(handleAppleEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
			[self setNextResponder:[NSApp nextResponder]];
			[NSApp setNextResponder:self];
		}
	}
	return self;
}
- (void)dealloc
{
	if(PGSharedDocumentController == self) [[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];
	[self AE_removeObserver];
	[defaultPageMenu release];
	[windowsMenuSeparator release];
	[_recentMenuSeparatorItem release];
	[_recentDocumentIdentifiers release];
	[_documents release];
	[_fullscreenController release];
	[_exifPanel release];
	[_timerPanel release];
	[_activityPanel release];
	[_classesByExtension release];
	[super dealloc];
}

@end

@interface PGApplication : NSApplication
@end
@interface PGWindow : NSWindow
@end
@interface PGView : NSView
@end
@interface PGMenu : NSMenu
@end

@implementation PGApplication

+ (void)initialize
{
	if([PGApplication class] != self) return;
	[PGWindow poseAsClass:[NSWindow class]];
	[PGView poseAsClass:[NSView class]];
	[PGMenu poseAsClass:[NSMenu class]];
	[[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.poisonousinsect.Sequential"]; // Fall back on the old preference file if necessary.
	struct rlimit l = {RLIM_INFINITY, RLIM_INFINITY};
	(void)setrlimit(RLIMIT_NOFILE, &l); // We use a lot of file descriptors, especially prior to Leopard where we don't have FSEvents.
}
- (void)sendEvent:(NSEvent *)anEvent
{
	if([anEvent type] == NSKeyDown) {
		if([[self mainMenu] performKeyEquivalent:anEvent]) return;
		NSWindow *const w = [anEvent window];
		if(w) return [w sendEvent:anEvent];
		else if([[PGDocumentController sharedDocumentController] performKeyEquivalent:anEvent]) return; // Allow our document controller to catch key equivalents.
	}
	[super sendEvent:anEvent];
}

@end

@implementation PGWindow

- (void)sendEvent:(NSEvent *)anEvent
{
	if(!PGIsLeopardOrLater() && [anEvent type] == NSKeyDown && [anEvent modifierFlags] & NSCommandKeyMask) [[self firstResponder] keyDown:anEvent]; // Tiger never lets views catch events with the Command modifier.
	else [super sendEvent:anEvent];
}
- (void)keyDown:(NSEvent *)anEvent
{
	if(![[PGDocumentController sharedDocumentController] performKeyEquivalent:anEvent]) [super keyDown:anEvent]; // Catch events that would normally be swallowed.
}
- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	if(@selector(PG_grow:) == [anItem action]) return !!([self styleMask] & NSResizableWindowMask); // Categories can't call super, and there's only one method that validates every action, so sadly we have to use class posing for this.
	return [super validateMenuItem:anItem];
}

@end

@implementation PGView

// Help tab between windows.
- (NSView *)nextValidKeyView
{
	NSView *const view = [super nextValidKeyView];
	return view ? view : self;
}
- (NSView *)previousValidKeyView
{
	NSView *const view = [super previousValidKeyView];
	return view ? view : self;
}

@end

@implementation PGMenu

- (BOOL)performKeyEquivalent:(NSEvent *)anEvent
{
	if([anEvent type] != NSKeyDown) return NO;
	int i = 0;
	for(; i < [self numberOfItems]; i++) {
		NSMenuItem *const item = [self itemAtIndex:i];
		NSString *const equiv = [item keyEquivalent];
		if([equiv length] != 1) continue;
		unsigned short const keyCode = PGKeyCodeFromUnichar([equiv characterAtIndex:0]);
		if(PGKeyUnknown == keyCode || [anEvent keyCode] != keyCode) continue; // Some non-English keyboard layouts switch to English when the Command key is held, but that doesn't help our shortcuts that don't use Command, so we have to check by key code.
		unsigned const modifiersMask = NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask | NSControlKeyMask;
		if(([anEvent modifierFlags] & modifiersMask) != ([item keyEquivalentModifierMask] & modifiersMask)) continue;
		if([item AE_performAction]) return YES;
		break;
	}
	return [super performKeyEquivalent:anEvent];
}

@end
