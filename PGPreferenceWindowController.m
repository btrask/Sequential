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
#import "PGPreferenceWindowController.h"

// Models
#import "PGPrefObject.h"

// Controllers
#import "PGDocumentController.h"

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGFoundationAdditions.h"

NSString *const PGPreferenceWindowControllerBackgroundPatternColorDidChangeNotification = @"PGPreferenceWindowControllerBackgroundPatternColorDidChange";
NSString *const PGPreferenceWindowControllerDisplayScreenDidChangeNotification          = @"PGPreferenceWindowControllerDisplayScreenDidChange";

static NSString *const PGDisplayScreenIndexKey = @"PGDisplayScreenIndex";

static NSString *const PGGeneralPaneIdentifier = @"PGGeneralPane";
static NSString *const PGNavigationPaneIdentifier = @"PGNavigationPaneIdentifier";

static PGPreferenceWindowController *PGSharedPrefController = nil;

@interface PGPreferenceWindowController(Private)

- (NSString *)_titleForPane:(NSString *)identifier;
- (void)_setCurrentPane:(NSString *)identifier;
- (void)_updateSecondaryMouseActionLabel;

@end

@implementation PGPreferenceWindowController

#pragma mark +PGPreferenceWindowController

+ (id)sharedPrefController
{
	return PGSharedPrefController ? PGSharedPrefController : [[[self alloc] init] autorelease];
}

#pragma mark -PGPreferenceWindowController

- (IBAction)changeDisplayScreen:(id)sender
{
	[self setDisplayScreen:[(NSMenuItem *)sender representedObject]];
}
- (IBAction)showPrefsHelp:(id)sender
{
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"preferences" inBook:[[NSBundle mainBundle] objectForInfoDictionaryKey:PGCFBundleHelpBookNameKey]];
}
- (IBAction)changePane:(NSToolbarItem *)sender
{
	[self _setCurrentPane:[sender itemIdentifier]];
}

#pragma mark -

- (NSColor *)backgroundPatternColor
{
	NSColor *const color = [[NSUserDefaults standardUserDefaults] PG_decodedObjectForKey:@"PGBackgroundColor"];
	return [[[NSUserDefaults standardUserDefaults] objectForKey:@"PGBackgroundPattern"] unsignedIntegerValue] == PGCheckerboardPattern ? [color PG_checkerboardPatternColor] : color;
}
- (NSScreen *)displayScreen
{
	return [[_displayScreen retain] autorelease];
}
- (void)setDisplayScreen:(NSScreen *)aScreen
{
	[_displayScreen autorelease];
	_displayScreen = [aScreen retain];
	[[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithUnsignedInteger:[[NSScreen screens] indexOfObjectIdenticalTo:aScreen]] forKey:PGDisplayScreenIndexKey];
	[self PG_postNotificationName:PGPreferenceWindowControllerDisplayScreenDidChangeNotification];
}

#pragma mark -PGPreferenceWindowController(Private)

- (NSString *)_titleForPane:(NSString *)identifier
{
	if(PGEqualObjects(identifier, PGGeneralPaneIdentifier)) {
		return NSLocalizedString(@"General", @"Title of general pref pane.");
	} else if(PGEqualObjects(identifier, PGNavigationPaneIdentifier)) {
		return NSLocalizedString(@"Navigation", @"Title of navigation pref pane.");
	}
	return @"";
}
- (void)_setCurrentPane:(NSString *)identifier
{
	NSView *newView = nil;
	if(PGEqualObjects(identifier, PGGeneralPaneIdentifier)) newView = generalView;
	else if(PGEqualObjects(identifier, PGNavigationPaneIdentifier)) newView = navigationView;
	NSAssert(newView, @"Invalid identifier.");
	NSWindow *const w = [self window];
	[w setTitle:[self _titleForPane:identifier]];
	[[w toolbar] setSelectedItemIdentifier:identifier];
	NSView *const container = [w contentView];
	NSView *const oldView = [[container subviews] lastObject];
	if(oldView != newView) {
		if(oldView) {
			[oldView removeFromSuperview]; // We don't let oldView fade out because CoreAnimation insists on pinning it to the bottom of the resizing window (regardless of its autoresizing mask), which looks awful.
			[container display]; // Even if oldView is removed, if we don't force it to redisplay, it still shows up during the transition.
		}

		[NSAnimationContext beginGrouping];
		if([[NSApp currentEvent] modifierFlags] & NSShiftKeyMask) [[NSAnimationContext currentContext] setDuration:1.0f];

		NSRect const b = [container bounds];
		[newView setFrameOrigin:NSMakePoint(NSMinX(b), NSHeight(b) - NSHeight([newView frame]))];
		[oldView ? [container animator] : container addSubview:newView];

		NSRect r = [w contentRectForFrameRect:[w frame]];
		CGFloat const h = NSHeight([newView frame]);
		r.origin.y += NSHeight(r) - h;
		r.size.height = h;
		[oldView ? [w animator] : w setFrame:[w frameRectForContentRect:r] display:YES];

		[NSAnimationContext endGrouping];
	}
}
- (void)_updateSecondaryMouseActionLabel
{
	NSString *label = @"";
	switch([[[NSUserDefaults standardUserDefaults] objectForKey:PGMouseClickActionKey] integerValue]) {
		case PGNextPreviousAction: label = @"Secondary click goes to the previous page."; break;
		case PGLeftRightAction: label = @"Secondary click goes right."; break;
		case PGRightLeftAction: label = @"Secondary click goes left."; break;
	}
	[secondaryMouseActionLabel setStringValue:NSLocalizedString(label, @"Informative string for secondary mouse button action.")];
}

