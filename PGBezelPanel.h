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
#import <Cocoa/Cocoa.h>
#import <HMDTAppKit/PGFadeOutPanel.h>

extern NSString *const PGBezelPanelFrameShouldChangeNotification;

extern NSString *const PGBezelPanelShouldAnimateKey;

@interface PGBezelPanel : PGFadeOutPanel
{
	@private
	BOOL      _acceptsEvents;
	NSWindow *_parentWindow; // -[NSWindow parentWindow] apparently retains and autoreleases the window before returning it, which is not good when that window is being deallocated and we call it while it's removing us.
}

- (id)initWithContentView:(NSView *)aView;
- (void)displayOverWindow:(NSWindow *)aWindow;

- (BOOL)acceptsEvents;
- (void)setAcceptsEvents:(BOOL)flag;

- (void)changeFrameAnimate:(BOOL)flag;

- (void)frameShouldChange:(NSNotification *)aNotif; // Calls -changeFrameAnimate:.
- (void)windowDidResize:(NSNotification *)aNotif;

@end

@interface NSView (PGBezelPanelContentView)

+ (id)PG_bezelPanel; // Returns a bezel panel with an instance of the receiver as the content view.

// To be overridden.
- (NSRect)bezelPanel:(PGBezelPanel *)sender frameForContentRect:(NSRect)aRect scale:(float)scaleFactor; // By default, returns aRect.

@end
