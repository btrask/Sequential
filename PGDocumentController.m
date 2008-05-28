#import "PGDocumentController.h"
#import <Carbon/Carbon.h>

// Models
#import "PGDocument.h"
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Controllers
#import "PGDisplayController.h"
#import "PGWindowController.h"
#import "PGFullscreenController.h"
#import "PGExifPanel.h"
#import "PGURLAlert.h"

// Other
#import "PGLegacy.h"

// Categories
#import "NSAttributedStringAdditions.h"
#import "NSColorAdditions.h"
#import "NSMenuItemAdditions.h"
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"
#import "NSUserDefaultsAdditions.h"

NSString *const PGDocumentControllerBackgroundPatternColorDidChangeNotification = @"PGDocumentControllerBackgroundPatternColorDidChange";
NSString *const PGDocumentControllerDisplayScreenDidChangeNotification          = @"PGDocumentControllerDisplayScreenDidChange";

NSString *const PGCFBundleTypeExtensionsKey = @"CFBundleTypeExtensions";
NSString *const PGCFBundleTypeOSTypesKey    = @"CFBundleTypeOSTypes";
NSString *const PGCFBundleTypeMIMETypesKey  = @"CFBundleTypeMIMETypes";
NSString *const PGLSTypeIsPackageKey        = @"LSTypeIsPackage";
NSString *const PGBundleTypeFourCCKey       = @"PGBundleTypeFourCC";

static NSString *const PGCFBundleDocumentTypesKey = @"CFBundleDocumentTypes";
static NSString *const PGAdapterClassKey          = @"PGAdapterClass";

static NSString *const PGRecentDocumentsDeprecatedKey       = @"PGRecentDocuments"; // Deprecated after 1.2.2.
static NSString *const PGRecentItemsDeprecatedKey           = @"PGRecentItems"; // Deprecated after 1.3.2
static NSString *const PGRecentItemsKey                     = @"PGRecentItems2";
static NSString *const PGBackgroundColorKey                 = @"PGBackgroundColor";
static NSString *const PGBackgroundPatternKey               = @"PGBackgroundPattern";
static NSString *const PGFullscreenKey                      = @"PGFullscreen";
static NSString *const PGDisplayScreenIndexKey              = @"PGDisplayScreenIndex";
static NSString *const PGExifShownKey                       = @"PGExifShown";
static NSString *const PGUsesDirectionMouseButtonMappingKey = @"PGUsesDirectionMouseButtonMapping";

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
	if(PGSharedDocumentController) return PGSharedDocumentController;
	return [[self alloc] init];
}

#pragma mark Instance Methods

- (IBAction)orderFrontColorPanel:(id)sender
{
	NSColorPanel *const colorPanel = [NSColorPanel sharedColorPanel];
	[colorPanel setColor:[self backgroundColor]];
	[colorPanel setTarget:self];
	[colorPanel setAction:@selector(changeBackgroundColor:)];
	if([colorPanel accessoryView] != colorPanelAccessory) {
		NSSize const minSize = [colorPanel minSize];
		[colorPanelAccessory setFrameSize:NSMakeSize(NSWidth([[colorPanel contentView] bounds]), NSHeight([colorPanelAccessory frame]))];
		[colorPanel setAccessoryView:colorPanelAccessory];
		[colorPanel setMinSize:minSize];
	}
	[checkerboardBackground setState:([self backgroundPattern] == PGCheckerboardPattern)];
	[NSApp orderFrontColorPanel:sender];
}
- (IBAction)changeBackgroundColor:(id)sender
{
	[self setBackgroundColor:[[NSColorPanel sharedColorPanel] color]];
}
- (IBAction)changeBackgroundPattern:(id)sender
{
	[self setBackgroundPattern:([sender state] == NSOnState ? [sender tag] : PGNoPattern)];
}

- (IBAction)useScreen:(id)sender
{
	[self setDisplayScreen:[sender representedObject]];
}

- (IBAction)provideFeedback:(id)sender
{
	if(![[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"mailto:sequential@comcast.net"]]) NSBeep();
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

- (IBAction)openDocument:(id)sender
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

- (IBAction)toggleExif:(id)sender
{
	if([self exifShown]) [[_exifPanel window] performClose:self];
	else [self setExifShown:YES];
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

- (NSArray *)recentDocumentIdentifiers
{
	return [[_recentDocumentIdentifiers retain] autorelease];
}
- (void)setRecentDocumentIdentifiers:(NSArray *)anArray
{
	NSParameterAssert(anArray);
	if(_prefsLoaded && [anArray isEqual:_recentDocumentIdentifiers]) return;
	[_recentDocumentIdentifiers release];
	_recentDocumentIdentifiers = [[anArray subarrayWithRange:NSMakeRange(0, MIN([anArray count], [self maximumRecentDocumentCount]))] retain];
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:_recentDocumentIdentifiers] forKey:PGRecentItemsKey];
}
- (unsigned)maximumRecentDocumentCount
{
	return 10;
}

