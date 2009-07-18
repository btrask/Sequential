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
	return 0.0f;
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
