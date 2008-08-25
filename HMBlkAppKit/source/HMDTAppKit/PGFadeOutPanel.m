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
#import "PGFadeOutPanel.h"

#define PGFadeOutPanelFrameRate (1.0 / 30.0)
#define PGFadeOutPanelDuration  0.20

@implementation PGFadeOutPanel

#pragma mark Instance Methods

- (BOOL)isFadingOut
{
	return _frameCount != 0;
}
- (void)fadeOut
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	if(![self isFadingOut]) {
		_alphaValue = [self alphaValue];
		_ignoresMouseEvents = [self ignoresMouseEvents];
		[self setIgnoresMouseEvents:YES];
	}
	float const x = ++_frameCount / (PGFadeOutPanelDuration / PGFadeOutPanelFrameRate) - 1;
	if(x >= 0) return [self close];
	[self setAlphaValue:_alphaValue * powf(x, 2)];
	[self performSelector:@selector(fadeOut) withObject:nil afterDelay:PGFadeOutPanelFrameRate inModes:[NSArray arrayWithObject:(NSString *)kCFRunLoopCommonModes]];
}
- (void)cancelFadeOut
{
	if(![self isFadingOut]) return;
	[self setAlphaValue:_alphaValue];
	[self setIgnoresMouseEvents:_ignoresMouseEvents];
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(fadeOut) object:nil];
	_frameCount = 0;
}

#pragma mark NSWindow

- (IBAction)makeKeyAndOrderFront:(id)sender
{
	[self cancelFadeOut];
	[super makeKeyAndOrderFront:sender];
}
- (IBAction)orderFront:(id)sender
{
	[self cancelFadeOut];
	[super orderFront:sender];
}

- (void)orderFrontRegardless
{
	[self cancelFadeOut];
	[super orderFrontRegardless];
}

- (void)close
{
	[super close];
	[self cancelFadeOut];
}
- (void)dealloc
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[super dealloc];
}

@end
