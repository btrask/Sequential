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
#import "PGDocumentController.h"
#import <Carbon/Carbon.h>
#import <sys/resource.h>
#import <objc/Protocol.h>
#import "Sparkle/Sparkle.h"
#import <tgmath.h>

// Models
#import "PGDocument.h"
#import "PGResourceAdapter.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Views
#import "PGOrientationMenuItemCell.h"

// Controllers
#import "PGAboutBoxController.h"
#import "PGPreferenceWindowController.h"
#import "PGDisplayController.h"
#import "PGWindowController.h"
#import "PGFullscreenController.h"
#import "PGExifPanelController.h"
#import "PGTimerPanelController.h"
#import "PGActivityPanelController.h"
#import "PGURLAlert.h"

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGDelayedPerforming.h"
#import "PGFoundationAdditions.h"
#import "PGKeyboardLayout.h"
#import "PGLegacy.h"

NSString *const PGAntialiasWhenUpscalingKey = @"PGAntialiasWhenUpscaling";
NSString *const PGBackgroundColorKey = @"PGBackgroundColor";
NSString *const PGBackgroundPatternKey = @"PGBackgroundPattern";
NSString *const PGMouseClickActionKey = @"PGMouseClickAction";
NSString *const PGEscapeKeyMappingKey = @"PGEscapeKeyMapping";
NSString *const PGDimOtherScreensKey = @"PGDimOtherScreens";
NSString *const PGBackwardsInitialLocationKey = @"PGBackwardsInitialLocation";

static NSString *const PGRecentItemsKey = @"PGRecentItems2";
static NSString *const PGRecentItemsDeprecated2Key = @"PGRecentItems"; // Deprecated after 1.3.2
static NSString *const PGRecentItemsDeprecatedKey = @"PGRecentDocuments"; // Deprecated after 1.2.2.
static NSString *const PGFullscreenKey = @"PGFullscreen";

static NSString *const PGCheckForUpdatesKey = @"PGCheckForUpdates";
static NSString *const PGUpdateAvailableKey = @"PGUpdateAvailable";
static NSString *const PGNextUpdateCheckDateKey = @"PGNextUpdateCheckDate";

static NSString *const PGPathFinderApplicationName = @"Path Finder";

static PGDocumentController *PGSharedDocumentController = nil;

@interface PGDocumentController(Private)

- (void)_setFullscreen:(BOOL)flag;
- (PGDocument *)_openNew:(BOOL)flag document:(PGDocument *)document display:(BOOL)display;
- (void)_scheduleNextUpdateCheckWithDate:(NSDate *)date;
- (void)_checkForUpdates;

@end

@implementation PGDocumentController

#pragma mark +PGDocumentController

+ (PGDocumentController *)sharedDocumentController
{
	return PGSharedDocumentController ? PGSharedDocumentController : [[self alloc] init];
}

#pragma mark +NSObject

+ (void)initialize
{
	if([PGDocumentController class] != self) return;
	NSNumber *const yes = [NSNumber numberWithBool:YES], *no = [NSNumber numberWithBool:NO];
	NSUserDefaults *const d = [NSUserDefaults standardUserDefaults];
	[d registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		yes, PGAntialiasWhenUpscalingKey,
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]], PGBackgroundColorKey,
		[NSNumber numberWithUnsignedInteger:PGNoPattern], PGBackgroundPatternKey,
		[NSNumber numberWithInteger:PGNextPreviousAction], PGMouseClickActionKey,
		[NSNumber numberWithUnsignedInteger:1], PGMaxDepthKey,
		no, PGFullscreenKey,
		[NSNumber numberWithInteger:PGFullscreenMapping], PGEscapeKeyMappingKey,
		no, PGDimOtherScreensKey,
		[NSNumber numberWithInteger:PGEndLocation], PGBackwardsInitialLocationKey,
		yes, PGCheckForUpdatesKey,
		no, PGUpdateAvailableKey,
		nil]];
}

#pragma mark -PGDocumentController

