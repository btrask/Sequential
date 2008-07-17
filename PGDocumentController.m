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
#import "PGDocumentController.h"
#import <Carbon/Carbon.h>
#import <sys/resource.h>

// Models
#import "PGDocument.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Controllers
#import "PGPrefController.h"
#import "PGDisplayController.h"
#import "PGWindowController.h"
#import "PGFullscreenController.h"
#import "PGExifPanel.h"
#import "PGActivityPanel.h"
#import "PGURLAlert.h"

// Other
#import "PGAttachments.h"
#import "PGLegacy.h"

// Categories
#import "NSArrayAdditions.h"
#import "NSColorAdditions.h"
#import "NSMenuItemAdditions.h"
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"
#import "NSUserDefaultsAdditions.h"

NSString *const PGCFBundleTypeExtensionsKey = @"CFBundleTypeExtensions";
NSString *const PGCFBundleTypeOSTypesKey    = @"CFBundleTypeOSTypes";
NSString *const PGCFBundleTypeMIMETypesKey  = @"CFBundleTypeMIMETypes";
NSString *const PGLSTypeIsPackageKey        = @"LSTypeIsPackage";
NSString *const PGBundleTypeFourCCKey       = @"PGBundleTypeFourCC";

NSString *const PGAntialiasWhenUpscalingKey = @"PGAntialiasWhenUpscaling";
NSString *const PGAnimatesImagesKey         = @"PGAnimatesImages";
NSString *const PGAutozoomsWindowsKey       = @"PGAutozoomsWindows";
NSString *const PGBackgroundColorKey        = @"PGBackgroundColor";
NSString *const PGBackgroundPatternKey      = @"PGBackgroundPattern";
NSString *const PGMouseClickActionKey       = @"PGMouseClickAction";

static NSString *const PGCFBundleDocumentTypesKey = @"CFBundleDocumentTypes";
static NSString *const PGAdapterClassKey          = @"PGAdapterClass";

static NSString *const PGRecentItemsKey            = @"PGRecentItems2";
static NSString *const PGRecentItemsDeprecated2Key = @"PGRecentItems"; // Deprecated after 1.3.2
static NSString *const PGRecentItemsDeprecatedKey  = @"PGRecentDocuments"; // Deprecated after 1.2.2.
static NSString *const PGFullscreenKey             = @"PGFullscreen";
static NSString *const PGExifShownKey              = @"PGExifShown";

static NSString *const PGNSApplicationName         = @"NSApplicationName";
static NSString *const PGPathFinderApplicationName = @"Path Finder";
static NSString *const PGFinderApplicationName     = @"Finder";

OSType PGHFSTypeCodeForPseudoFileType(NSString *type)
{
	return CFSwapInt32BigToHost(*(OSType *)[[type dataUsingEncoding:NSUTF8StringEncoding] bytes]);
}
NSString *PGPseudoFileTypeForHFSTypeCode(OSType type)
{
	OSType const swapped = CFSwapInt32HostToBig(type);
	return [[[NSString alloc] initWithBytes:(const void *)&swapped length:4 encoding:NSUTF8StringEncoding] autorelease];
}

static PGDocumentController *PGSharedDocumentController = nil;

@interface PGWindow : NSWindow
@end
@interface PGView : NSView
@end

@interface PGDocumentController (Private)

- (void)_setInFullscreen:(BOOL)flag;

- (void)_setRevealsInBrowser:(BOOL)flag;
- (void)_setPageMenu:(NSMenu *)aMenu;

- (PGDocument *)_openNew:(BOOL)flag document:(PGDocument *)document display:(BOOL)display;

