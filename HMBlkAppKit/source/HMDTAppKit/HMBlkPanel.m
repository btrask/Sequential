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

#import "HMBlkButton.h"
#import "HMBlkContentView.h"
#import "HMBlkPanel.h"

@implementation HMBlkPanel

//--------------------------------------------------------------//
#pragma mark -- Black image --
//--------------------------------------------------------------//

+ (NSImage*)contentBackgroundImage
{
    static NSImage* _contentBackgroundImage;
    if (!_contentBackgroundImage) {
        NSBundle*   bundle;
        bundle = [NSBundle bundleForClass:self];
        
        _contentBackgroundImage = [[NSImage alloc] initWithContentsOfFile:
                [bundle pathForImageResource:@"blkPanelMM"]];
    }
    
    return _contentBackgroundImage;
}

//--------------------------------------------------------------//
#pragma mark -- Colors --
//--------------------------------------------------------------//

+ (NSColor*)highlighedCellColor
{
    static NSColor* _highlightCellColor = nil;
    if (!_highlightCellColor) {
        _highlightCellColor = [[NSColor colorWithCalibratedWhite:0.4f alpha:1.0f] retain];
    }
    
    return _highlightCellColor;
}

+ (NSArray*)alternatingRowBackgroundColors
{
    static NSArray* _altColors = nil;
    if (!_altColors) {
        _altColors = [[NSArray arrayWithObjects:
                [NSColor colorWithCalibratedWhite:0.16f alpha:0.86f], 
                [NSColor colorWithCalibratedWhite:0.15f alpha:0.8f], 
                nil] retain];
    }
    
    return _altColors;
}

+ (NSColor*)majorGridColor
{
    static NSColor* _majorGridColor = nil;
    if (!_majorGridColor) {
        _majorGridColor = [[NSColor colorWithCalibratedRed:0.69f green:0.69 blue:0.69 alpha:1.0f] retain];
    }
    
    return _majorGridColor;
}

//--------------------------------------------------------------//
#pragma mark -- Initialize --
//--------------------------------------------------------------//

- (id)initWithContentRect:(NSRect)contentRect 
        styleMask:(unsigned int)styleMask 
        backing:(NSBackingStoreType)backingType 
        defer:(BOOL)flag
{
    // Invoke super without title bar
    self = [super initWithContentRect:contentRect 
            styleMask:NSBorderlessWindowMask
            backing:backingType 
            defer:flag];
    
    // Initialize instance variables
    _mouseMoveListeners = [[NSMutableSet set] retain];
    
    // Configure itself
    [self setLevel:NSFloatingWindowLevel];
    [self setOpaque:NO];
    [self setBecomesKeyOnlyIfNeeded:YES];
    
    // Set content view
    _blkContentView = [[HMBlkContentView alloc] initWithFrame:contentRect];
    [self setContentView:_blkContentView];
    
    // Create close button
    NSBundle*   bundle;
    NSImage*    closeButtonImage;
    bundle = [NSBundle bundleForClass:[self class]];
    closeButtonImage = [[[NSImage alloc] initWithContentsOfFile:
            [bundle pathForImageResource:@"blkCloseButton"]] autorelease];
    if (closeButtonImage) {
        NSRect  buttonRect;
        buttonRect.origin.x = 12;
        buttonRect.origin.y = contentRect.size.height - 7 - [closeButtonImage size].height;
        buttonRect.size = [closeButtonImage size];
        
        _closeButton = [[HMBlkButton alloc] initWithFrame:buttonRect];
        [_closeButton setButtonType:NSMomentaryChangeButton];
        [_closeButton setBezelStyle:NSRegularSquareBezelStyle];
        [_closeButton setBordered:NO];
        [_closeButton setImage:closeButtonImage];
        [_closeButton setAutoresizingMask:NSViewMaxXMargin | NSViewMinYMargin];
        [_closeButton setTarget:self];
        [_closeButton setAction:@selector(fadeOut)];
        
        [_blkContentView addSubview:_closeButton];
        
        [self addMouseMoveListener:_closeButton];
    }
    
    // Set accepts mouse moved events
    [self setAcceptsMouseMovedEvents:YES];
    
    return self;
}

- (void)dealloc
{
    [_blkContentView release];
    [_closeButton release];
    [_mouseMoveListeners release];
    
    [super dealloc];
}

//--------------------------------------------------------------//
#pragma mark -- Window attributes --
//--------------------------------------------------------------//

- (void)setContentView:(NSView*)contentView
{
    // Get current content view
    NSView* oldContentView;
    oldContentView = [self contentView];
    
    // Keep black content view
    if (oldContentView == _blkContentView) {
        // Remove old subviews
        [[oldContentView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        
        // Swap new subviews
        NSEnumerator*   enumerator;
        NSView*         view;
        enumerator = [[[[contentView subviews] copy] autorelease] objectEnumerator];
        while (view = [enumerator nextObject]) {
		[view retain];
		[view removeFromSuperview];
		[oldContentView addSubview:view];
		[view release];
        }
        
        // Add close button
        if (![[oldContentView subviews] containsObject:_closeButton]) {
            [oldContentView addSubview:_closeButton];
        }
        
        return;
    }
    
    [super setContentView:contentView];
}

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

//--------------------------------------------------------------//
#pragma mark -- Mouse move listener --
//--------------------------------------------------------------//

- (void)addMouseMoveListener:(id)listener
{
    [_mouseMoveListeners addObject:listener];
}

- (void)removeMouseMoveListener:(id)listener
{
    [_mouseMoveListeners removeObject:listener];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	return [anItem action] == @selector(performClose:) ? YES : [super validateMenuItem:anItem]; // NSWindow doesn't like -performClose: for borderless windows.
}

#pragma mark NSWindow

- (IBAction)performClose:(id)sender
{
	[_closeButton performClick:sender];
}

@end