- (IBAction)orderFrontStandardAboutPanel:(id)sender
{
	[[PGAboutBoxController sharedAboutBoxController] showWindow:self];
}
- (IBAction)installUpdate:(id)sender
{
	[[SUUpdater sharedUpdater] checkForUpdates:sender]; // We validate this menu item specially but its behavior can just use the normal Sparkle mechanism.
}
- (IBAction)showPreferences:(id)sender
{
	[[PGPreferenceWindowController sharedPrefController] showWindow:self];
}
- (IBAction)switchToFileManager:(id)sender
{
	if(![[[[NSAppleScript alloc] initWithSource:self.pathFinderRunning ? @"tell application \"Path Finder\" to activate" : @"tell application \"Finder\" to activate"] autorelease] executeAndReturnError:NULL]) NSBeep();
}

#pragma mark -

- (IBAction)open:(id)sender
{
	[NSApp activateIgnoringOtherApps:YES];
	NSOpenPanel *const openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	NSURL *const URL = [[[self currentDocument] originalIdentifier] URL];
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
	[self openDocumentWithContentsOfIdentifier:[(NSMenuItem *)sender representedObject] display:YES];
}
- (IBAction)clearRecentDocuments:(id)sender
{
	[self setRecentDocumentIdentifiers:[NSArray array]];
}
- (IBAction)closeAll:(id)sender
{
	[[_fullscreenController window] close];
	for(PGDocument *const doc in [self documents]) [[[doc displayController] window] performClose:self];
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
	PGDocument *const doc = [(NSMenuItem *)sender representedObject];
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
	switch([[[NSUserDefaults standardUserDefaults] objectForKey:PGEscapeKeyMappingKey] integerValue]) {
		case PGFullscreenMapping: return [self performToggleFullscreen];
		case PGQuitMapping: [NSApp terminate:self]; return YES;
	}
	return NO;
}
- (BOOL)performZoomIn
{
	return [zoomIn PG_performAction];
}
- (BOOL)performZoomOut
{
	return [zoomOut PG_performAction];
}
- (BOOL)performToggleFullscreen
{
	return [toggleFullscreen PG_performAction];
}
- (BOOL)performToggleInfo
{
	return [toggleInfo PG_performAction];
}

#pragma mark -

- (NSArray *)recentDocumentIdentifiers
{
	return [[_recentDocumentIdentifiers retain] autorelease];
}
- (void)setRecentDocumentIdentifiers:(NSArray *)anArray
{
	NSParameterAssert(anArray);
	if(PGEqualObjects(anArray, _recentDocumentIdentifiers)) return;
	[_recentDocumentIdentifiers PG_removeObjectObserver:self name:PGDisplayableIdentifierIconDidChangeNotification];
	[_recentDocumentIdentifiers PG_removeObjectObserver:self name:PGDisplayableIdentifierDisplayNameDidChangeNotification];
	[_recentDocumentIdentifiers release];
	_recentDocumentIdentifiers = [[anArray subarrayWithRange:NSMakeRange(0, MIN([anArray count], [self maximumRecentDocumentCount]))] copy];
	[_recentDocumentIdentifiers PG_addObjectObserver:self selector:@selector(recentDocumentIdentifierDidChange:) name:PGDisplayableIdentifierIconDidChangeNotification];
	[_recentDocumentIdentifiers PG_addObjectObserver:self selector:@selector(recentDocumentIdentifierDidChange:) name:PGDisplayableIdentifierDisplayNameDidChangeNotification];
	[self recentDocumentIdentifierDidChange:nil];
}
- (NSUInteger)maximumRecentDocumentCount
{
	return [[[[NSDocumentController alloc] init] autorelease] maximumRecentDocumentCount]; // This is ugly but we don't want to use NSDocumentController.
}
- (PGDisplayController *)displayControllerForNewDocument
{
	if(self.fullscreen) {
		if(!_fullscreenController) _fullscreenController = [[PGFullscreenController alloc] init];
		return _fullscreenController;
	}
	return [[[PGWindowController alloc] init] autorelease];
}
@synthesize fullscreen = _fullscreen;
- (void)setFullscreen:(BOOL)flag
{
	if(flag == _fullscreen) return;
	_fullscreen = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGFullscreenKey];
	[self _setFullscreen:flag];
}
- (BOOL)canToggleFullscreen
{
	if(_fullscreen) return YES;
	for(PGDocument *const doc in [self documents]) if([[[doc displayController] window] attachedSheet]) return NO;
	return YES;
}
@synthesize documents = _documents;
- (NSMenu *)scaleMenu
{
	return [scaleSliderItem menu];
}
- (NSSlider *)scaleSlider
{
	return scaleSlider;
}
@synthesize defaultPageMenu;
@synthesize currentDocument = _currentDocument;
- (void)setCurrentDocument:(PGDocument *)document
{
	_currentDocument = document;
	NSMenu *const menu = [_currentDocument pageMenu];
	[pageMenuItem setSubmenu:menu ? menu : [self defaultPageMenu]];
}
- (BOOL)pathFinderRunning
{
	for(NSDictionary *const dict in [[NSWorkspace sharedWorkspace] launchedApplications]) if(PGEqualObjects([dict objectForKey:@"NSApplicationName"], PGPathFinderApplicationName)) return YES;
	return NO;
}

