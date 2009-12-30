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
#import "PGDelayedPerforming.h"

// Other Sources
#import "PGFoundationAdditions.h"

static NSMutableDictionary *PGTimersByNonretainedObjectValue;

@interface PGTimerContextObject : NSObject
{
	@private
	id _target;
	SEL _selector;
	id _argument;
	PGDelayedPerformingOptions _options;
}

- (id)initWithTarget:(id)target selector:(SEL)aSel object:(id)anArgument options:(PGDelayedPerformingOptions)opts;
- (BOOL)matchesSelector:(SEL)aSel object:(id)anObject;
- (void)invoke;
- (id)target;

@end

@implementation NSObject(PGDelayedPerforming)

static void PGTimerCallback(CFRunLoopTimerRef timer, PGTimerContextObject *context)
{
	if(!CFRunLoopTimerIsValid(timer)) [[PGTimersByNonretainedObjectValue objectForKey:[context target]] removeObjectIdenticalTo:(NSTimer *)timer];
	[context invoke];
}
- (NSTimer *)PG_performSelector:(SEL)aSel withObject:(id)anArgument fireDate:(NSDate *)date interval:(NSTimeInterval)interval options:(PGDelayedPerformingOptions)opts
{
	return [self PG_performSelector:aSel withObject:anArgument fireDate:date interval:interval options:opts mode:(NSString *)kCFRunLoopCommonModes];
}
- (NSTimer *)PG_performSelector:(SEL)aSel withObject:(id)anArgument fireDate:(NSDate *)date interval:(NSTimeInterval)interval options:(PGDelayedPerformingOptions)opts mode:(NSString *)mode
{
	NSParameterAssert(interval >= 0.0f);
	CFRunLoopTimerContext context = {
		0,
		[[[PGTimerContextObject alloc] initWithTarget:self selector:aSel object:anArgument options:opts] autorelease],
		CFRetain,
		CFRelease,
		CFCopyDescription,
	};
	CFTimeInterval const repeatInterval = PGRepeatOnInterval & opts ? interval : 0.0f;
	NSTimer *const timer = [(NSTimer *)CFRunLoopTimerCreate(kCFAllocatorDefault, CFDateGetAbsoluteTime((CFDateRef)(date ? date : [NSDate dateWithTimeIntervalSinceNow:interval])), repeatInterval, kNilOptions, 0, (CFRunLoopTimerCallBack)PGTimerCallback, &context) autorelease];
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:mode];
	if(!PGTimersByNonretainedObjectValue) PGTimersByNonretainedObjectValue = (NSMutableDictionary *)CFDictionaryCreateMutable(kCFAllocatorDefault, 0, NULL, &kCFTypeDictionaryValueCallBacks);
	[NSMutableDictionary dictionary];
	NSMutableArray *timers = [PGTimersByNonretainedObjectValue objectForKey:self];
	if(!timers) {
		timers = [NSMutableArray array];
		CFDictionaryAddValue((CFMutableDictionaryRef)PGTimersByNonretainedObjectValue, self, timers);
	}
	[timers addObject:timer];
	return timer;
}
- (void)PG_cancelPreviousPerformRequests
{
	[[PGTimersByNonretainedObjectValue objectForKey:self] makeObjectsPerformSelector:@selector(invalidate)];
	[PGTimersByNonretainedObjectValue removeObjectForKey:self];
}
- (void)PG_cancelPreviousPerformRequestsWithSelector:(SEL)aSel object:(id)anArgument
{
	NSMutableArray *const timers = [PGTimersByNonretainedObjectValue objectForKey:self];
	for(NSTimer *const timer in [[timers copy] autorelease]) {
		if([timer isValid]) {
			CFRunLoopTimerContext context;
			CFRunLoopTimerGetContext((CFRunLoopTimerRef)timer, &context);
			if(![(PGTimerContextObject *)context.info matchesSelector:aSel object:anArgument]) continue;
			[timer invalidate];
		}
		[timers removeObjectIdenticalTo:timer];
	}
}

@end

@implementation PGTimerContextObject

#pragma mark -PGTimerContextObject

- (id)initWithTarget:(id)target selector:(SEL)aSel object:(id)anArgument options:(PGDelayedPerformingOptions)opts
{
	if((self = [super init])) {
		_target = target;
		_selector = aSel;
		_argument = [anArgument retain];
		_options = opts;
		if(PGRetainTarget & _options) [_target retain];
	}
	return self;
}
- (BOOL)matchesSelector:(SEL)aSel object:(id)anArgument
{
	if(aSel != _selector) return NO;
	if(anArgument != _argument && (PGCompareArgumentPointer & _options || !PGEqualObjects(anArgument, _argument))) return NO;
	return YES;
}
- (void)invoke
{
	[_target performSelector:_selector withObject:_argument];
}
- (id)target
{
	return _target;
}

#pragma mark -NSObject

- (void)dealloc
{
	if(PGRetainTarget & _options) [_target release];
	[_argument release];
	[super dealloc];
}

@end
