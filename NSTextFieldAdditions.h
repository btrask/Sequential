#import <Cocoa/Cocoa.h>

@interface NSTextField (AEAdditions)

- (void)AE_setAttributedStringValue:(NSAttributedString *)str; // Keeps existing attributes.

@end
