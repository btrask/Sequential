#import "PGRoundedBackgroundView.h"

// Categories
#import "NSBezierPathAdditions.h"

@implementation PGRoundedBackgroundView

#pragma mark NSView

- (BOOL)isOpaque
{
	return NO;
}
- (void)drawRect:(NSRect)aRect
{
	[[NSColor windowBackgroundColor] set];
	[[NSBezierPath AE_bezierPathWithRoundRect:NSInsetRect([self bounds], 1, 1) cornerRadius:20] fill];
}

#pragma mark NSResponder

- (void)mouseDown:(NSEvent *)anEvent
{
	[[self window] makeFirstResponder:[self superview]];
}
- (void)rightMouseDown:(NSEvent *)anEvent {}

@end
