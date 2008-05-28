#import <Cocoa/Cocoa.h>

#ifndef NSAppKitVersionNumber10_4
#define NSAppKitVersionNumber10_4 824
#endif
extern BOOL PGIsLeopardOrLater(void);

extern void PGDisableScreenUpdates(void); // NSDisable/EnableScreenUpdates() do not provide a way to detect whether updates are enabled, so we wrap them and store a flag.
extern void PGEnableScreenUpdates(void);
extern BOOL PGScreenUpdatesEnabled(void); // This function will have false negatives: screen updates are automatically turned back on after a certain amount of time. But that's OK for our purposes.

#define PGCommonRunLoopsMode (NSString *)kCFRunLoopCommonModes

@interface NSObject (AEAdditions)

- (void)AE_postNotificationName:(NSString *)aName;
- (void)AE_postNotificationName:(NSString *)aName userInfo:(NSDictionary *)aDict;

- (void)AE_addObserver:(id)observer selector:(SEL)aSelector name:(NSString *)aName;
- (void)AE_removeObserver;
- (void)AE_removeObserver:(id)observer name:(NSString *)aName;

- (void)AE_performSelector:(SEL)aSelector withObject:(id)anArgument afterDelay:(NSTimeInterval)delay; // Uses PGCommonRunLoopsMode.

@end
