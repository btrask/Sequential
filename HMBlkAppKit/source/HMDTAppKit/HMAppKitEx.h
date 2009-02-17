/*
HMAppKitEx.h

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

@interface NSApplication (private)
- (BOOL)_handleKeyEquivalent:(NSEvent*)event;
@end

@interface NSBezierPath (ellipse)
+ (NSBezierPath*)ellipseInRect:(NSRect)rect withRadius:(float)radius;
@end

@interface NSBrowser (appearance)
- (void)_setBorderType:(NSBorderType)type;
- (NSBorderType)_borderType;
@end

@interface NSCell (appearance)
- (void)_drawFocusRingWithFrame:(NSRect)rect;
- (NSDictionary*)_textAttributes;
@end

@interface NSDocumentController (MIMEType)
- (NSString*)typeFromMIMEType:(NSString*)MIMEType;
@end

@interface NSImage (HMAdditions)
+ (NSImage*)imageWithSize:(NSSize)size
		leftImage:(NSImage*)leftImage
		middleImage:(NSImage*)middleImage
		rightImage:(NSImage*)middleImage
		middleRect:(NSRect*)outMiddleRect;
+ (NSImage *)HM_imageNamed:(NSString *)name
		for:(id)anObject
		flipped:(BOOL)flag;
- (void)drawInRect:(NSRect)dstRect
		fromRect:(NSRect)srcRect
		operation:(NSCompositingOperation)op
		fraction:(float)delta
		contextRect:(NSRect)ctxRect
		isContextFlipped:(BOOL)flag;
@end

@interface NSObject (_NSArrayControllerTreeNode_methods)
- (id)observedObject;
@end

@interface NSOutlineView (private)
- (void)_sendDelegateWillDisplayCell:(id)cell forColumn:(id)column row:(int)row;
- (void)_sendDelegateWillDisplayOutlineCell:(id)cell inOutlineTableColumnAtRow:(int)row;
@end

@interface NSOutlineView (ExpandingAndCollapsing)
- (void)expandAllItems;
- (void)collapseAllItems;
@end

@interface NSOutlineView (ContextMenu)
- (NSMenu*)menuForEvent:(NSEvent*)event;
- (void)draggedImage:(NSImage*)image 
        endedAt:(NSPoint)point 
        operation:(NSDragOperation)operation;
@end

@interface NSObject (OutlineViewContextMenu)
- (NSMenu*)outlineView:(NSOutlineView*)outlineView menuForEvent:(NSEvent*)event;
@end

@interface NSScroller (private)
- (NSRect)_drawingRectForPart:(int)part;
- (NSRect)rectForPart:(int)part;
@end

@interface NSTableView (private)
- (void)_sendDelegateWillDisplayCell:(id)cell forColumn:(id)column row:(int)row;
- (void)drawRow:(int)row clipRect:(NSRect)rect;
@end

@interface NSTableView (ContextMenu)
- (NSMenu*)menuForEvent:(NSEvent*)event;
@end

@interface NSObject (TableViewContextMenu)
- (NSMenu*)tableView:(NSTableView*)tableView menuForEvent:(NSEvent*)event;
@end

@interface NSToolbar (ToolbarItem)
- (NSToolbarItem*)toolbarItemWithIdentifier:(id)identifier;
@end

@interface NSView (HMAdditions)
- (BOOL)HM_isActive;
@end

@interface NSWindow (HMAdditions)

- (NSRect)HM_logicalFrame;
- (void)HM_setLogicalFrame:(NSRect)aRect display:(BOOL)flag;
- (NSRect)HM_resizeRectForView:(NSView *)aView;
- (BOOL)HM_trackResize:(BOOL)isResize withEvent:(NSEvent *)firstEvent;

@end
