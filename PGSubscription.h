#import <Cocoa/Cocoa.h>
#import <sys/event.h>

extern NSString *const PGSubscriptionEventDidOccurNotification;

extern NSString *const PGSubscriptionFlagsKey;

@interface PGSubscription : NSObject
{
	@private
	int _descriptor;
}

- (id)initWithPath:(NSString *)path;

@end
