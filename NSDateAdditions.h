#import <Cocoa/Cocoa.h>

@interface NSDate (AEAdditions)

+ (NSString *)AE_localizedStringFromTimeInterval:(NSTimeInterval)interval;
- (NSString *)AE_localizedStringWithDateStyle:(CFDateFormatterStyle)dateStyle timeStyle:(CFDateFormatterStyle)timeStyle;

@end