#pragma mark -

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
	NSUInteger const i = [windowsMenu indexOfItemWithRepresentedObject:document];
	if(NSNotFound != i) [windowsMenu removeItemAtIndex:i];
	if(![_documents count]) [windowsMenuSeparator PG_removeFromMenu];
	[self _setFullscreen:[_documents count] > 0];
}
- (PGDocument *)documentForIdentifier:(PGResourceIdentifier *)ident
{
	for(PGDocument *const doc in _documents) if(PGEqualObjects([doc originalIdentifier], ident)) return doc;
	return nil;
}
- (PGDocument *)next:(BOOL)flag documentBeyond:(PGDocument *)document
{
	NSArray *const docs = [[PGDocumentController sharedDocumentController] documents];
	NSUInteger const count = [docs count];
	if(count <= 1) return nil;
	NSUInteger i = [docs indexOfObjectIdenticalTo:[self currentDocument]];
	if(NSNotFound == i) return nil;
	if(flag) {
		if([docs count] == ++i) i = 0;
	} else if(0 == i--) i = [docs count] - 1;
	return [docs objectAtIndex:i];
}
- (NSMenuItem *)windowsMenuItemForDocument:(PGDocument *)document
{
	NSInteger const i = [windowsMenu indexOfItemWithRepresentedObject:document];
	return -1 == i ? nil : [windowsMenu itemAtIndex:i];
}

#pragma mark -

- (id)openDocumentWithContentsOfIdentifier:(PGResourceIdentifier *)ident display:(BOOL)flag
{
	if(!ident) return nil;
	PGDocument *const doc = [self documentForIdentifier:ident];
	return [self _openNew:!doc document:doc ? doc : [[(PGDocument *)[PGDocument alloc] initWithIdentifier:[ident displayableIdentifier]] autorelease] display:flag];
}
- (id)openDocumentWithContentsOfURL:(NSURL *)URL display:(BOOL)flag
{
	return [self openDocumentWithContentsOfIdentifier:[URL PG_resourceIdentifier] display:flag];
}
- (id)openDocumentWithBookmark:(PGBookmark *)aBookmark display:(BOOL)flag
{
	PGDocument *const doc = [self documentForIdentifier:[aBookmark documentIdentifier]];
	[doc openBookmark:aBookmark];
	return [self _openNew:!doc document:doc ? doc : [[[PGDocument alloc] initWithBookmark:aBookmark] autorelease] display:flag];
}
- (void)noteNewRecentDocument:(PGDocument *)document
{
	PGDisplayableIdentifier *const identifier = [document originalIdentifier];
	if(!identifier) return;
	NSMutableArray *const identifiers = [[[self recentDocumentIdentifiers] mutableCopy] autorelease];
	[identifiers removeObject:identifier];
	[identifiers insertObject:identifier atIndex:0];
	[self setRecentDocumentIdentifiers:identifiers];
}

#pragma mark -

- (void)handleAppleEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent
{
	if([event eventClass] == kInternetEventClass && [event eventID] == kAEGetURL) [self openDocumentWithContentsOfURL:[NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]] display:YES];
}

#pragma mark -

- (void)recentDocumentIdentifierDidChange:(NSNotification *)aNotif
{
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_recentDocumentIdentifiers] forKey:PGRecentItemsKey];
}

