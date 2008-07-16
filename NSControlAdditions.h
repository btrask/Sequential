#import <Cocoa/Cocoa.h>

@interface NSControl (AEAdditions)

- (void)AE_setAttributedStringValue:(NSAttributedString *)str; // Keeps existing attributes.

@end
