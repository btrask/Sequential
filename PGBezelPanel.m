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
#import "PGBezelPanel.h"

// Other
#import "PGGeometry.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSWindowAdditions.h"

NSString *const PGBezelPanelFrameShouldChangeNotification = @"PGBezelPanelFrameShouldChange";
NSString *const PGBezelPanelFrameDidChangeNotification    = @"PGBezelPanelFrameDidChange";

@interface PGBezelPanel (Private)

- (void)_updateFrameWithWindow:(NSWindow *)aWindow display:(BOOL)flag;

@end

@implementation PGBezelPanel

#pragma mark NSObject

+ (BOOL)instancesRespondToSelector:(SEL)aSelector
{
	if(@selector(cancelOperation:) == aSelector) return NO;
	if(@selector(performClose:) == aSelector) return NO;
	return [super instancesRespondToSelector:aSelector];
}

#pragma mark Instance Methods

- (id)initWithContentView:(NSView *)aView
{
	if((self = [super initWithContentRect:(NSRect){NSZeroPoint, [aView frame].size} styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:YES])) {
		[self setOpaque:NO];
		[self setBackgroundColor:[NSColor clearColor]];
		[self useOptimizedDrawing:YES];
		[self setHidesOnDeactivate:NO];
		[self setBecomesKeyOnlyIfNeeded:YES];
		[self setContentView:aView];
	}
	return self;
}
- (void)displayOverWindow:(NSWindow *)aWindow
{
	[self cancelFadeOut];
	if(aWindow != _parentWindow) [_parentWindow removeChildWindow:self];
	[self setIgnoresMouseEvents:!_acceptsEvents];
	[self _updateFrameWithWindow:aWindow display:NO];
	[aWindow addChildWindow:self ordered:NSWindowAbove];
	if(!PGIsTigerOrLater()) [self orderFront:self]; // This makes the parent window -orderFront: as well, which is obnoxious, but unfortunately it seems necessary on Panther.
}

#pragma mark -

- (id)content
{
	return [self contentView];
}

#pragma mark -

- (BOOL)acceptsEvents
{
	return _acceptsEvents;
}
- (void)setAcceptsEvents:(BOOL)flag
{
	_acceptsEvents = flag;
}
- (void)setCanBecomeKey:(BOOL)flag
{
	_canBecomeKey = flag;
}

#pragma mark -

- (PGInset)frameInset
{
	return _frameInset;
}
- (void)setFrameInset:(PGInset)inset
{
	_frameInset = inset;
}

#pragma mark -

- (void)updateFrameDisplay:(BOOL)flag
{
	[self _updateFrameWithWindow:_parentWindow display:flag];
}

#pragma mark -

- (void)frameShouldChange:(NSNotification *)aNotif
{
	[self updateFrameDisplay:YES];
}
- (void)windowDidResize:(NSNotification *)aNotif
{
	[self updateFrameDisplay:YES];
}

#pragma mark Private Protocol

- (void)_updateFrameWithWindow:(NSWindow *)aWindow
        display:(BOOL)flag
{
	float const s = [self AE_userSpaceScaleFactor];
	NSRect const f = [[self contentView] bezelPanel:self frameForContentRect:PGInsetRect([aWindow AE_contentRect], PGScaleInset(_frameInset, 1.0f / s)) scale:s];
	if(NSEqualRects([self frame], f)) return;
	if(flag) NSDisableScreenUpdates();
	[self setFrame:f display:NO];
	if(flag) {
		[self display];
		NSEnableScreenUpdates();
	}
	[self AE_postNotificationName:PGBezelPanelFrameDidChangeNotification];
}

#pragma mark NSStandardKeyBindingMethods Protocol

- (void)cancelOperation:(id)sender
{
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark NSObject Protocol

- (BOOL)respondsToSelector:(SEL)aSelector
{
	if(@selector(cancelOperation:) == aSelector) return NO;
	if(@selector(performClose:) == aSelector) return NO;
	return [super respondsToSelector:aSelector];
}

#pragma mark NSWindow

- (IBAction)performClose:(id)sender
{
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark -

- (BOOL)canBecomeKeyWindow
{
	if([self isFadingOut]) return NO;
	return _acceptsEvents || ![_parentWindow isKeyWindow];
}
- (void)becomeKeyWindow
{
	[super becomeKeyWindow];
	if(!_canBecomeKey) [_parentWindow makeKeyAndOrderFront:self];
}
- (void)setContentView:(NSView *)aView
{
	[[self contentView] AE_removeObserver:self name:PGBezelPanelFrameShouldChangeNotification];
	[super setContentView:aView];
	[[self contentView] AE_addObserver:self selector:@selector(frameShouldChange:) name:PGBezelPanelFrameShouldChangeNotification];
}
- (void)setParentWindow:(NSWindow *)aWindow
{
	[_parentWindow AE_removeObserver:self name:NSWindowDidResizeNotification];
	[super setParentWindow:aWindow];
	_parentWindow = aWindow;
	[_parentWindow AE_addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification];
}
- (void)close
{
	[_parentWindow removeChildWindow:self];
	[super close];
}

#pragma mark -

// Insert the parent window before the initial first responder in the key view loop.
- (void)selectKeyViewFollowingView:(NSView *)aView
{
	if(![aView nextValidKeyView] || [aView nextValidKeyView] == [self initialFirstResponder]) {
		if([self makeFirstResponder:nil]) [_parentWindow makeKeyWindow];
	} else [super selectKeyViewFollowingView:aView];
}
- (void)selectKeyViewPrecedingView:(NSView *)aView
{
	if(!aView || aView == [self initialFirstResponder]) {
		if([self makeFirstResponder:nil]) [_parentWindow makeKeyWindow];
	} else [super selectKeyViewPrecedingView:aView];
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[super dealloc];
}

@end

@implementation NSView (PGBezelPanelContentView)

#pragma mark Class Methods

+ (id)PG_bezelPanel
{
	return [[[PGBezelPanel alloc] initWithContentView:[[[self alloc] initWithFrame:NSZeroRect] autorelease]] autorelease];
}

#pragma mark Instance Methods

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)scaleFactor
{
	return aRect;
}

@end
