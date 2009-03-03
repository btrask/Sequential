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
#import <Cocoa/Cocoa.h>
#import <HMDTAppKit/PGFadeOutPanel.h>

// Other
#import "PGGeometryTypes.h"

extern NSString *const PGBezelPanelFrameShouldChangeNotification;
extern NSString *const PGBezelPanelFrameDidChangeNotification;

@interface PGBezelPanel : PGFadeOutPanel
{
	@private
	BOOL _acceptsEvents;
	BOOL _canBecomeKey;
	PGInset _frameInset;
}

- (id)initWithContentView:(NSView *)aView;
- (void)displayOverWindow:(NSWindow *)aWindow;

- (id)content; // Returns the content view, but as type id so you don't have to cast it.

- (BOOL)acceptsEvents;
- (void)setAcceptsEvents:(BOOL)flag;
- (void)setCanBecomeKey:(BOOL)flag;

- (PGInset)frameInset;
- (void)setFrameInset:(PGInset)inset;

- (void)updateFrameDisplay:(BOOL)flag;

- (void)frameShouldChange:(NSNotification *)aNotif;
- (void)windowDidResize:(NSNotification *)aNotif;

@end

@interface NSView (PGBezelPanelContentView)

+ (id)PG_bezelPanel; // Returns a bezel panel with an instance of the receiver as the content view.

// To be overridden.
- (NSRect)bezelPanel:(PGBezelPanel *)sender frameForContentRect:(NSRect)aRect scale:(float)scaleFactor; // By default, returns aRect.

@end
