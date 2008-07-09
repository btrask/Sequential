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
#import "PGPrefController.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSColorAdditions.h"
#import "NSObjectAdditions.h"
#import "NSUserDefaultsAdditions.h"

NSString *const PGPrefControllerBackgroundPatternColorDidChangeNotification = @"PGPrefControllerBackgroundPatternColorDidChange";

static NSString *const PGDisplayScreenIndexKey = @"PGDisplayScreenIndex";

static PGPrefController *PGSharedPrefController = nil;

@interface PGPrefController (Private)

- (void)_updateSecondaryMouseActionLabel;

@end

@implementation PGPrefController

#pragma mark Class Methods

+ (id)sharedPrefController
{
	return PGSharedPrefController ? PGSharedPrefController : [[[self alloc] init] autorelease];
}

#pragma mark Instance Methods

- (IBAction)showPrefsHelp:(id)sender
{
	[[NSHelpManager sharedHelpManager] openHelpAnchor:@"preferences" inBook:@"Sequential Help"];
}

#pragma mark -

- (NSColor *)backgroundPatternColor
{
	NSColor *const color = [[NSUserDefaults standardUserDefaults] AE_decodedObjectForKey:@"PGBackgroundColor"];
	return [[[NSUserDefaults standardUserDefaults] objectForKey:@"PGBackgroundPattern"] unsignedIntValue] == PGCheckerboardPattern ? [color AE_checkerboardPatternColor] : color;
}
- (NSScreen *)displayScreen
{
	return [[NSScreen screens] objectAtIndex:0]; // TODO: Implement.
}
- (void)setDisplayScreen:(id)sender
{
	// TODO: Implement
}

#pragma mark Private Protocol

- (void)_updateSecondaryMouseActionLabel
{
	NSString *label = @"";
	switch([[[NSUserDefaults standardUserDefaults] objectForKey:PGMouseClickActionKey] intValue]) {
		case PGNextPreviousAction: label = @"Secondary click goes to the previous page."; break;
		case PGLeftRightAction: label = @"Secondary click goes right."; break;
		case PGRightLeftAction: label = @"Secondary click goes left."; break;
	}
	[secondaryMouseActionLabel setStringValue:NSLocalizedString(label, @"Informative string for secondary mouse button action.")];
}

#pragma mark NSKeyValueObserving Protocol

- (void)observeValueForKeyPath:(NSString *)keyPath
        ofObject:(id)object
        change:(NSDictionary *)change
	context:(void *)context
{
	if(context != self) return [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	if([keyPath isEqualToString:PGMouseClickActionKey]) [self _updateSecondaryMouseActionLabel];
	else [self AE_postNotificationName:PGPrefControllerBackgroundPatternColorDidChangeNotification];
}

#pragma mark NSApplicationNotifications Protocol

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

#pragma mark NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	[self _updateSecondaryMouseActionLabel];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super initWithWindowNibName:@"PGPreferences"])) {
		if(PGSharedPrefController) {
			[self release];
			return [PGSharedPrefController retain];
		} else PGSharedPrefController = [self retain];
		[[self window] center]; // Load and center the window.
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGBackgroundColorKey options:0 context:self];
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGBackgroundPatternKey options:0 context:self];
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGMouseClickActionKey options:0 context:self];
	}
	return self;
}
- (void)dealloc
{
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:PGBackgroundColorKey];
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:PGBackgroundPatternKey];
	[super dealloc];
}

@end
