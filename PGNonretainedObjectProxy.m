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

- (NSUInteger)hash
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