#pragma mark -PGDocumentController(Private)

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
		for(PGDocument *const doc in docs) {
			[doc setDisplayController:[self displayControllerForNewDocument]];
			[[doc displayController] showWindow:self];
		}
		[[_fullscreenController window] close];
		[_fullscreenController release];
		_fullscreenController = nil;
	} else if([[self documents] count] && self.fullscreen) {
		_inFullscreen = flag;
		PGDocument *const currentDoc = [self currentDocument];
		_fullscreenController = [[PGFullscreenController alloc] init];
		for(PGDocument *const doc in [self documents]) {
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
- (PGDocument *)_openNew:(BOOL)flag document:(PGDocument *)document display:(BOOL)display
{
	if(!document) return nil;
	if(flag) [self addDocument:document];
	if(display) [document createUI];
	return document;
}
- (void)_scheduleNextUpdateCheckWithDate:(NSDate *)date
{
	if(![[NSUserDefaults standardUserDefaults] boolForKey:PGCheckForUpdatesKey]) return;
	NSDate *const d = date ? date : [NSDate dateWithTimeIntervalSinceNow:604800.0f];
	[[NSUserDefaults standardUserDefaults] setObject:d forKey:PGNextUpdateCheckDateKey];
	[_updateTimer invalidate];
	[_updateTimer release];
	_updateTimer = [[self PG_performSelector:@selector(_checkForUpdates:) withObject:nil fireDate:d interval:0.0f options:PGRetainTarget] retain];
}
- (void)_checkForUpdates
{
	if(![[NSUserDefaults standardUserDefaults] boolForKey:PGCheckForUpdatesKey]) return;
	[[SUUpdater sharedUpdater] checkForUpdateInformation];
	[self _scheduleNextUpdateCheckWithDate:nil];
}

#pragma mark -NSResponder

- (BOOL)performKeyEquivalent:(NSEvent *)anEvent
{
	if(!([anEvent modifierFlags] & (NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask))) switch([anEvent keyCode]) {
		case PGKeyEscape: [self performEscapeKeyAction]; break;
		case PGKeyQ: [NSApp terminate:self]; return YES;
	}
	return NO;
}

#pragma mark -NSObject

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
		[self setRecentDocumentIdentifiers:recentItemsData ? [NSKeyedUnarchiver unarchiveObjectWithData:recentItemsData] : [NSArray array]];
		_fullscreen = [[defaults objectForKey:PGFullscreenKey] boolValue];

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

			NSDate *updateDate = [[NSUserDefaults standardUserDefaults] objectForKey:PGNextUpdateCheckDateKey];
			if(updateDate && [updateDate earlierDate:[NSDate date]] == updateDate) {
				[self _checkForUpdates];
				updateDate = nil;
			}
			[self _scheduleNextUpdateCheckWithDate:updateDate];
		}
	}
	return self;
}
- (void)dealloc
{
	if(PGSharedDocumentController == self) [[NSAppleEventManager sharedAppleEventManager] removeEventHandlerForEventClass:kInternetEventClass andEventID:kAEGetURL];
	[self PG_removeObserver];
	[defaultPageMenu release];
	[windowsMenuSeparator release];
	[_updateTimer invalidate];
	[_updateTimer release];
	[_recentDocumentIdentifiers release];
	[_documents release];
	[_fullscreenController release];
	[_exifPanel release];
	[_timerPanel release];
	[_activityPanel release];
	[_classesByExtension release];
	[super dealloc];
}

#pragma mark -NSObject(NSMenuValidation)

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	SEL const action = [anItem action];

	// Sequential:
	if(@selector(installUpdate:) == action) {
		[anItem setTitle:[[NSUserDefaults standardUserDefaults] boolForKey:PGUpdateAvailableKey] ? NSLocalizedString(@"Install Update...", @"Update menu item title. One of two states.") : NSLocalizedString(@"Check for Updates...", @"Update menu item title. One of two states.")];
	}
	if(@selector(switchToFileManager:) == action) [anItem setTitle:NSLocalizedString((self.pathFinderRunning ? @"Switch to Path Finder" : @"Switch to Finder"), @"Switch to Finder or Path Finder (www.cocoatech.com). Two states of the same item.")];

	// Window:
	if(@selector(activateDocument:) == action) [anItem setState:[anItem representedObject] == [self currentDocument]];

	if([[self documents] count] <= 1) {
		if(@selector(selectPreviousDocument:) == action) return NO;
		if(@selector(selectNextDocument:) == action) return NO;
	}
	if(![[self recentDocumentIdentifiers] count]) {
		if(@selector(clearRecentDocuments:) == action) return NO;
	}
	return [super validateMenuItem:anItem];
}