#pragma mark -

- (NSColor *)backgroundPatternColor
{
	return _backgroundPattern == PGCheckerboardPattern ? [_backgroundColor AE_checkerboardPatternColor] : [self backgroundColor];
}
- (NSColor *)backgroundColor
{
	return [[_backgroundColor retain] autorelease];
}
- (void)setBackgroundColor:(NSColor *)aColor
{
	NSParameterAssert(aColor);
	if(_prefsLoaded && [aColor isEqual:_backgroundColor]) return;
	[_backgroundColor release];
	_backgroundColor = [aColor retain];
	[[NSUserDefaults standardUserDefaults] AE_encodeObject:aColor forKey:PGBackgroundColorKey];
	[self AE_postNotificationName:PGDocumentControllerBackgroundPatternColorDidChangeNotification];
}
- (PGPatternType)backgroundPattern
{
	return _backgroundPattern;
}
- (void)setBackgroundPattern:(PGPatternType)aPattern
{
	// More patterns are likely to become available in the future, so accept them gracefully.
	if(_prefsLoaded && aPattern == _backgroundPattern) return;
	_backgroundPattern = aPattern;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:aPattern] forKey:PGBackgroundPatternKey];
	[self AE_postNotificationName:PGDocumentControllerBackgroundPatternColorDidChangeNotification];
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
	[toggleFullscreen setTitle:(flag ? NSLocalizedString(@"Exit Full Screen", nil) : NSLocalizedString(@"Enter Full Screen", nil))];
	[fitToView setTitle:(flag ? NSLocalizedString(@"Fit to Screen", nil) : NSLocalizedString(@"Fit to Window", nil))];
	[self _setInFullscreen:flag];
}
- (NSScreen *)displayScreen
{
	return [[_displayScreen retain] autorelease];
}
- (void)setDisplayScreen:(NSScreen *)anObject
{
	[_displayScreen autorelease];
	_displayScreen = [anObject retain];
	unsigned index = [[NSScreen screens] indexOfObjectIdenticalTo:anObject];
	[[NSUserDefaults standardUserDefaults] setObject:(index == NSNotFound ? nil : [NSNumber numberWithUnsignedInt:index]) forKey:PGDisplayScreenIndexKey];
	[self AE_postNotificationName:PGDocumentControllerDisplayScreenDidChangeNotification];
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
	[toggleExif setTitle:(flag ? NSLocalizedString(@"Hide Exif Data", nil) : NSLocalizedString(@"Show Exif Data", nil))];
	if(flag) {
		_exifPanel = [[PGExifPanel alloc] init];
		[_exifPanel showWindow:self];
	} else {
		[_exifPanel release];
		_exifPanel = nil;
	}
}

#pragma mark -

- (BOOL)usesDirectionalMouseButtonMapping
{
	return _usesDirectionalMouseButtonMapping;
}
- (void)setUsesDirectionalMouseButtonMapping:(BOOL)flag
{
	if(_prefsLoaded && !flag == !_usesDirectionalMouseButtonMapping) return;
	_usesDirectionalMouseButtonMapping = flag;
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:flag] forKey:PGUsesDirectionMouseButtonMappingKey];
}

#pragma mark -

- (NSArray *)documents
{
	return [[_documents copy] autorelease];
}
- (void)addDocument:(PGDocument *)document
{
	NSParameterAssert([_documents indexOfObjectIdenticalTo:document] == NSNotFound);
	[_documents addObject:document];
	NSMenuItem *const item = [[[NSMenuItem alloc] init] autorelease];
	[item setRepresentedObject:document];
	[item setAction:@selector(activateTab:)];
	[item setTarget:nil];
	[tabsMenu addItem:item];
	[self _setInFullscreen:YES];
}
- (void)removeDocument:(PGDocument *)document
{
	NSParameterAssert(!document || [_documents indexOfObjectIdenticalTo:document] != NSNotFound);
	if(document == [self currentDocument]) [self setCurrentDocument:nil];
	if(!document) return;
	[_documents removeObject:document];
	unsigned const i = [tabsMenu indexOfItemWithRepresentedObject:document];
	if(NSNotFound != i) [tabsMenu removeItemAtIndex:i];
	[self _setInFullscreen:[_documents count] > 0];
}
- (id)documentForResourceIdentifier:(PGResourceIdentifier *)ident
{
	PGDocument *doc;
	NSEnumerator *const docEnum = [_documents objectEnumerator];
	while((doc = [docEnum nextObject])) if([[doc identifier] isEqual:ident]) return doc;
	return nil;
}
- (NSMenuItem *)tabMenuItemForDocument:(PGDocument *)document
{
	int const i = [tabsMenu indexOfItemWithRepresentedObject:document];
	return -1 == i ? nil : [tabsMenu itemAtIndex:i];
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
	[exts removeObject:@""]; // We specify a blank extension in our Info.plist to get proper behavior as a drop target, but it can break things internally.
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
	return [self resourceAdapterClassWhereAttribute:PGCFBundleTypeExtensionsKey matches:[ext lowercaseString]];
}

