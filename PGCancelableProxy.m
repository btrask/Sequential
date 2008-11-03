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
#import "PGCancelableProxy.h"

// Other
#import "PGCFMutableArray.h"

@implementation PGCancelableProxy

#pragma mark Class Methods

+ (id)storage
{
	return [[[NSMutableArray alloc] initWithCallbacks:NULL] autorelease];
}

#pragma mark Instance Methods

- (id)initWithTarget:(id)target
      class:(Class)class
      storage:(id)storage
{
	if((self = [super init])) {
		if(!target) {
			[self release];
			return nil;
		}
		NSParameterAssert(class);
		NSParameterAssert(storage);
		_target = target;
		_class = class;
		_storage = [storage retain];
	}
	return self;
}

#pragma mark NSObject

- (void)dealloc
{
	[_storage release];
	[super dealloc];
}

#pragma mark -

- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	return [_class instanceMethodSignatureForSelector:sel];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
	@synchronized(_storage) {
		unsigned const i = [_storage indexOfObject:_target];
		if(NSNotFound != i) {
			[_storage removeObjectAtIndex:i];
			[invocation invokeWithTarget:_target];
			return;
		}
	}
	unsigned const length = [[invocation methodSignature] methodReturnLength];
	if(!length) return;
	void *const blank = calloc(1, length);
	[invocation setReturnValue:blank];
	free(blank);
}

@end

@implementation NSObject (PGCancelable)

+ (id)PG_performOn:(id)target
      allow:(BOOL)flag
      withStorage:(id)storage
{
	if(!target) return nil;
	NSParameterAssert(storage);
	if(flag) {
		@synchronized(storage) {
			[storage addObject:target];
		}
	}
	return [[[PGCancelableProxy alloc] initWithTarget:target class:self storage:storage] autorelease];
}
- (void)PG_allowPerformsWithStorage:(id)storage
{
	NSParameterAssert(storage);
	@synchronized(storage) {
		[storage addObject:self];
	}
}
- (void)PG_cancelPerformsWithStorage:(id)storage
{
	if(!storage) return;
	@synchronized(storage) {
		[storage removeObject:self];
	}
}

@end