#pragma mark -NSObject(NSNibAwaking)

- (void)awakeFromNib
{
	[defaultPageMenu retain];
	[windowsMenuSeparator retain];
	[windowsMenuSeparator PG_removeFromMenu];

	for(NSMenuItem *const item in [orientationMenu itemArray]) [PGOrientationMenuIconCell addOrientationMenuIconCellToMenuItem:item];

	[zoomIn setKeyEquivalent:@"+"];
	[zoomIn setKeyEquivalentModifierMask:0];
	[zoomOut setKeyEquivalent:@"-"];
	[zoomOut setKeyEquivalentModifierMask:0];

	[scaleSliderItem setView:[scaleSlider superview]];
	[scaleSlider setMinValue:log2(PGScaleMin)];
	[scaleSlider setMaxValue:log2(PGScaleMax)];

	[selectPreviousDocument setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x21E1]];
	[selectPreviousDocument setKeyEquivalentModifierMask:NSCommandKeyMask];
	[selectNextDocument setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x21E3]];
	[selectNextDocument setKeyEquivalentModifierMask:NSCommandKeyMask];

	[self _setFullscreen:_fullscreen];
	[self setCurrentDocument:nil];
}

#pragma mark -NSObject(SUUpdaterDelegateInformalProtocol)

- (void)updater:(SUUpdater *)updater didFindValidUpdate:(SUAppcastItem *)update
{
	[[NSUserDefaults standardUserDefaults] setBool:YES forKey:PGUpdateAvailableKey];
}
- (void)updaterDidNotFindUpdate:(SUUpdater *)update
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PGUpdateAvailableKey];
}
- (void)updater:(SUUpdater *)updater willInstallUpdate:(SUAppcastItem *)update
{
	[[NSUserDefaults standardUserDefaults] setBool:NO forKey:PGUpdateAvailableKey];
}

#pragma mark -<NSApplicationDelegate>

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename
{
	return !![self openDocumentWithContentsOfURL:[filename PG_fileURL] display:YES];
}
- (void)application:(NSApplication *)sender openFiles:(NSArray *)filenames
{
	for(NSString *const filename in filenames) [self openDocumentWithContentsOfURL:[filename PG_fileURL] display:YES];
	[sender replyToOpenOrPrint:NSApplicationDelegateReplySuccess];
}

#pragma mark -<NSMenuDelegate>

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	[menu PG_removeAllItems];
	BOOL addedAnyItems = NO;
	NSArray *const identifiers = [self recentDocumentIdentifiers];
	for(PGDisplayableIdentifier *const identifier in identifiers) {
		if(![identifier URL]) continue; // Make sure the URLs are valid.
		BOOL uniqueName = YES;
		NSString *const name = [identifier displayName];
		for(PGDisplayableIdentifier *const comparisonIdentifier in identifiers) {
			if(comparisonIdentifier == identifier || !PGEqualObjects([comparisonIdentifier displayName], name)) continue;
			uniqueName = NO;
			break;
		}
		NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:@"" action:@selector(openRecentDocument:) keyEquivalent:@""] autorelease];
		[item setAttributedTitle:[identifier attributedStringWithAncestory:!uniqueName]];
		[item setRepresentedObject:identifier];
		[menu addItem:item];
		addedAnyItems = YES;
	}
	if(addedAnyItems) [menu addItem:[NSMenuItem separatorItem]];
	[menu addItem:[[[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"Clear Menu", @"Clear the Open Recent menu. Should be the same as the standard text.") action:@selector(clearRecentDocuments:) keyEquivalent:@""] autorelease]];
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
@interface PGMenuItem : NSMenuItem
@end

