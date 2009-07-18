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
#import "PGSubscription.h"
#import <sys/time.h>
#import <unistd.h>
#import <fcntl.h>

// Other
#import "PGCancelableProxy.h"

// Categories
#import "NSObjectAdditions.h"

NSString *const PGSubscriptionEventDidOccurNotification = @"PGSubscriptionEventDidOccur";

NSString *const PGSubscriptionPathKey      = @"PGSubscriptionPath";
NSString *const PGSubscriptionRootFlagsKey = @"PGSubscriptionRootFlags";

static int PGKQueue              = -1;
static id  PGActiveSubscriptions = nil;

@interface PGLeafSubscription : PGSubscription
{
	@private
	int _descriptor;
}

+ (void)threaded_sendFileEvents;

- (id)initWithPath:(NSString *)path;
- (PGSubscription *)rootSubscription;
- (void)noteFileEventDidOccurWithFlags:(NSNumber *)flagsNum;

@end

@interface PGKQueueBranchSubscription : PGLeafSubscription
{
	@private
	PGKQueueBranchSubscription *_parent;
	NSArray *_children;
}

- (id)initWithPath:(NSString *)path parent:(PGKQueueBranchSubscription *)parent;

@end

@interface PGFSEventBranchSubscription : PGSubscription
{
	@private
	FSEventStreamRef _eventStream;
	PGSubscription *_rootSubscription;
}

- (id)initWithPath:(NSString *)path;
- (void)subscribeWithPath:(NSString *)path;
- (void)unsubscribe;
- (void)noteFileEventsDidOccurAtPaths:(NSArray *)paths;
- (void)rootSubscriptionEventDidOccur:(NSNotification *)aNotif;

@end

@implementation PGSubscription

#pragma mark Class Methods

+ (id)subscriptionWithPath:(NSString *)path descendents:(BOOL)flag
{
	id result;
	if(!flag) result = [PGLeafSubscription alloc];
	else if(PGIsLeopardOrLater()) result = [PGFSEventBranchSubscription alloc];
	else result = [PGKQueueBranchSubscription alloc];
	return [[result initWithPath:path] autorelease];
}
+ (id)subscriptionWithPath:(NSString *)path
{
	return [self subscriptionWithPath:path descendents:NO];
}

#pragma mark Instance Methods

- (NSString *)path
{
	return nil;
}

#pragma mark NSObject Protocol

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p: %@>", [self class], self, [self path]];
}

@end

@implementation PGLeafSubscription

#pragma mark Class Methods

+ (void)threaded_sendFileEvents
{
	for(;;) {
		NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
		struct kevent ev[5]; // Group up to 5 events at once.
		unsigned const count = kevent(PGKQueue, NULL, 0, ev, 5, NULL);
		unsigned i = 0;
		for(; i < count; i++) [[PGLeafSubscription PG_performOn:(id)ev[i].udata allowOnce:NO withStorage:PGActiveSubscriptions] performSelectorOnMainThread:@selector(noteFileEventDidOccurWithFlags:) withObject:[NSNumber numberWithUnsignedInt:ev[i].fflags] waitUntilDone:NO];
		[pool release];
	}
}

#pragma mark Instance Methods

- (id)initWithPath:(NSString *)path
{
	errno = 0;
	if((self = [super init])) {
		char const *const rep = [path fileSystemRepresentation];
		_descriptor = open(rep, O_EVTONLY);
		if(-1 == _descriptor) {
			[self release];
			return nil;
		}
		if(-1 == PGKQueue) {
			PGKQueue = kqueue();
			PGActiveSubscriptions = [[PGCancelableProxy storage] retain];
			[NSThread detachNewThreadSelector:@selector(threaded_sendFileEvents) toTarget:[self class] withObject:nil];
		}
		[self PG_allowPerformsWithStorage:PGActiveSubscriptions];
		struct kevent ev;
		EV_SET(&ev, _descriptor, EVFILT_VNODE, EV_ADD | EV_CLEAR, NOTE_DELETE | NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME | NOTE_REVOKE, 0, self);
		struct timespec timeout = {0, 0};
		if(-1 == kevent(PGKQueue, &ev, 1, NULL, 0, &timeout)) {
			[self release];
			return nil;
		}
	}
	return self;
}
- (PGSubscription *)rootSubscription
{
	return self;
}
- (void)noteFileEventDidOccurWithFlags:(NSNumber *)flagsNum
{
	NSMutableDictionary *const dict = [NSMutableDictionary dictionary];
	NSString *const path = [self path];
	if(path) [dict setObject:path forKey:PGSubscriptionPathKey];
	if(flagsNum) [dict setObject:flagsNum forKey:PGSubscriptionRootFlagsKey];
	[[self rootSubscription] AE_postNotificationName:PGSubscriptionEventDidOccurNotification userInfo:dict];
}