- (void)_applicationLaunched:(NSString *)app;
- (void)_applicationTerminated:(NSString *)app;

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
	[PGWindow poseAsClass:[NSWindow class]];
	[PGView poseAsClass:[NSView class]];
	[[NSUserDefaults standardUserDefaults] addSuiteNamed:@"com.poisonousinsect.Sequential"]; // Fall back on the old preference file if necessary.
	[[NSUserDefaults standardUserDefaults] registerDefaults:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:YES], PGAntialiasWhenUpscalingKey,
		[NSNumber numberWithBool:YES], PGAnimatesImagesKey,
		[NSNumber numberWithBool:YES], PGAutozoomsWindowsKey,
		[NSArchiver archivedDataWithRootObject:[NSColor blackColor]], PGBackgroundColorKey,
		[NSNumber numberWithUnsignedInt:PGNoPattern], PGBackgroundPatternKey,
		[NSNumber numberWithInt:PGNextPreviousAction], PGMouseClickActionKey,
		[NSNumber numberWithUnsignedInt:1], PGMaxDepthKey,
		[NSNumber numberWithBool:NO], PGFullscreenKey,
		[NSNumber numberWithBool:NO], PGExifShownKey,
		nil]];
	struct rlimit l = {RLIM_INFINITY, RLIM_INFINITY};
	(void)setrlimit(RLIMIT_NOFILE, &l);
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

#pragma mark -

- (IBAction)closeAll:(id)sender
{
	[[_fullscreenController window] close];
	PGDocument *doc;
	NSEnumerator *const docEnum = [[self documents] objectEnumerator];
	while((doc = [docEnum nextObject])) [[[doc displayController] window] performClose:self];
}

#pragma mark -

- (IBAction)switchToPathFinder:(id)sender
{
	if(![[[[NSAppleScript alloc] initWithSource:@"tell application \"Path Finder\" to activate"] autorelease] executeAndReturnError:NULL]) NSBeep();
}
- (IBAction)switchToFinder:(id)sender
{
	if(![[[[NSAppleScript alloc] initWithSource:@"tell application \"Finder\" to activate"] autorelease] executeAndReturnError:NULL]) NSBeep();
}

#pragma mark -

