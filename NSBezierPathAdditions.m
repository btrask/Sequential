#import "NSBezierPathAdditions.h"

@implementation NSBezierPath (AEAdditions)

+ (id)AE_bezierPathWithRoundRect:(NSRect)aRect
      cornerRadius:(float)radius
{
	NSBezierPath *const path = [self bezierPath];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(aRect) - radius, NSMaxY(aRect) - radius) radius:radius startAngle:0 endAngle:90];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(aRect) + radius, NSMaxY(aRect) - radius) radius:radius startAngle:90 endAngle:180];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(aRect) + radius, NSMinY(aRect) + radius) radius:radius startAngle:180 endAngle:270];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(aRect) - radius, NSMinY(aRect) + radius) radius:radius startAngle:270 endAngle:0];
	[path closePath];
	return path;
}

@end
