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
#import "PGLoading.h"

@implementation PGLoadManager

#pragma mark Class Methods

+ (id)sharedLoadManager
{
	static PGLoadManager *m = nil;
	if(!m) m = [[self alloc] init];
	return m;
}

#pragma mark Instance Methods

- (NSString *)loadDescription
{
	return nil;
}
- (float)loadProgress
{
	return 0;
}
- (id<PGLoading>)parentLoad
{
	return nil;
}
- (NSArray *)subloads
{
	return [[_subloads retain] autorelease];
}
- (void)setSubload:(id<PGLoading>)obj
        isLoading:(BOOL)flag
{
	if(!flag) [_subloads removeObjectIdenticalTo:obj];
	else if([_subloads indexOfObjectIdenticalTo:obj] == NSNotFound) [_subloads addObject:obj];
}
- (void)prioritizeSubload:(id<PGLoading>)obj
{
	unsigned const i = [_subloads indexOfObjectIdenticalTo:[[obj retain] autorelease]];
	if(NSNotFound == i) return;
	[_subloads removeObjectAtIndex:i];
	[_subloads insertObject:obj atIndex:0];
}
- (void)cancelLoad {}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_subloads = (NSMutableArray *)CFArrayCreateMutable(kCFAllocatorDefault, 0, NULL);
	}
	return self;
}
- (void)dealloc
{
	[_subloads release];
	[super dealloc];
}

@end