- (IBAction)open:(id)sender
{
	NSOpenPanel *const openPanel = [NSOpenPanel openPanel];
	[openPanel setCanChooseDirectories:YES];
	[openPanel setCanChooseFiles:YES];
	[openPanel setAllowsMultipleSelection:YES];
	NSURL *const URL = [[[self currentDocument] identifier] URL];
	NSString *const path = [URL isFileURL] ? [URL path] : nil;
	if([openPanel runModalForDirectory:[path stringByDeletingLastPathComponent] file:[path lastPathComponent] types:[self supportedExtensions]] == NSOKButton) [self application:NSApp openFiles:[openPanel filenames]];
}
- (IBAction)openURL:(id)sender
{
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

#pragma mark -

- (IBAction)changeImageScalingMode:(id)sender
{
	[[self currentPrefObject] setImageScalingMode:[sender tag]];
	[[self currentPrefObject] setImageScaleFactor:1];
}
- (IBAction)changeImageScalingConstraint:(id)sender
{
	[[self currentPrefObject] setImageScalingConstraint:[sender tag]];
}
- (IBAction)changeImageScaleFactor:(id)sender
{
	[[self currentPrefObject] setImageScaleFactor:powf(2, [sender tag])];
	[[self currentPrefObject] setImageScalingMode:PGConstantFactorScaling];
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
	[self setExifShown:![self exifShown]];
}
- (IBAction)toggleActivity:(id)sender
{
	[self setActivityShown:![self activityShown]];
}
- (IBAction)selectPreviousDocument:(id)sender
{
	PGDocument *const doc = [self next:NO documentBeyond:[self currentDocument]];
	if(doc) [[doc displayController] activateDocument:doc];
}
- (IBAction)selectNextDocument:(id)sender
{
	PGDocument *const doc = [self next:YES documentBeyond:[self currentDocument]];
	if(doc) [[doc displayController] activateDocument:doc];
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

- (NSArray *)recentDocumentIdentifiers
{
	return [[_recentDocumentIdentifiers retain] autorelease];
}
- (void)setRecentDocumentIdentifiers:(NSArray *)anArray
{
	NSParameterAssert(anArray);
	if(_prefsLoaded && [anArray isEqual:_recentDocumentIdentifiers]) return;
	[_recentDocumentIdentifiers AE_removeObjectObserver:self name:PGResourceIdentifierDidChangeNotification];
	[_recentDocumentIdentifiers release];
	_recentDocumentIdentifiers = [[anArray subarrayWithRange:NSMakeRange(0, MIN([anArray count], [self maximumRecentDocumentCount]))] retain];
	[_recentDocumentIdentifiers AE_addObjectObserver:self selector:@selector(recentDocumentIdentifierDidChange:) name:PGResourceIdentifierDidChangeNotification];
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
	[toggleFullscreen setTitle:NSLocalizedString((flag ? @"Exit Full Screen" : @"Enter Full Screen"), @"Enter/exit full screen. Two states of the same item.")];
	[fitToView setTitle:NSLocalizedString((flag ? @"Fit to Screen" : @"Fit to Window"), @"Scale image down so the entire thing fits menu item. Two labels, depending on mode.")];
	[self _setInFullscreen:flag];
}

#pragma mark -

- (BOOL)exifShown
{
	return _exifShown;
}
- (void)setExifShown:(BOOL)flag
{
	if(_prefsLoaded && flag == _exifShown) return;
	_exifShown = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGExifShownKey];
	if(flag) {
		if(!_exifPanel) _exifPanel = [[PGExifPanel alloc] init];
		[_exifPanel showWindow:self];
	} else [[_exifPanel window] performClose:self];
}
- (BOOL)activityShown
{
	return _activityShown;
}
- (void)setActivityShown:(BOOL)flag
{
	if(flag == _activityShown) return;
	_activityShown = flag;
	if(flag) {
		if(!_activityPanel) _activityPanel = [[PGActivityPanel alloc] init];
		[_activityPanel showWindow:self];
	} else [[_activityPanel window] performClose:self];
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
	[self _setInFullscreen:YES];
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
	[self _setInFullscreen:[_documents count] > 0];
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
	[[self currentPrefObject] AE_removeObserver:self name:PGPrefObjectShowsOnScreenDisplayDidChangeNotification];

	_currentDocument = document;
	[self _setRevealsInBrowser:[_currentDocument isOnline]];
	[self _setPageMenu:(_currentDocument ? [_currentDocument pageMenu] : [self defaultPageMenu])];

	[[self currentPrefObject] AE_addObserver:self selector:@selector(readingDirectionDidChange:) name:PGPrefObjectReadingDirectionDidChangeNotification];
	[[self currentPrefObject] AE_addObserver:self selector:@selector(showsOnScreenDisplayDidChange:) name:PGPrefObjectShowsOnScreenDisplayDidChangeNotification];
	[self readingDirectionDidChange:nil];
	[self showsOnScreenDisplayDidChange:nil];
}

#pragma mark -

- (NSArray *)documentTypeDictionaries
{
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:PGCFBundleDocumentTypesKey];
}
- (NSArray *)supportedExtensions
{
	NSMutableArray *const exts = [NSMutableArray array];
	NSDictionary *typeDict;
	NSEnumerator *const typeDictEnum = [[self documentTypeDictionaries] objectEnumerator];
	while((typeDict = [typeDictEnum nextObject])) {
		[exts addObjectsFromArray:[typeDict objectForKey:PGCFBundleTypeExtensionsKey]];
		NSArray *const OSTypes = [typeDict objectForKey:PGCFBundleTypeOSTypesKey];
		if(!OSTypes || ![OSTypes count]) continue;
		NSString *type;
		NSEnumerator *const typeEnum = [OSTypes objectEnumerator];
		while((type = [typeEnum nextObject])) [exts addObject:NSFileTypeForHFSTypeCode(PGHFSTypeCodeForPseudoFileType(type))];
	}
	return exts;
}
- (NSDictionary *)documentTypeDictionaryWhereAttribute:(NSString *)key
                  matches:(id)value
{
	NSArray *const dictionaries = [self documentTypeDictionaries];
	if(![dictionaries count]) return nil;
	if(!key) return [dictionaries objectAtIndex:0];
	if(!value) return nil;
	NSDictionary *typeDict;
	NSEnumerator *const typeDictEnum = [dictionaries objectEnumerator];
	while((typeDict = [typeDictEnum nextObject])) {
		id const obj = [typeDict objectForKey:key];
		if(([obj respondsToSelector:@selector(containsObject:)] && [obj containsObject:value]) || [obj isEqual:value]) return typeDict;
	}
	return nil;
}
- (Class)resourceAdapterClassWhereAttribute:(NSString *)key
         matches:(id)value
{
	return NSClassFromString([[self documentTypeDictionaryWhereAttribute:key matches:value] objectForKey:PGAdapterClassKey]);
}
- (Class)resourceAdapterClassForExtension:(NSString *)ext
{
	Class class = [_classesByExtension objectForKey:ext];
	if(!class) {
		class = [self resourceAdapterClassWhereAttribute:PGCFBundleTypeExtensionsKey matches:[ext lowercaseString]];
		if(class) [_classesByExtension setObject:class forKey:ext];
	}
	return class;
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
- (void)workspaceDidLaunchApplication:(NSNotification *)aNotif
{
	if(aNotif) return [self _applicationLaunched:[[aNotif userInfo] objectForKey:PGNSApplicationName]];
	[switchToPathFinder AE_removeFromMenu];
	[revealInPathFinder AE_removeFromMenu];
	[switchToFinder AE_removeFromMenu];
	[revealInFinder AE_removeFromMenu];
	[_runningApps release];
	_runningApps = [[NSCountedSet alloc] init];
	NSDictionary *dict;
	NSEnumerator *const dictEnum = [[[NSWorkspace sharedWorkspace] launchedApplications] objectEnumerator];
	while((dict = [dictEnum nextObject])) [self _applicationLaunched:[dict objectForKey:PGNSApplicationName]];
}
- (void)workspaceDidTerminateApplication:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	[self _applicationTerminated:[[aNotif userInfo] objectForKey:PGNSApplicationName]];
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
- (void)showsOnScreenDisplayDidChange:(NSNotification *)aNotif
{
	[toggleInfo setTitle:NSLocalizedString(([[self currentPrefObject] showsOnScreenDisplay] ? @"Hide Info" : @"Show Info"), @"Lets the user toggle the on-screen display. Two states of the same item.")];
}

#pragma mark Private Protocol

- (void)_setInFullscreen:(BOOL)flag
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

#pragma mark -

- (void)_setRevealsInBrowser:(BOOL)flag
{
	if(flag == _revealsInBrowser) return;
	_revealsInBrowser = flag;
	if(flag) {
		[revealInPathFinder AE_removeFromMenu];
		[revealInFinder AE_removeFromMenu];
		[revealInBrowser AE_addAfterItem:precedingRevealItem];
	} else {
		[revealInBrowser AE_removeFromMenu];
		[self workspaceDidLaunchApplication:nil];
	}
}
- (void)_setPageMenu:(NSMenu *)aMenu
{
	NSMenu *const mainMenu = [NSApp mainMenu];
	unsigned const pageMenuItemIndex = [mainMenu indexOfItem:[[pageMenuItem retain] autorelease]];
	[mainMenu removeItemAtIndex:pageMenuItemIndex]; // Works around a Tiger bug where two Page menus appear.

	NSMenu *const oldMenu = [pageMenuItem submenu];
	NSMenu *const newMenu = aMenu ? aMenu : defaultPageMenu;
	[newMenu setTitle:[pageMenuItem title]]; // Otherwise the title can get changed.
	firstPage = [newMenu itemAtIndex:[oldMenu indexOfItem:firstPage]]; // Since we change the whole menu, make sure to get the current menu's items.
	previousPage = [newMenu itemAtIndex:[oldMenu indexOfItem:previousPage]];
	nextPage = [newMenu itemAtIndex:[oldMenu indexOfItem:nextPage]];
	lastPage = [newMenu itemAtIndex:[oldMenu indexOfItem:lastPage]];
	[pageMenuItem setSubmenu:newMenu];

	[mainMenu insertItem:pageMenuItem atIndex:pageMenuItemIndex];
	[self readingDirectionDidChange:nil];
}

#pragma mark -

- (PGDocument *)_openNew:(BOOL)flag
                document:(PGDocument *)document
                display:(BOOL)display
{
	if(!document) return nil;
	if(flag) [self addDocument:document];
	if(display) [document createUI];
	return document;
}

#pragma mark -

- (void)_applicationLaunched:(NSString *)app
{
	[_runningApps addObject:app];
	if([_runningApps countForObject:app] != 1) return;
	if([PGPathFinderApplicationName isEqual:app]) {
		[switchToPathFinder AE_addAfterItem:precedingSwitchItem];
		if(!_revealsInBrowser) [revealInPathFinder AE_addAfterItem:precedingRevealItem];
	} else if([PGFinderApplicationName isEqual:app]) {
		[switchToFinder AE_addAfterItem:([switchToPathFinder menu] ? switchToPathFinder : precedingSwitchItem)];
		if(!_revealsInBrowser) [revealInFinder AE_addAfterItem:([revealInPathFinder menu] ? revealInPathFinder : precedingRevealItem)];
	}
}
- (void)_applicationTerminated:(NSString *)app
{
	[_runningApps removeObject:[[app retain] autorelease]];
	if([_runningApps countForObject:app] != 0) return;
	if([PGPathFinderApplicationName isEqual:app]) {
		[switchToPathFinder AE_removeFromMenu];
		if(!_revealsInBrowser) [revealInPathFinder AE_removeFromMenu];
	} else if([PGFinderApplicationName isEqual:app]) {
		[switchToFinder AE_removeFromMenu];
		if(!_revealsInBrowser) [revealInFinder AE_removeFromMenu];
	}
}

#pragma mark NSNibAwakening Protocol

- (void)awakeFromNib
{
	[switchToPathFinder retain];
	[switchToFinder retain];
	[revealInPathFinder retain];
	[revealInFinder retain];
	[revealInBrowser retain];
	[revealInBrowser AE_removeFromMenu];
	[defaultPageMenu retain];
	[windowsMenuSeparator retain];
	[windowsMenuSeparator AE_removeFromMenu];

	[rotate90CC setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGRotationMenuIconCell alloc] initWithMenuItem:rotate90CC rotation:90] autorelease] label:[rotate90CC title]]];
	[rotate270CC setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGRotationMenuIconCell alloc] initWithMenuItem:rotate270CC rotation:-90] autorelease] label:[rotate270CC title]]];
	[rotate180 setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGRotationMenuIconCell alloc] initWithMenuItem:rotate180 rotation:180] autorelease] label:[rotate180 title]]];

	[mirrorHorz setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGMirrorMenuIconCell alloc] initWithMenuItem:mirrorHorz rotation:0] autorelease] label:[mirrorHorz title]]];
	[mirrorVert setAttributedTitle:[NSAttributedString PG_attributedStringWithAttachmentCell:[[[PGMirrorMenuIconCell alloc] initWithMenuItem:mirrorVert rotation:90] autorelease] label:[mirrorVert title]]];

	[zoomIn setKeyEquivalent:(PGIsLeopardOrLater() ? @"+" : @"=")]; // Leopard is smart about this.
	[zoomIn setKeyEquivalentModifierMask:NSCommandKeyMask];

	[selectNextDocument setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x21E2]];
	[selectNextDocument setKeyEquivalentModifierMask:NSCommandKeyMask | NSShiftKeyMask];
	[selectPreviousDocument setKeyEquivalent:[NSString stringWithFormat:@"%C", 0x21E0]];
	[selectPreviousDocument setKeyEquivalentModifierMask:NSCommandKeyMask | NSShiftKeyMask];

	NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
	[self setFullscreen:[[defaults objectForKey:PGFullscreenKey] boolValue]];
	[self setExifShown:[[defaults objectForKey:PGExifShownKey] boolValue]];
	_prefsLoaded = YES;

	[self setCurrentDocument:nil];

	[self workspaceDidLaunchApplication:nil];
	[self readingDirectionDidChange:nil];
	[self showsOnScreenDisplayDidChange:nil];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	id const pref = [self currentPrefObject];
	SEL const action = [anItem action];
	int const tag = [anItem tag];
	if(@selector(changeReadingDirection:) == action) [anItem setState:[pref readingDirection] == tag];
	else if(@selector(changeImageScalingMode:) == action) [anItem setState:fabs([pref imageScaleFactor] - 1) < 0.01 && [pref imageScalingMode] == tag];
	else if(@selector(changeImageScaleFactor:) == action) [anItem setState:(int)roundf(log2f([pref imageScaleFactor])) == tag];
	else if(@selector(changeImageScalingConstraint:) == action) [anItem setState:tag == [pref imageScalingConstraint]];
	else if(@selector(changeSortOrder:) == action) [anItem setState:tag == (PGSortOrderMask & [pref sortOrder])];
	else if(@selector(changeSortDirection:) == action) {
		[anItem setState:tag == (PGSortDescendingMask & [pref sortOrder])];
		if(([pref sortOrder] & PGSortOrderMask) == PGSortShuffle) return NO;
	} else if(@selector(changeSortRepeat:) == action) [anItem setState:tag == (PGSortRepeatMask & [pref sortOrder])];
	if(@selector(activateDocument:) == action) [anItem setState:([anItem representedObject] == [self currentDocument])];
	if([[self documents] count] <= 1) {
		if(@selector(selectPreviousDocument:) == action) return NO;
		if(@selector(selectNextDocument:) == action) return NO;
	}
	if(![self currentDocument]) {
		if(@selector(changeReadingDirection:) == action) return NO;
		if(@selector(changeImageScalingMode:) == action) return NO;
		if(@selector(changeImageScaleFactor:) == action) return NO;
		if(@selector(changeImageScalingConstraint:) == action) return NO;
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
		NSMutableArray *const identifiers = [NSMutableArray array];
		PGResourceIdentifier *identifier;
		NSEnumerator *const identifierEnum = [[self recentDocumentIdentifiers] objectEnumerator];
		while((identifier = [identifierEnum nextObject])) if([identifier URL]) [identifiers addObject:identifier]; // Make sure the URLs are valid.
		[self setRecentDocumentIdentifiers:identifiers];
		int const separatorIndex = [menu indexOfItem:_recentMenuSeparatorItem];
		if(separatorIndex != -1) [menu removeItemAtIndex:separatorIndex]; // The separator gets moved around as we rebuild the menu.
		return [identifiers count] + 1;
	}
	return -1;
}
- (BOOL)menu:(NSMenu *)menu
        updateItem:(NSMenuItem *)item
        atIndex:(int)index
        shouldCancel:(BOOL)shouldCancel
{
	NSCellStateValue state = NSOffState;
	NSString *title = @"";
	NSAttributedString *attributedTitle = nil;
	id target = self;
	SEL action = NULL;
	id representedObject = nil;
	int tag = -1;
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
		} else if([identifiers count] == (unsigned)index) {
			title = NSLocalizedString(@"Clear Menu", @"Clear the Open Recent menu. Should be the same as the standard text.");
			if(index) {
				if(!_recentMenuSeparatorItem) _recentMenuSeparatorItem = [[NSMenuItem separatorItem] retain];
				[menu insertItem:_recentMenuSeparatorItem atIndex:index];
				action = @selector(clearRecentDocuments:);
			}
		}
	}
	[item setState:state];
	[item setTitle:title];
	[item setAttributedTitle:attributedTitle];
	[item setTarget:target];
	[item setAction:action];
	[item setRepresentedObject:representedObject];
	[item setTag:tag];
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
	if([[anEvent characters] isEqualToString:@"q"] && !([anEvent modifierFlags] & (NSCommandKeyMask | NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask))) {
		[NSApp terminate:self];
		return YES;
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

		NSNotificationCenter *const workspaceCenter = [[NSWorkspace sharedWorkspace] notificationCenter];
		[workspaceCenter addObserver:self selector:@selector(workspaceDidLaunchApplication:) name:NSWorkspaceDidLaunchApplicationNotification object:nil];
		[workspaceCenter addObserver:self selector:@selector(workspaceDidTerminateApplication:) name:NSWorkspaceDidTerminateApplicationNotification object:nil];

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
	[switchToPathFinder release];
	[switchToFinder release];
	[revealInPathFinder release];
	[revealInFinder release];
	[revealInBrowser release];
	[defaultPageMenu release];
	[windowsMenuSeparator release];
	[_runningApps release];
	[_recentMenuSeparatorItem release];
	[_recentDocumentIdentifiers release];
	[_documents release];
	[_fullscreenController release];
	[_exifPanel release];
	[_activityPanel release];
	[_classesByExtension release];
	[super dealloc];
}

@end

@interface PGApplication : NSApplication
@end

@implementation PGApplication

- (void)sendEvent:(NSEvent *)anEvent
{
	if([anEvent window] || [anEvent type] != NSKeyDown || (![[self mainMenu] performKeyEquivalent:anEvent] && ![[PGDocumentController sharedDocumentController] performKeyEquivalent:anEvent])) [super sendEvent:anEvent];
}

@end

@implementation PGWindow

// Catch events that would normally be swallowed.
- (void)keyDown:(NSEvent *)anEvent
{
	if(![[PGDocumentController sharedDocumentController] performKeyEquivalent:anEvent]) [super keyDown:anEvent];
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