#pragma mark -

- (id)openDocumentWithContentsOfURL:(NSURL *)URL
      display:(BOOL)display
{
	PGResourceIdentifier *const identifier = [PGResourceIdentifier resourceIdentifierWithURL:URL];
	PGDocument *const doc = [self documentForResourceIdentifier:identifier];
	return [self _openNew:!doc document:(doc ? doc : [[[PGDocument alloc] initWithResourceIdentifier:identifier] autorelease]) display:display];
}
- (id)openDocumentWithBookmark:(PGBookmark *)aBookmark
      display:(BOOL)display
{
	PGDocument *const doc = [self documentForResourceIdentifier:[aBookmark documentIdentifier]];
	[doc setOpenedBookmark:aBookmark];
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

- (void)workspaceDidLaunchApplication:(NSNotification *)aNotif
{
	if(aNotif) return [self _applicationLaunched:[[aNotif userInfo] objectForKey:@"NSApplicationName"]];
	[switchToPathFinder AE_removeFromMenu];
	[revealInPathFinder AE_removeFromMenu];
	[switchToFinder AE_removeFromMenu];
	[revealInFinder AE_removeFromMenu];
	[_runningApps release];
	_runningApps = [[NSCountedSet alloc] init];
	NSDictionary *dict;
	NSEnumerator *const dictEnum = [[[NSWorkspace sharedWorkspace] launchedApplications] objectEnumerator];
	while((dict = [dictEnum nextObject])) [self _applicationLaunched:[dict objectForKey:@"NSApplicationName"]];
}
- (void)workspaceDidTerminateApplication:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	[self _applicationTerminated:[[aNotif userInfo] objectForKey:@"NSApplicationName"]];
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
	[toggleInfo setTitle:([[self currentPrefObject] showsOnScreenDisplay] ? NSLocalizedString(@"Hide Info", nil) : NSLocalizedString(@"Show Info", nil))];
}

#pragma mark Private Protocol

