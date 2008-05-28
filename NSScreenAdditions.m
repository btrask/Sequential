#import "NSScreenAdditions.h"

@implementation NSScreen (AEAdditions)

+ (NSScreen *)AE_mainScreen
{
	NSArray *const screens = [self screens];
	return [screens count] ? [screens objectAtIndex:0] : nil;
}

@end
