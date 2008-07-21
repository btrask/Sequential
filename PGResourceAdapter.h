/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import <Cocoa/Cocoa.h>
#import "PGResourceAdapting.h"

// Models
@class PGNode;

enum {
	PGLoadToMaxDepth = 0,
	PGLoadAll        = 1,
	PGLoadNone       = 2
};
typedef int PGLoadingPolicy;

@interface PGResourceAdapter : NSObject <PGResourceAdapting>
{
	@private
	PGNode  *_node;
	BOOL     _isImage;
	BOOL     _needsEncoding;
	unsigned _temporarilyViewableCount;
}

+ (BOOL)alwaysLoads;

- (PGNode *)node;
- (void)setNode:(PGNode *)aNode;

- (BOOL)adapterIsViewable;
- (BOOL)isImage;
- (void)setIsImage:(BOOL)flag;
- (BOOL)needsEncoding;
- (void)setNeedsEncoding:(BOOL)flag;
- (void)setIsTemporarilyViewable:(BOOL)flag;

- (PGLoadingPolicy)descendentLoadingPolicy; // Return MAX(preferredValue, [[self parentAdapter] descendentLoadingPolicy]).

- (void)read; // Abstract method. Sent by -becomeViewed and -becomeViewedWithPassword:. -returnImageRep:error must be sent sometime hereafter.

- (void)noteResourceDidChange;

@end
