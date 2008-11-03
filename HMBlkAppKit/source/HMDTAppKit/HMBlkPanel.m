/*
HMBlkPanel.m

Author: Makoto Kinoshita

Copyright 2004-2006 The Shiira Project. All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted 
provided that the following conditions are met:

  1. Redistributions of source code must retain the above copyright notice, this list of conditions 
  and the following disclaimer.

  2. Redistributions in binary form must reproduce the above copyright notice, this list of 
  conditions and the following disclaimer in the documentation and/or other materials provided 
  with the distribution.

THIS SOFTWARE IS PROVIDED BY THE SHIIRA PROJECT ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES, 
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR 
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE SHIIRA PROJECT OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, 
PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
POSSIBILITY OF SUCH DAMAGE.
*/
#import "HMBlkPanel.h"
#import "HMAppKitEx.h"
#import "HMBlkContentView.h"

@implementation HMBlkPanel

#pragma mark Class Methods

+ (NSImage*)contentBackgroundImage
{
	static NSImage *_contentBackgroundImage;
	if(!_contentBackgroundImage) _contentBackgroundImage = [[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:self] pathForImageResource:@"blkPanelMM"]];
	return _contentBackgroundImage;
}

+ (NSColor *)highlightColorForView:(NSView *)view
{
	return [view HM_isActive] ? [NSColor alternateSelectedControlColor] : [NSColor colorWithCalibratedWhite:0.6f alpha:1.0f];
}
+ (NSArray*)alternatingRowBackgroundColors
{
	static NSArray *_altColors = nil;
	if(!_altColors) _altColors = [[NSArray alloc] initWithObjects:[NSColor colorWithCalibratedWhite:0.16f alpha:0.86f], [NSColor colorWithCalibratedWhite:0.15f alpha:0.8f], nil];
	return _altColors;
}
+ (NSColor*)majorGridColor
{
	static NSColor *_majorGridColor = nil;
	if(!_majorGridColor) _majorGridColor = [[NSColor colorWithCalibratedRed:0.69f green:0.69 blue:0.69 alpha:1.0f] retain];
	return _majorGridColor;
}

#pragma mark NSNibAwaking Protocol

- (void)awakeFromNib
{
	// Convert the sizes set in IB to our new style mask.
	[self setMinSize:[NSWindow frameRectForContentRect:[NSWindow contentRectForFrameRect:(NSRect){NSZeroPoint, [self minSize]} styleMask:NSTitledWindowMask] styleMask:NSBorderlessWindowMask].size];
	[self setMaxSize:[NSWindow frameRectForContentRect:[NSWindow contentRectForFrameRect:(NSRect){NSZeroPoint, [self maxSize]} styleMask:NSTitledWindowMask] styleMask:NSBorderlessWindowMask].size];
}

#pragma mark NSScripting Protocol

- (BOOL)isResizable
{
	return !!(NSWindowZoomButton & [self styleMask]);
}

#pragma mark HMAdditions Protocol

- (NSRect)HM_logicalFrame
{
	NSRect const f = [super HM_logicalFrame];
	return NSMakeRect(NSMinX(f) + 7, NSMinY(f) + 12, NSWidth(f) - 15, NSHeight(f) - 16);
}
- (void)HM_setLogicalFrame:(NSRect)aRect
        display:(BOOL)flag
{
	[super HM_setLogicalFrame:NSMakeRect(NSMinX(aRect) - 7, NSMinY(aRect) - 12, NSWidth(aRect) + 15, NSHeight(aRect) + 16) display:flag];
}
- (NSRect)HM_resizeRectForView:(NSView *)aView
{
	NSView *const c = [self contentView];
	return [c convertRect:NSMakeRect(NSWidth([c bounds]) - 30, 18, 16, 16) toView:aView];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	return [anItem action] == @selector(performClose:) ? YES : [super validateMenuItem:anItem]; // NSWindow doesn't like -performClose: for borderless windows.
}

#pragma mark NSWindow

- (id)initWithContentRect:(NSRect)contentRect 
      styleMask:(unsigned int)styleMask 
      backing:(NSBackingStoreType)backingType 
      defer:(BOOL)flag
{
	self = [super initWithContentRect:contentRect styleMask:NSBorderlessWindowMask backing:backingType defer:flag];

	[self setLevel:NSFloatingWindowLevel];
	[self setOpaque:NO];
	[self setBecomesKeyOnlyIfNeeded:YES];

	_blkContentView = [[HMBlkContentView alloc] initWithFrame:contentRect];
	[self setContentView:_blkContentView];

	NSImage *const closeButtonImage = [[[NSImage alloc] initWithContentsOfFile:[[NSBundle bundleForClass:[self class]] pathForImageResource:@"blkCloseButton"]] autorelease];
	if(closeButtonImage) {
		NSRect  buttonRect;
		buttonRect.origin.x = 12;
		buttonRect.origin.y = contentRect.size.height - 7 - [closeButtonImage size].height;
		buttonRect.size = [closeButtonImage size];

		_closeButton = [[NSButton alloc] initWithFrame:buttonRect];
		[_closeButton setButtonType:NSMomentaryChangeButton];
		[_closeButton setBezelStyle:NSRegularSquareBezelStyle];
		[_closeButton setBordered:NO];
		[_closeButton setImage:closeButtonImage];
		[_closeButton setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
		[_closeButton setTarget:self];
		[_closeButton setAction:@selector(fadeOut)];

		[_blkContentView addSubview:_closeButton];
	}

	[self setAcceptsMouseMovedEvents:YES];

	return self;
}

#pragma mark -

- (IBAction)performClose:(id)sender
{
	[_closeButton performClick:sender];
}

#pragma mark -

- (BOOL)hasShadow
{
	return NO;
}
- (BOOL)becomesKeyOnlyIfNeeded
{
	return YES;
}
- (BOOL)canBecomeKeyWindow
{
	return YES;
}
- (BOOL)canBecomeMainWindow
{
	return NO;
}

- (void)setContentView:(NSView*)contentView
{
	NSView *const oldContentView = [self contentView];
	if(oldContentView != _blkContentView) return [super setContentView:contentView];
	[[oldContentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
	NSView *subview;
	NSEnumerator *const subviewEnum = [[[[contentView subviews] copy] autorelease] objectEnumerator];
	while((subview = [subviewEnum nextObject])) {
		[subview retain];
		[subview removeFromSuperview];
		[oldContentView addSubview:subview];
		[subview release];
	}
	if(![[oldContentView subviews] containsObject:_closeButton]) [oldContentView addSubview:_closeButton];
}

#pragma mark NSObject

- (void)dealloc
{
	[_blkContentView release];
	[_closeButton release];
	[super dealloc];
}

@end