#pragma mark NSCopying Protocol

- (id)copyWithZone:(NSZone *)zone
{
	return [self retain];
}

#pragma mark PGSubscription

- (NSString *)path
{
	NSString *result = nil;
	char *path = calloc(PATH_MAX, sizeof(char));
	if(-1 != fcntl(_descriptor, F_GETPATH, path)) result = [[NSFileManager defaultManager] stringWithFileSystemRepresentation:path length:strlen(path)];
	free(path);
	return result;
}

#pragma mark NSObject

- (void)dealloc
{
	[self PG_cancelPerformsWithStorage:PGActiveSubscriptions];
	if(-1 != _descriptor) close(_descriptor);
	[super dealloc];
}

@end

@implementation PGKQueueBranchSubscription

#pragma mark Instance Methods

- (id)initWithPath:(NSString *)path
      parent:(PGKQueueBranchSubscription *)parent
{
	if((self = [self initWithPath:path])) {
		_parent = parent;
	}
	return self;
}
- (PGSubscription *)rootSubscription
{
	return _parent ? [_parent rootSubscription] : self;
}

#pragma mark PGLeafSubscription

- (id)initWithPath:(NSString *)path
{
	if(!(self = [super initWithPath:path])) return nil;
	BOOL isDir;
	if(![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || !isDir) {
		[self release];
		return nil;
	}
	NSMutableArray *const children = [NSMutableArray array];
	NSString *pathComponent;
	NSEnumerator *const pathComponentEnum = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
	while((pathComponent = [pathComponentEnum nextObject])) {
		PGSubscription *const child = [[[PGKQueueBranchSubscription alloc] initWithPath:[path stringByAppendingPathComponent:pathComponent] parent:self] autorelease];
		if(child) [children addObject:child];
		else if(EMFILE == errno) {
			[self release];
			return nil;
		}
	}
	_children = [children retain];
	return self;
}
- (void)noteFileEventDidOccurWithFlags:(NSNumber *)flagsNum
{
	if([self rootSubscription] == self) [super noteFileEventDidOccurWithFlags:flagsNum];
	else if(NOTE_WRITE & [flagsNum unsignedIntValue]) [super noteFileEventDidOccurWithFlags:nil];
}

#pragma mark NSObject

- (void)dealloc
{
	[_children release];
	[super dealloc];
}

@end

static void PGEventStreamCallback(ConstFSEventStreamRef streamRef, void *clientCallBackInfo, size_t numEvents, void *eventPaths, const FSEventStreamEventFlags eventFlags[], const FSEventStreamEventId eventIds[])
{
	[(PGFSEventBranchSubscription *)clientCallBackInfo noteFileEventsDidOccurAtPaths:(id)eventPaths];
}

@implementation PGFSEventBranchSubscription

#pragma mark Instance Methods

- (id)initWithPath:(NSString *)path
{
	if((self = [super init])) {
		_rootSubscription = [[PGSubscription subscriptionWithPath:path] retain];
		[_rootSubscription AE_addObserver:self selector:@selector(rootSubscriptionEventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
		[self subscribeWithPath:path];
	}
	return self;
}
- (void)subscribeWithPath:(NSString *)path
{
	if(_eventStream) [self unsubscribe];
	if(!path) return;
	FSEventStreamContext context = {0, self, NULL, NULL, NULL};
	_eventStream = FSEventStreamCreate(kCFAllocatorDefault, PGEventStreamCallback, &context, (CFArrayRef)[NSArray arrayWithObject:path], kFSEventStreamEventIdSinceNow, 0.0f, kFSEventStreamCreateFlagUseCFTypes | kFSEventStreamCreateFlagNoDefer);
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
- (void)noteFileEventsDidOccurAtPaths:(NSArray *)paths
{
	NSString *path;
	NSEnumerator *pathEnum = [paths objectEnumerator];
	while((path = [pathEnum nextObject])) [self AE_postNotificationName:PGSubscriptionEventDidOccurNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:path, PGSubscriptionPathKey, nil]];
}
- (void)rootSubscriptionEventDidOccur:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	unsigned const flags = [[[aNotif userInfo] objectForKey:PGSubscriptionRootFlagsKey] unsignedIntValue];
	if(!(flags & (NOTE_RENAME | NOTE_REVOKE | NOTE_DELETE))) return;
	[self subscribeWithPath:[[aNotif userInfo] objectForKey:PGSubscriptionPathKey]];
	[self AE_postNotificationName:PGSubscriptionEventDidOccurNotification userInfo:[aNotif userInfo]];
}

#pragma mark PGSubscription

- (NSString *)path
{
	return [_rootSubscription path];
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[self unsubscribe];
	[_rootSubscription release];
	[super dealloc];
}

@end
