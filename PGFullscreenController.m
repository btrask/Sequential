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
#import "PGFullscreenController.h"
#import <Carbon/Carbon.h>

// Views
#import "PGFullscreenWindow.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSScreenAdditions.h"
#import "NSStringAdditions.h"

@interface PGFullscreenController (Private)

- (void)_hideMenuBar;

@end

@implementation PGFullscreenController

#pragma mark Class Methods

+ (id)sharedFullscreenController
{
	static PGFullscreenController *sharedFullscreenController = nil;
	if(!sharedFullscreenController) sharedFullscreenController = [[self alloc] init];
	return sharedFullscreenController;
}

#pragma mark Instance Methods

- (IBAction)nextTab:(id)sender
{
	NSArray *const docs = [[PGDocumentController sharedDocumentController] documents];
	unsigned i = [docs indexOfObjectIdenticalTo:[self activeDocument]];
	if(NSNotFound == i) return;
	if(0 == i) i = [docs count];
	[self setActiveDocument:[docs objectAtIndex:i - 1] closeIfAppropriate:NO];
}
- (IBAction)previousTab:(id)sender
{
	NSArray *const docs = [[PGDocumentController sharedDocumentController] documents];
	unsigned i = [docs indexOfObjectIdenticalTo:[self activeDocument]] + 1;
	if(NSNotFound == i) return;
	if(i >= [docs count]) i = 0;
	[self setActiveDocument:[docs objectAtIndex:i] closeIfAppropriate:NO];
}
- (IBAction)activateTab:(id)sender
{
	[self setActiveDocument:[sender representedObject] closeIfAppropriate:NO];
}

#pragma mark -

- (void)prepareToExitFullscreen
{
	_isExitingFullscreen = YES;
	SetSystemUIMode(kUIModeNormal, kNilOptions); // For some reason, this moves windows downward slightly (at least on 10.5.3), so make sure it happens before our new windows get put onscreen.
}

#pragma mark -

- (void)displayScreenDidChange:(NSNotification *)aNotif
{
	NSScreen *const screen = [[PGDocumentController sharedDocumentController] displayScreen];
	[(PGFullscreenWindow *)[self window] moveToScreen:screen];
	if(![[self window] isKeyWindow]) return;
	if([NSScreen AE_mainScreen] == screen) [self _hideMenuBar];
	else SetSystemUIMode(kUIModeNormal, kNilOptions);
}

#pragma mark Private Protocol

- (void)_hideMenuBar
{
	SetSystemUIMode(kUIModeAllSuppressed, kNilOptions);
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(id<NSMenuItem>)anItem
{
	SEL const action = [anItem action];
	if(@selector(activateTab:) == action) [anItem setState:([anItem representedObject] == [self activeDocument])];
	// Actions which require multiple documents.
	if([[[PGDocumentController sharedDocumentController] documents] count] < 2) {
		if(@selector(nextTab:) == action) return NO;
		if(@selector(previousTab:) == action) return NO;
	}
	return [super validateMenuItem:anItem];
}

#pragma mark PGFullscreenWindowDelegate Protocol

- (void)closeWindowContent:(PGFullscreenWindow *)sender
{
	[[self activeDocument] close];
}

#pragma mark NSWindowNotifications Protocol

- (void)windowDidBecomeMain:(NSNotification *)aNotif
{
	[super windowDidBecomeMain:aNotif];
	[NSCursor setHiddenUntilMouseMoves:YES];
}
- (void)windowDidResignMain:(NSNotification *)aNotif
{
	if(!_isExitingFullscreen) [super windowDidResignMain:aNotif];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotif
{
	if([[PGDocumentController sharedDocumentController] displayScreen] == [NSScreen AE_mainScreen]) [self AE_performSelector:@selector(_hideMenuBar) withObject:nil afterDelay:0]; // Prevents the menu bar from messing up when the application unhides on Leopard.
}
- (void)windowDidResignKey:(NSNotification *)aNotif
{
	if([[NSApp keyWindow] delegate] == self || [[PGDocumentController sharedDocumentController] displayScreen] != [NSScreen AE_mainScreen]) return;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_hideMenuBar) object:nil];
	SetSystemUIMode(kUIModeNormal, kNilOptions);
}

