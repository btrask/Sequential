/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

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
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGBezelPanel.h"

// Categories
#import "NSObjectAdditions.h"
#import "NSWindowAdditions.h"

NSString *const PGBezelPanelFrameShouldChangeNotification = @"PGBezelPanelFrameShouldChange";

NSString *const PGBezelPanelShouldAnimateKey = @"PGBezelPanelShouldAnimate";

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
	[self setFrame:[[self contentView] bezelPanel:self frameForContentRect:PGInsetRect([aWindow AE_contentRect], _frameInset) scale:[self AE_userSpaceScaleFactor]] display:NO];
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

- (void)changeFrameAnimate:(BOOL)flag
{
	if(!flag) NSDisableScreenUpdates();
	[self setFrame:[[self contentView] bezelPanel:self frameForContentRect:PGInsetRect([_parentWindow AE_contentRect], _frameInset) scale:[self AE_userSpaceScaleFactor]] display:YES animate:flag];
	[self display];
	if(!flag) NSEnableScreenUpdates();
}

#pragma mark -

- (void)frameShouldChange:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	[self changeFrameAnimate:[[[aNotif userInfo] objectForKey:PGBezelPanelShouldAnimateKey] boolValue]];
}
- (void)windowDidResize:(NSNotification *)aNotif
{
	[self changeFrameAnimate:NO];
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
	return _acceptsEvents && _canBecomeKey;
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
