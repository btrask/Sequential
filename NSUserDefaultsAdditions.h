#import <Cocoa/Cocoa.h>

@interface NSUserDefaults (AEAdditions)

- (id)AE_decodedObjectForKey:(NSString *)defaultName;
- (void)AE_encodeObject:(id)value forKey:(NSString *)defaultName;

@end
