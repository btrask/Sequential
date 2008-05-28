#import "PGSubscription.h"
#import <sys/time.h>
#import <unistd.h>

// Categories
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGSubscriptionEventDidOccurNotification = @"PGSubscriptionEventDidOccur";

NSString *const PGSubscriptionFlagsKey = @"PGSubscriptionFlags";

static int           PGKQueue        = -1;
static NSMutableSet *PGSubscriptions = nil;

@interface PGSubscription (Private)

+ (void)_threaded_sendFileEvents;
+ (void)_sendFileEvent:(NSDictionary *)aDict;

@end

@implementation PGSubscription

#pragma mark Private Protocol

+ (void)_threaded_sendFileEvents
{
	for(;;) {
		NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
		struct kevent ev[5]; // Group up to 5 events at once.
		unsigned const count = kevent(PGKQueue, NULL, 0, ev, 5, NULL);
		unsigned i = 0;
		for(; i < count; i++) [self performSelectorOnMainThread:@selector(_sendFileEvent:) withObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithNonretainedObject:(id)ev[i].udata], @"Subscription", [NSNumber numberWithUnsignedInt:ev[i].fflags], PGSubscriptionFlagsKey, nil] waitUntilDone:NO];
		[pool release];
	}
}
+ (void)_sendFileEvent:(NSDictionary *)aDict
{
	NSValue *const subscriptionValue = [aDict objectForKey:@"Subscription"];
	if([PGSubscriptions containsObject:subscriptionValue]) [[subscriptionValue nonretainedObjectValue] AE_postNotificationName:PGSubscriptionEventDidOccurNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[aDict objectForKey:PGSubscriptionFlagsKey], PGSubscriptionFlagsKey, nil]];
}

#pragma mark Instance Methods

- (id)initWithPath:(NSString *)path
{
	if((self = [super init])) {
		_descriptor = [path AE_fileDescriptor];
		if(-1 == _descriptor) {
			[self release];
			return nil;
		}
		if(-1 == PGKQueue) {
			PGKQueue = kqueue();
			PGSubscriptions = [[NSMutableSet alloc] init];
			[NSThread detachNewThreadSelector:@selector(_threaded_sendFileEvents) toTarget:[self class] withObject:nil];
		}
		struct kevent ev;
		EV_SET(&ev, _descriptor, EVFILT_VNODE, EV_ADD | EV_CLEAR, NOTE_DELETE | NOTE_WRITE | NOTE_EXTEND | NOTE_ATTRIB | NOTE_LINK | NOTE_RENAME | NOTE_REVOKE, 0, self);
		struct timespec timeout = {0, 0};
		if(-1 == kevent(PGKQueue, &ev, 1, NULL, 0, &timeout)) {
			[self release];
			return nil;
		}
		[PGSubscriptions addObject:[NSValue valueWithNonretainedObject:self]];
	}
	return self;
}

#pragma mark NSObject

- (void)dealloc
{
	[PGSubscriptions removeObject:[NSValue valueWithNonretainedObject:self]];
	if(-1 != _descriptor) close(_descriptor);
	[super dealloc];
}

@end
