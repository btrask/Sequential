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
#import "NSImageRepAdditions.h"

@implementation NSImageRep (AEAdditions)

+ (id)AE_bestImageRepWithData:(NSData *)data
{
	if(!data) return nil;
	NSArray *const reps = [NSBitmapImageRep imageRepsWithData:data];
	if(1 == [reps count]) return [reps objectAtIndex:0];
	NSInteger bestPixelCount = 0;
	NSBitmapImageRep *bestRep = nil;
	if(data) for(NSBitmapImageRep *const rep in reps) {
		NSInteger const w = [rep pixelsWide], h = [rep pixelsHigh];
		if(NSImageRepMatchesDevice == w || NSImageRepMatchesDevice == h) {
			bestRep = rep;
			break;
		}
		NSInteger const pixelCount = w * h;
		if(pixelCount < bestPixelCount) continue;
		if(pixelCount == bestPixelCount && [bestRep bitsPerPixel] > [rep bitsPerPixel]) continue;
		bestRep = rep;
		bestPixelCount = pixelCount;
	}
	return bestRep;
}

@end
