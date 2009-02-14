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
#import "NSImageAdditions.h"

@implementation NSImage (AEAdditions)

- (void)AE_tileInRect:(NSRect)aRect phase:(NSPoint)phase operation:(NSCompositingOperation)op clip:(BOOL)flag
{
	if(flag) {
		[NSGraphicsContext saveGraphicsState];
		NSRectClip(aRect);
	}
	NSSize const s = [self size];
	float y = floorf((NSMinY(aRect) - phase.y) / s.height) * s.height + phase.y;
	for(; y < NSMaxY(aRect); y += s.height) {
		float x = floorf((NSMinX(aRect) - phase.x) / s.width) * s.width + phase.x;
		for(; x < NSMaxX(aRect); x += s.width) {
			[self drawInRect:NSMakeRect(x, y, s.width, s.height) fromRect:NSZeroRect operation:op fraction:1.0f];
		}
	}
	if(flag) [NSGraphicsContext restoreGraphicsState];
}

@end
