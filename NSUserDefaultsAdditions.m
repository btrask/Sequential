#import "NSUserDefaultsAdditions.h"

@implementation NSUserDefaults (AEAdditions)

#pragma mark Instance Methods

- (id)AE_decodedObjectForKey:(NSString *)defaultName
{
	NSData *const data = [self dataForKey:defaultName];
	return (data ? [NSUnarchiver unarchiveObjectWithData:data] : nil);
}
- (void)AE_encodeObject:(id)value
        forKey:(NSString *)defaultName
{
	[self setObject:(value ? [NSArchiver archivedDataWithRootObject:value] : nil) forKey:defaultName];
}

@end
