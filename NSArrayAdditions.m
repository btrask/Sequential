#import "NSArrayAdditions.h"

@implementation NSArray (AEAdditions)

- (NSArray *)AE_arrayWithUniqueObjects
{
	NSMutableArray *const array = [[self mutableCopy] autorelease];
	unsigned i = 0, count;
	for(; i < (count = [array count]); i++) [array removeObject:[array objectAtIndex:i] inRange:NSMakeRange(i + 1, count - i - 1)];
	return array;
}

@end