#pragma mark -NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	NSWindow *const w = [self window];

	NSToolbar *const toolbar = [[(NSToolbar *)[NSToolbar alloc] initWithIdentifier:@"PGPreferenceWindowControllerToolbar"] autorelease];
	[toolbar setDelegate:self];
	[w setToolbar:toolbar];

	[self _setCurrentPane:PGGeneralPaneIdentifier];
	[w center];
	[self _updateSecondaryMouseActionLabel];
	[self applicationDidChangeScreenParameters:nil];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super initWithWindowNibName:@"PGPreference"])) {
		if(PGSharedPrefController) {
			[self release];
			return [PGSharedPrefController retain];
		} else PGSharedPrefController = [self retain];

		NSArray *const screens = [NSScreen screens];
		NSUInteger const screenIndex = [[[NSUserDefaults standardUserDefaults] objectForKey:PGDisplayScreenIndexKey] unsignedIntegerValue];
		[self setDisplayScreen:screenIndex >= [screens count] ? [NSScreen PG_mainScreen] : [screens objectAtIndex:screenIndex]];

		[NSApp PG_addObserver:self selector:@selector(applicationDidChangeScreenParameters:) name:NSApplicationDidChangeScreenParametersNotification];
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGBackgroundColorKey options:kNilOptions context:self];
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGBackgroundPatternKey options:kNilOptions context:self];
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGMouseClickActionKey options:kNilOptions context:self];
	}
	return self;
}
- (void)dealloc
{
	[self PG_removeObserver];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:PGBackgroundColorKey];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:PGBackgroundPatternKey];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:PGMouseClickActionKey];
	[super dealloc];
}

#pragma mark -NSObject(NSKeyValueObserving)

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(context != self) return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	if(PGEqualObjects(keyPath, PGMouseClickActionKey)) [self _updateSecondaryMouseActionLabel];
	else [self PG_postNotificationName:PGPreferenceWindowControllerBackgroundPatternColorDidChangeNotification];
}

#pragma mark -<NSApplicationDelegate>

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotif
{
	NSArray *const screens = [NSScreen screens];
	[screensPopUp removeAllItems];
	BOOL const hasScreens = [screens count] != 0;
	[screensPopUp setEnabled:hasScreens];
	if(!hasScreens) return [self setDisplayScreen:nil];

	NSScreen *const currentScreen = [self displayScreen];
	NSUInteger i = [screens indexOfObjectIdenticalTo:currentScreen];
	if(NSNotFound == i) {
		i = [screens indexOfObject:currentScreen];
		[self setDisplayScreen:[screens objectAtIndex:NSNotFound == i ? 0 : i]];
	} else [self setDisplayScreen:[self displayScreen]]; // Post PGPreferenceWindowControllerDisplayScreenDidChangeNotification.

	NSMenu *const screensMenu = [screensPopUp menu];
	for(i = 0; i < [screens count]; i++) {
		NSScreen *const screen = [screens objectAtIndex:i];
		NSMenuItem *const item = [[[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"%@ (%lux%lu)", (i ? [NSString stringWithFormat:NSLocalizedString(@"Screen %lu", @"Non-primary screens. %lu is replaced with the screen number."), (unsigned long)i + 1] : NSLocalizedString(@"Main Screen", @"The primary screen.")), (unsigned long)NSWidth([screen frame]), (unsigned long)NSHeight([screen frame])] action:@selector(changeDisplayScreen:) keyEquivalent:@""] autorelease];
		[item setRepresentedObject:screen];
		[item setTarget:self];
		[screensMenu addItem:item];
		if([self displayScreen] == screen) [screensPopUp selectItem:item];
	}
}

#pragma mark -<NSToolbarDelegate>

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)ident willBeInsertedIntoToolbar:(BOOL)flag
{
	NSToolbarItem *const item = [[[NSToolbarItem alloc] initWithItemIdentifier:ident] autorelease];
	[item setTarget:self];
	[item setAction:@selector(changePane:)];
	[item setLabel:[self _titleForPane:ident]];
	if(PGEqualObjects(ident, PGGeneralPaneIdentifier)) {
		[item setImage:[NSImage imageNamed:@"Pref-General"]];
	} else if(PGEqualObjects(ident, PGNavigationPaneIdentifier)) {
		[item setImage:[NSImage imageNamed:@"Pref-Navigation"]];
	}
	return item;
}
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar*)toolbar
{
	return [NSArray arrayWithObjects:PGGeneralPaneIdentifier, PGNavigationPaneIdentifier, NSToolbarFlexibleSpaceItemIdentifier, nil];
}
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar*)toolbar
{
	return [self toolbarDefaultItemIdentifiers:toolbar];
}
- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarDefaultItemIdentifiers:toolbar];
}

@end
