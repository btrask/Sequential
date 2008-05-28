#import "NSObjectAdditions.h"

BOOL PGIsLeopardOrLater(void)
{
	return floor(NSAppKitVersionNumber) > NSAppKitVersionNumber10_4;
}

static unsigned PGDisabledScreenUpdateCount = 0;
extern void PGDisableScreenUpdates(void)
{
	PGDisabledScreenUpdateCount++;
	NSDisableScreenUpdates();
}
extern void PGEnableScreenUpdates(void)
{
	NSEnableScreenUpdates();
	if(PGDisabledScreenUpdateCount) PGDisabledScreenUpdateCount--;
}
extern BOOL PGScreenUpdatesEnabled(void)
{
	return 0 == PGDisabledScreenUpdateCount;
}

@implementation NSObject (AEAdditions)

#pragma mark Instance Methods

- (void)AE_postNotificationName:(NSString *)aName
{
	[self AE_postNotificationName:aName userInfo:nil];
}
- (void)AE_postNotificationName:(NSString *)aName
        userInfo:(NSDictionary *)aDict
{
	[[NSNotificationCenter defaultCenter] postNotificationName:aName object:self userInfo:aDict];
}

#pragma mark -

- (void)AE_addObserver:(id)observer
        selector:(SEL)aSelector
        name:(NSString *)aName
{
	[[NSNotificationCenter defaultCenter] addObserver:observer selector:aSelector name:aName object:self];
}
- (void)AE_removeObserver
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}
- (void)AE_removeObserver:(id)observer
        name:(NSString *)aName
{
	[[NSNotificationCenter defaultCenter] removeObserver:observer name:aName object:self];
}

#pragma mark -

- (void)AE_performSelector:(SEL)aSelector
        withObject:(id)anArgument
	afterDelay:(NSTimeInterval)delay
{
	[self performSelector:aSelector withObject:anArgument afterDelay:delay inModes:[NSArray arrayWithObject:PGCommonRunLoopsMode]];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(id<NSMenuItem>)anItem
{
	return [self respondsToSelector:[anItem action]];
}

@end
