#import "PGLevelIndicatorCell.h"

// Categories
#import "NSBezierPathAdditions.h"

@implementation PGLevelIndicatorCell

#pragma mark Instance Methods

- (BOOL)hidden
{
	return _hidden;
}
- (void)setHidden:(BOOL)flag
{
	_hidden = flag;
}

#pragma mark NSCell

- (void)drawWithFrame:(NSRect)aRect
        inView:(NSView *)aView
{
	if([self hidden]) return;

	[[NSColor colorWithDeviceWhite:0.9 alpha:0.8] set];
	[[NSBezierPath AE_bezierPathWithRoundRect:NSInsetRect(aRect, 0.5, 0.5) cornerRadius:(NSHeight(aRect) - 1) / 2] stroke];

	NSRect r = aRect;
	r.size.width = ceilf(NSWidth(aRect) * [[self objectValue] floatValue]); // For some reason -[NSCell floatValue] doesn't work.
	[NSGraphicsContext saveGraphicsState];
	[[NSBezierPath bezierPathWithRect:r] addClip];
	[[NSBezierPath AE_bezierPathWithRoundRect:NSInsetRect(aRect, 2, 2) cornerRadius:(NSHeight(aRect) - 4) / 2] addClip];
	
	r.size.height = ceilf(NSHeight(r) / 2);
	[[NSColor colorWithDeviceWhite:0.95 alpha:0.8] set];
	NSRectFillUsingOperation(r, NSCompositeSourceOver);
	r.origin.y += NSHeight(r);
	[[NSColor colorWithDeviceWhite:0.85 alpha:0.8] set];
	NSRectFillUsingOperation(r, NSCompositeSourceOver);
	
	[NSGraphicsContext restoreGraphicsState];
}

@end
