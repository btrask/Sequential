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
#import "NSWindowAdditions.h"
#import <Carbon/Carbon.h>

@implementation NSWindow(AEAdditions)

- (BOOL)AE_isVisible
{
	return [NSApp isActive] || ![self hidesOnDeactivate];
}
- (CGFloat)AE_userSpaceScaleFactor
{
	return [self respondsToSelector:@selector(userSpaceScaleFactor)] ? [self userSpaceScaleFactor] : 1.0f;
}
- (NSRect)AE_contentRect
{
	Rect r;
	GetWindowBounds([self windowRef], kWindowContentRgn, &r); // Updated in realtime, unlike -frame. See hxxp://rentzsch.com/cocoa/nswindowFrameLies.
	return NSMakeRect(r.left, (CGFloat)CGDisplayPixelsHigh(kCGDirectMainDisplay) - r.bottom, r.right - r.left, r.bottom - r.top);
}
- (void)AE_setContentRect:(NSRect)aRect
{
	NSSize const min = [self minSize];
	NSSize const max = [self maxSize];
	NSRect r = [self frameRectForContentRect:aRect];
	r.size.width = MIN(MAX(min.width, NSWidth(r)), max.width);
	CGFloat const newHeight = MIN(MAX(min.height, NSHeight(r)), max.height);
	r.origin.y += NSHeight(r) - newHeight;
	r.size.height = newHeight;
	[self setFrame:r display:YES];
}

@end
