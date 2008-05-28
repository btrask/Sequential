#import <Cocoa/Cocoa.h>

@interface NSAttributedString (AEAdditions)

+ (id)AE_attributedStringWithFileIcon:(NSImage *)anImage name:(NSString *)fileName;

@end
