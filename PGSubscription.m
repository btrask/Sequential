/* Copyright © 2007-2011, The Sequential Project
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
#import "PGSubscription.h"
#import <sys/time.h>
#import <unistd.h>
#import <fcntl.h>

// Other Sources
#import "PGFoundationAdditions.h"

NSString *const PGSubscriptionEventDidOccurNotification = @"PGSubscriptionEventDidOccur";

NSString *const PGSubscriptionPathKey = @"PGSubscriptionPath";
NSString *const PGSubscriptionRootFlagsKey = @"PGSubscriptionRootFlags";

@interface PGLeafSubscription : PGSubscription
{
	@private
	int _descriptor;
}

+ (void)threaded_sendFileEvents;
+ (void)mainThread_sendFileEvent:(NSDictionary *)info;

- (id)initWithPath:(NSString *)path;

@end

@interface PGBranchSubscription : PGSubscription
{
	@private
	FSEventStreamRef _eventStream;
	PGSubscription *_rootSubscription;
}

- (id)initWithPath:(NSString *)path;
- (void)subscribeWithPath:(NSString *)path;
- (void)unsubscribe;
- (void)rootSubscriptionEventDidOccur:(NSNotification *)aNotif;

@end

@implementation PGSubscription

#pragma mark +PGSubscription

+ (id)subscriptionWithPath:(NSString *)path descendents:(BOOL)flag
{
	id result;
	if(!flag) result = [PGLeafSubscription alloc];
	else result = [PGBranchSubscription alloc];
	return [[result initWithPath:path] autorelease];
}
+ (id)subscriptionWithPath:(NSString *)path
{
	return [self subscriptionWithPath:path descendents:NO];
}

#pragma mark -PGSubscription

- (NSString *)path
{
	return nil;
}

#pragma mark -NSObject<NSObject>

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p: %@>", [self class], self, [self path]];
}

@end

static NSString *const PGLeafSubscriptionValueKey = @"PGLeafSubscriptionValue";
static NSString *const PGLeafSubscriptionFlagsKey = @"PGLeafSubscriptionFlags";

static int PGKQueue = -1;
static CFMutableSetRef PGActiveSubscriptions = nil;

@implementation PGLeafSubscription

#pragma mark +PGLeafSubscription

+ (void)threaded_sendFileEvents
{
	for(;;) {
		NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
		struct kevent ev;
		(void)kevent(PGKQueue, NULL, 0, &ev, 1, NULL);
		[self performSelectorOnMainThread:@selector(mainThread_sendFileEvent:) withObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSValue valueWithNonretainedObject:(PGLeafSubscription *)ev.udata], PGLeafSubscriptionValueKey,
			[NSNumber numberWithUnsignedInt:ev.fflags], PGLeafSubscriptionFlagsKey,
			nil] waitUntilDone:NO];
		[pool release];
	}
}
+ (void)mainThread_sendFileEvent:(NSDictionary *)info
{
	PGSubscription *const subscription = [[info objectForKey:PGLeafSubscriptionValueKey] nonretainedObjectValue];
	if(!CFSetContainsValue(PGActiveSubscriptions, subscription)) return;
	NSMutableDictionary *const dict = [NSMutableDictionary dictionary];
	NSString *const path = [subscription path];
	if(path) [dict setObject:path forKey:PGSubscriptionPathKey];
	NSNumber *const flags = [info objectForKey:PGLeafSubscriptionFlagsKey];
	if(flags) [dict setObject:flags forKey:PGSubscriptionRootFlagsKey];
	[subscription PG_postNotificationName:PGSubscriptionEventDidOccurNotification userInfo:dict];
}

#pragma mark +NSObject

+ (void)initialize
{
	if([PGLeafSubscription class] != self) return;
	PGKQueue = kqueue();
	PGActiveSubscriptions = CFSetCreateMutable(kCFAllocatorDefault, 0, NULL);
	[NSThread detachNewThreadSelector:@selector(threaded_sendFileEvents) toTarget:self withObject:nil];
}

#pragma mark -PGLeafSubscription

- (id)initWithPath:(NSString *)path
{
	NSAssert([NSThread isMainThread], @"PGSubscription is not thread safe.");
	errno = 0;
	if((self = [super init])) {
		CFSetAddValue(PGActiveSubscriptions, self);
		char const *const rep = [path fileSystemRepresentation];
		_descriptor = open(rep, O_EVTONLY);
		if(-1 == _descriptor) {
			[self release];
			return nil;
		}
		struct kevent const ev = {
			.ident = _descriptor,
			.filter = EVFILT_VNODE,
			.flags = EV_ADD | EV_CLEAR,
			.fflags = NOTE_DELETE | NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME | NOTE_REVOKE,
			.data = 0,
			.udata = self,
		};
		struct timespec const timeout = {0, 0};
		if(-1 == kevent(PGKQueue, &ev, 1, NULL, 0, &timeout)) {
			[self release];
			return nil;
		}
	}
	return self;
}

#pragma mark -PGSubscription

- (NSString *)path
{
	NSString *result = nil;
	char *path = calloc(PATH_MAX, sizeof(char));
	if(-1 != fcntl(_descriptor, F_GETPATH, path)) result = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:path length:strlen(path)];
	free(path);
	return result;
}

#pragma mark -NSObject

- (void)dealloc
{
	CFSetRemoveValue(PGActiveSubscriptions, self);
	if(-1 != _descriptor) close(_descriptor);
	[super dealloc];
}

#pragma mrk -NSObject<NSObject>

- (id)retain
{
	NSAssert([NSThread isMainThread], @"PGSubscription is not thread safe.");
	return [super retain];
}
- (oneway void)release
{
	NSAssert([NSThread isMainThread], @"PGSubscription is not thread safe.");
	[super release];
}
- (id)autorelease
{
	NSAssert([NSThread isMainThread], @"PGSubscription is not thread safe.");
	return [super autorelease];
}

@end

static void PGEventStreamCallback(ConstFSEventStreamRef streamRef, PGBranchSubscription *subscription, size_t numEvents, NSArray *paths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[])
{
	for(NSString *const path in paths) [subscription PG_postNotificationName:PGSubscriptionEventDidOccurNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:path, PGSubscriptionPathKey, nil]];
}

@implementation PGBranchSubscription

#pragma mark -PGBranchSubscription

- (id)initWithPath:(NSString *)path
{
	if((self = [super init])) {
		_rootSubscription = [[PGSubscription subscriptionWithPath:path] retain];
		[_rootSubscription PG_addObserver:self selector:@selector(rootSubscriptionEventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
		[self subscribeWithPath:path];
	}
	return self;
}
- (void)subscribeWithPath:(NSString *)path
{
	NSParameterAssert(!_eventStream);
	if(!path) return;
	FSEventStreamContext context = {.version = 0, .info = self};
	_eventStream = FSEventStreamCreate(kCFAllocatorDefault, (FSEventStreamCallback)PGEventStreamCallback, &context, (CFArrayRef)[NSArray arrayWithObject:path], kFSEventStreamEventIdSinceNow, 0.0f, kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer);
	FSEventStreamScheduleWithRunLoop(_eventStream, [[NSRunLoop currentRunLoop] getCFRunLoop], kCFRunLoopCommonModes);
	FSEventStreamStart(_eventStream);
}
- (void)unsubscribe
{
	if(!_eventStream) return;
	FSEventStreamStop(_eventStream);
	FSEventStreamInvalidate(_eventStream);
	FSEventStreamRelease(_eventStream);
	_eventStream = NULL;
}
- (void)rootSubscriptionEventDidOccur:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	NSUInteger const flags = [[[aNotif userInfo] objectForKey:PGSubscriptionRootFlagsKey] unsignedIntegerValue];
	if(!(flags & (NOTE_RENAME | NOTE_REVOKE | NOTE_DELETE))) return;
	[self unsubscribe];
	[self subscribeWithPath:[[aNotif userInfo] objectForKey:PGSubscriptionPathKey]];
	[self PG_postNotificationName:PGSubscriptionEventDidOccurNotification userInfo:[aNotif userInfo]];
}

#pragma mark -PGSubscription

- (NSString *)path
{
	return [_rootSubscription path];
}

#pragma mark -NSObject

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[self unsubscribe];
	[_rootSubscription release];
	[super dealloc];
}

@end
