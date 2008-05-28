#import <Cocoa/Cocoa.h>

@interface NSBezierPath (AEAdditions)

+ (id)AE_bezierPathWithRoundRect:(NSRect)aRect cornerRadius:(float)radius;

@end