#pragma mark PGWindowDelegate Protocol

- (NSDragOperation)window:(PGWindow *)window
                   dragOperationForInfo:(id<NSDraggingInfo>)info
{
	if(!([info draggingSourceOperationMask] & NSDragOperationGeneric)) return NSDragOperationNone;
	NSPasteboard *const pboard = [info draggingPasteboard];
	NSArray *const types = [pboard types];
	if([types containsObject:NSFilenamesPboardType]) {
		NSArray *const paths = [pboard propertyListForType:NSFilenamesPboardType];
		return [paths count] == 1 ? NSDragOperationGeneric : NSDragOperationNone; // TODO: Ignore documents of incompatible types.
	} else if([types containsObject:NSURLPboardType]) {
		return [NSURL URLFromPasteboard:pboard] ? NSDragOperationGeneric : NSDragOperationNone;
	}
	return NSDragOperationNone;
}
- (BOOL)window:(PGWindow *)window
        performDragOperation:(id<NSDraggingInfo>)info
{
	NSPasteboard *const pboard = [info draggingPasteboard];
	NSArray *const types = [pboard types];
	if([types containsObject:NSFilenamesPboardType]) return !![[PGDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[[[pboard propertyListForType:NSFilenamesPboardType] lastObject] AE_fileURL] display:YES];
	else if([types containsObject:NSURLPboardType]) return !![[PGDocumentController sharedDocumentController] openDocumentWithContentsOfURL:[NSURL URLFromPasteboard:pboard] display:YES];
	return NO;
}

#pragma mark PGDisplayController

- (BOOL)setActiveDocument:(PGDocument *)document
        closeIfAppropriate:(BOOL)flag
{
	if(document || _isExitingFullscreen) return [super setActiveDocument:document closeIfAppropriate:NO];
	if(![self activeDocument]) return NO;
	NSMutableArray *const docs = [[[[PGDocumentController sharedDocumentController] documents] mutableCopy] autorelease];
	[docs removeObjectIdenticalTo:[self activeDocument]];
	if([docs count]) [self nextTab:self];
	else [super setActiveDocument:nil closeIfAppropriate:NO]; // PGDocumentController knows when to close us, so don't close ourselves.
	return NO;
}

#pragma mark NSWindowController

- (BOOL)shouldCascadeWindows
{
	return NO;
}
- (void)windowDidLoad
{
	NSWindow *const window = [[[PGFullscreenWindow alloc] initWithScreen:[[PGDocumentController sharedDocumentController] displayScreen]] autorelease];
	NSView *const content = [[[[self window] contentView] retain] autorelease];
	[[self window] setContentView:nil];
	[window setContentView:content];
	[window setDelegate:[[self window] delegate]];
	[window setHidesOnDeactivate:[[self window] hidesOnDeactivate]];
	[window registerForDraggedTypes:[NSArray arrayWithObjects:NSFilenamesPboardType, NSURLPboardType, nil]];
	[self setWindow:window];

	[super windowDidLoad];
}
- (void)close
{
	if(_isExitingFullscreen) return;
	PGDocument *doc;
	NSEnumerator *const docEnum = [[[PGDocumentController sharedDocumentController] documents] objectEnumerator];
	while((doc = [docEnum nextObject])) [doc close];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		[[PGDocumentController sharedDocumentController] AE_addObserver:self selector:@selector(displayScreenDidChange:) name:PGDocumentControllerDisplayScreenDidChangeNotification];
	}
	return self;
}
- (void)dealloc
{
	[self AE_removeObserver];
	[super dealloc];
}

@end
