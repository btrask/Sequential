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
#import "PGNonretainedObjectProxy.h"

// Categories
#import "NSObjectAdditions.h"

@implementation PGNonretainedObjectProxy

#pragma mark Instance Methods

- (id)initWithTarget:(id)anObject
{
	if((self = [super init])) {
		_target = anObject;
	}
	return self;
}

#pragma mark PGNonretainedObjectProxy Protocol

- (id)PG_nonretainedObjectValue
{
	return _target;
}

#pragma mark NSObject Protocol

- (unsigned)hash
{
	return [_target hash];
}
- (BOOL)isEqual:(id)object
{
	return [object isEqual:_target]; // This works even if object is another proxy.
}
- (BOOL)isProxy
{
	return YES;
}
- (BOOL)isKindOfClass:(Class)aClass
{
	return [_target isKindOfClass:aClass];
}
- (BOOL)isMemberOfClass:(Class)aClass
{
	return [_target isMemberOfClass:aClass];
}
- (BOOL)conformsToProtocol:(Protocol *)aProtocol
{
	return [_target conformsToProtocol:aProtocol];
}
- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p: %@>", [self class], self, [_target description]];
}

#pragma mark NSObject

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSel
{
	return [_target methodSignatureForSelector:aSel];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
	[invocation setTarget:_target];
	[invocation invoke];
}

@end

@implementation NSObject (PGNonretainedObjectProxy)

- (id)PG_nonretainedObjectProxy
{
	return [[[PGNonretainedObjectProxy alloc] initWithTarget:self] autorelease];
}
- (id)PG_nonretainedObjectValue
{
	return self;
}

#pragma mark -

- (void)PG_performSelector:(SEL)aSel
        withObject:(id)anObject
        afterDelay:(NSTimeInterval)interval
        retain:(BOOL)flag
{
	[self PG_performSelector:aSel withObject:anObject afterDelay:interval inModes:[NSArray arrayWithObject:PGCommonRunLoopsMode] retain:flag];
}
- (void)PG_performSelector:(SEL)aSel
        withObject:(id)anObject
        afterDelay:(NSTimeInterval)interval
        inModes:(NSArray *)runLoopModes
        retain:(BOOL)flag
{
	[(flag ? self : [self PG_nonretainedObjectProxy]) performSelector:aSel withObject:anObject afterDelay:interval inModes:runLoopModes];
}

#pragma mark -

- (void)PG_cancelPreviousPerformRequests
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self];
	[NSObject cancelPreviousPerformRequestsWithTarget:[self PG_nonretainedObjectProxy]];
}
- (void)PG_cancelPreviousPerformRequestsWithSelector:(SEL)aSel
        object:(id)anObject
{
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:aSel object:anObject];
	[NSObject cancelPreviousPerformRequestsWithTarget:[self PG_nonretainedObjectProxy] selector:aSel object:anObject];
}

@end

@implementation NSValue (PGNonretainedObjectProxy)

- (id)PG_nonretainedObjectValue
{
	return [self nonretainedObjectValue];
}

@end