static BOOL (*PGNSWindowValidateMenuItem)(id, SEL, NSMenuItem *);
static NSView *(*PGNSViewNextValidKeyView)(id, SEL);
static NSView *(*PGNSViewPreviousValidKeyView)(id, SEL);
static BOOL (*PGNSMenuPerformKeyEquivalent)(id, SEL, NSEvent *);

static void (*PGNSMenuItemSetEnabled)(id, SEL, BOOL);

@implementation PGApplication

+ (void)initialize
{
	if([PGApplication class] != self) return;

	PGNSWindowValidateMenuItem = [NSWindow PG_useImplementationFromClass:[PGWindow class] forSelector:@selector(validateMenuItem:)];
	PGNSViewNextValidKeyView = [NSView PG_useImplementationFromClass:[PGView class] forSelector:@selector(nextValidKeyView)];
	PGNSViewPreviousValidKeyView = [NSView PG_useImplementationFromClass:[PGView class] forSelector:@selector(previousValidKeyView)];
	PGNSMenuPerformKeyEquivalent = [NSMenu PG_useImplementationFromClass:[PGMenu class] forSelector:@selector(performKeyEquivalent:)];
	PGNSMenuItemSetEnabled = [NSMenuItem PG_useImplementationFromClass:[PGMenuItem class] forSelector:@selector(setEnabled:)];

	struct rlimit l = {RLIM_INFINITY, RLIM_INFINITY};
	(void)setrlimit(RLIMIT_NOFILE, &l); // We use a lot of file descriptors, especially prior to Leopard where we don't have FSEvents.
}
- (void)sendEvent:(NSEvent *)anEvent
{
	if([anEvent window] || [anEvent type] != NSKeyDown || !([[self mainMenu] performKeyEquivalent:anEvent] || [[PGDocumentController sharedDocumentController] performKeyEquivalent:anEvent])) [super sendEvent:anEvent];
}

@end

@implementation PGWindow

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	if(@selector(PG_grow:) == [anItem action]) return !!([self styleMask] & NSResizableWindowMask); // Categories can't call super, and there's only one method that validates every action, so sadly we have to use class posing for this.
	return PGNSWindowValidateMenuItem(self, _cmd, anItem);
}

@end

@implementation PGView

// Help tab between windows.
- (NSView *)nextValidKeyView
{
	NSView *const view = PGNSViewNextValidKeyView(self, _cmd);
	return view ? view : self;
}
- (NSView *)previousValidKeyView
{
	NSView *const view = PGNSViewPreviousValidKeyView(self, _cmd);
	return view ? view : self;
}

@end

@implementation PGMenu

- (BOOL)performKeyEquivalent:(NSEvent *)anEvent
{
	if([anEvent type] != NSKeyDown) return NO;
	NSInteger i;
	NSInteger const count = [self numberOfItems];
	for(i = 0; i < count; i++) {
		NSMenuItem *const item = [self itemAtIndex:i];
		NSString *const equiv = [item keyEquivalent];
		if([equiv length] != 1) continue;
		unsigned short const keyCode = PGKeyCodeFromUnichar([equiv characterAtIndex:0]);
		if(PGKeyUnknown == keyCode || [anEvent keyCode] != keyCode) continue; // Some non-English keyboard layouts switch to English when the Command key is held, but that doesn't help our shortcuts that don't use Command, so we have to check by key code.
		NSUInteger const modifiersMask = NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask;
		if(([anEvent modifierFlags] & modifiersMask) != ([item keyEquivalentModifierMask] & modifiersMask)) continue;
		return [item PG_performAction];
	}
	for(i = 0; i < count; i++) if([[[self itemAtIndex:i] submenu] performKeyEquivalent:anEvent]) return YES;
	return [NSApp mainMenu] == self ? PGNSMenuPerformKeyEquivalent(self, _cmd, anEvent) : NO;
}

@end

@implementation PGMenuItem

- (void)setEnabled:(BOOL)flag
{
	PGNSMenuItemSetEnabled(self, _cmd, flag);
	[[self view] PG_setEnabled:flag recursive:YES];
}

@end
