#import <Cocoa/Cocoa.h>

@interface NSScreen (AEAdditions)

+ (NSScreen *)AE_mainScreen; // Returns the real main screen.

@end
