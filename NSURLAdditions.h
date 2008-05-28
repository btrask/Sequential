#import <Cocoa/Cocoa.h>

@interface NSURL (AEAdditions)

+ (NSURL *)AE_URLWithString:(NSString *)aString;

- (NSImage *)AE_icon; // Returns the URL image for non-file URLs.

@end