- (void)_setInFullscreen:(BOOL)flag
{
	if(flag == _inFullscreen) return;
	PGDisableScreenUpdates();
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

		[windowsMenuItem AE_addAfterItem:tabsMenuItem];
		[tabsMenuItem AE_removeFromMenu];
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

		[tabsMenuItem AE_addAfterItem:windowsMenuItem];
		[windowsMenuItem AE_removeFromMenu];
	}
	PGEnableScreenUpdates();
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
	// TODO: Ignore failed docs.
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
	[NSApp setWindowsMenu:windowsMenu];

	[switchToPathFinder retain];
	[switchToFinder retain];
	[revealInPathFinder retain];
	[revealInFinder retain];
	[revealInBrowser retain];
	[defaultPageMenu retain];
	[windowsMenuItem retain];
	[tabsMenuItem retain];
	[tabsSeparator retain];

	if(PGIsLeopardOrLater()) {
		[rotateRight setTitle:[NSString stringWithFormat:@"%C %@", 0x2B17, [rotateRight title]]]; 
		[rotateLeft setTitle:[NSString stringWithFormat:@"%C %@", 0x2B16, [rotateLeft title]]];
		[rotate180 setTitle:[NSString stringWithFormat:@"%C %@", 0x2B19, [rotate180 title]]];
		[flipHorz setTitle:[NSString stringWithFormat:@"%C %@", 0x25E7, [flipHorz title]]];
		[flipVert setTitle:[NSString stringWithFormat:@"%C %@", 0x2B12, [flipVert title]]]; // These unicode characters will work.

		[zoomIn setKeyEquivalent:@"+"]; // Leopard is smart about this.
	} else [zoomIn setKeyEquivalent:@"="];
	[zoomIn setKeyEquivalentModifierMask:NSCommandKeyMask];

	[revealInBrowser AE_removeFromMenu];
	[tabsMenuItem AE_removeFromMenu];

	NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];
	[self setFullscreen:PGValueWithSelectorOrDefault([defaults objectForKey:PGFullscreenKey], boolValue, NO)];
	[self setExifShown:PGValueWithSelectorOrDefault([defaults objectForKey:PGExifShownKey], boolValue, NO)];
	_prefsLoaded = YES;

	[self setCurrentDocument:nil];

	[self workspaceDidLaunchApplication:nil];
	[self readingDirectionDidChange:nil];
	[self showsOnScreenDisplayDidChange:nil];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(id<NSMenuItem>)anItem
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
	if(menu == screenMenu) return [[NSScreen screens] count];
	else if(menu == recentMenu) {
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
	if(menu == screenMenu) {
		NSScreen *const screen = [[NSScreen screens] objectAtIndex:index];
		if([self displayScreen] == screen) state = NSOnState;
		title = [NSString stringWithFormat:@"%@ (%dx%d)", (index ? [NSString stringWithFormat:NSLocalizedString(@"Screen %d", nil), index + 1] : NSLocalizedString(@"Main Screen", nil)), (int)NSWidth([screen frame]), (int)NSHeight([screen frame])];
		action = @selector(useScreen:);
		representedObject = screen;
	} else if(menu == recentMenu) {
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
			title = NSLocalizedString(@"Clear Menu", nil);
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

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotif
{
	NSArray *const screens = [NSScreen screens];
	if(![screens count]) return [self setDisplayScreen:nil];

	NSScreen *const currentScreen = [self displayScreen];
	unsigned i = [screens indexOfObjectIdenticalTo:currentScreen];
	if(NSNotFound != i) return [self setDisplayScreen:currentScreen];
	i = [screens indexOfObject:currentScreen];
	[self setDisplayScreen:[screens objectAtIndex:(NSNotFound == i ? 0 : i)]];
}

#pragma mark NSResponder

- (void)cancelOperation:(id)sender
{
	[NSApp terminate:sender];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		NSUserDefaults *const defaults = [NSUserDefaults standardUserDefaults];

		id recentItemsData = [defaults objectForKey:PGRecentItemsKey];
		if(!recentItemsData) {
			recentItemsData = [defaults objectForKey:PGRecentItemsDeprecatedKey];
			[defaults removeObjectForKey:PGRecentItemsDeprecatedKey]; // Don't leave unused data around.
		}
		if(!recentItemsData) {
			recentItemsData = [defaults objectForKey:PGRecentDocumentsDeprecatedKey];
			[defaults removeObjectForKey:PGRecentDocumentsDeprecatedKey]; // Don't leave unused data around.
			[NSKeyedUnarchiver setClass:[PGAlias class] forClassName:@"AEAlias"]; // PGAlias was known as AEAlias through 1.0b2.
		}
		[self setRecentDocumentIdentifiers:(recentItemsData ? [NSKeyedUnarchiver unarchiveObjectWithData:recentItemsData] : [NSArray array])];

		[self setUsesDirectionalMouseButtonMapping:PGValueWithSelectorOrDefault([defaults objectForKey:PGUsesDirectionMouseButtonMappingKey], boolValue, NO)];

		[self setBackgroundColor:PGValueOrDefault([defaults AE_decodedObjectForKey:PGBackgroundColorKey], [NSColor blackColor])];
		[self setBackgroundPattern:PGValueWithSelectorOrDefault([defaults objectForKey:PGBackgroundPatternKey], intValue, PGNoPattern)];

		NSArray *const screens = [NSScreen screens];
		unsigned const screenCount = [screens count];
		if(screenCount) {
			unsigned const screenIndex = PGValueWithSelectorOrDefault([defaults objectForKey:PGDisplayScreenIndexKey], unsignedIntValue, 0);
			[self setDisplayScreen:[screens objectAtIndex:(screenIndex < screenCount ? screenIndex : 0)]];
		}

		_documents = [[NSMutableArray alloc] init];

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
	[windowsMenuItem release];
	[tabsMenuItem release];
	[_runningApps release];
	[_recentMenuSeparatorItem release];
	[_recentDocumentIdentifiers release];
	[_backgroundColor release];
	[_displayScreen release];
	[_documents release];
	[_fullscreenController release];
	[_exifPanel release];
	[super dealloc];
}
- (void)keyDown:(NSEvent *)anEvent
{
	if([[anEvent characters] isEqualToString:@"q"] && !([anEvent modifierFlags] & (NSCommandKeyMask | NSShiftKeyMask | NSControlKeyMask | NSAlternateKeyMask))) [NSApp terminate:self];
}

@end

@interface PGApplication : NSApplication

@end

@implementation PGApplication

- (void)sendEvent:(NSEvent *)anEvent
{
	if([anEvent window] || [anEvent type] != NSKeyDown) [super sendEvent:anEvent];
	else if(![[self mainMenu] performKeyEquivalent:anEvent]) [self keyDown:anEvent];
}

@end
