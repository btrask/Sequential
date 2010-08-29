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
#import <AppKit/AppKit.h>

// Other Sources
#import "PGGeometryTypes.h"

enum {
	AENoIcon = 0,
	AEPlayIcon = 1,
	AEPauseIcon = 2,
	AEStopIcon = 3
};
typedef NSUInteger AEIconType;

@interface NSBezierPath(PGAppKitAdditions)

+ (NSBezierPath *)PG_bezierPathWithRoundRect:(NSRect)aRect cornerRadius:(CGFloat)radius;
+ (void)PG_drawIcon:(AEIconType)type inRect:(NSRect)r;
+ (void)PG_drawSpinnerInRect:(NSRect)aRect startAtPetal:(NSInteger)petal;

- (void)PG_fillUsingOperation:(NSCompositingOperation)op;

@end

@interface NSColor(PGAppKitAdditions)

+ (NSColor *)PG_bezelBackgroundColor;
+ (NSColor *)PG_bezelForegroundColor;
- (NSColor *)PG_checkerboardPatternColor;
- (NSColor *)PG_patternColorWithImage:(NSImage *)image fraction:(CGFloat)fraction;

@end

@interface NSControl(PGAppKitAdditions)

- (void)PG_setAttributedStringValue:(NSAttributedString *)str; // Keeps existing attributes.

@end

@interface NSEvent(PGAppKitAdditions)

- (NSPoint)PG_locationInView:(NSView *)view;

@end

@interface NSImageRep(PGAppKitAdditions)

- (id)PG_thumbnailWithMaxSize:(NSSize)size orientation:(PGOrientation)orientation opaque:(BOOL)opaque;

@end

@interface NSMenu(PGAppKitAdditions)

- (void)PG_removeAllItems; // -[NSMenu removeAllItems] requires 10.6.

@end

@interface NSMenuItem(PGAppKitAdditions)

- (void)PG_addAfterItem:(NSMenuItem *)anItem;
- (void)PG_removeFromMenu;
- (BOOL)PG_performAction; // Uses undocumented calls to highlight the item appropriately. Returns whether the item was enabled (and the action was performed).

@end

@interface NSScreen(PGAppKitAdditions)

+ (NSScreen *)PG_mainScreen; // Returns the real main screen.
- (BOOL)PG_setDesktopImageURL:(NSURL *)URL;

@end

@interface NSView(PGAppKitAdditions)

- (void)PG_setEnabled:(BOOL)enabled recursive:(BOOL)recursive;
- (BOOL)PG_isActive;

@end

@interface NSWindow(PGAppKitAdditions)

- (NSRect)PG_contentRect;
- (void)PG_setContentRect:(NSRect)aRect;

@end
