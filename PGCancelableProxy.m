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
#import "PGCancelableProxy.h"

// Other
#import "PGCFMutableArray.h"

@implementation PGCancelableProxy

#pragma mark +PGCancelableProxy

+ (id)storage
{
	return [[[NSMutableArray alloc] initWithCallbacks:NULL] autorelease];
}

#pragma mark -PGCancelableProxy

- (id)initWithTarget:(id)target class:(Class)class allowOnce:(BOOL)flag storage:(id)storage
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
		_allowOnce = flag;
		if(flag) @synchronized(storage) {
			[storage addObject:target];
		}
	}
	return self;
}

#pragma mark -NSObject

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
		NSUInteger const i = [_storage indexOfObject:_target];
		if(NSNotFound != i) {
			if(_allowOnce) [_storage removeObjectAtIndex:i];
			[invocation invokeWithTarget:_target];
			return;
		}
	}
	NSUInteger const length = [[invocation methodSignature] methodReturnLength];
	if(!length) return;
	void *const blank = calloc(1, length);
	[invocation setReturnValue:blank];
	free(blank);
}

@end

@implementation NSObject(PGCancelable)

+ (id)PG_performOn:(id)target
      allowOnce:(BOOL)flag
      withStorage:(id)storage
{
	if(!target) return nil;
	NSParameterAssert(storage);
	return [[[PGCancelableProxy alloc] initWithTarget:target class:self allowOnce:flag storage:storage] autorelease];
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
