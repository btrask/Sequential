#import "PGDragHighlightView.h"

// Views
@class PGBezelPanel;

@implementation PGDragHighlightView

#pragma mark PGBezelPanelView Protocol

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)scaleFactor
{
	[_highlightPath release];
	_highlightPath = nil;
	return aRect;
}

#pragma mark NSView

- (BOOL)isOpaque
{
	return YES;
}
- (void)drawRect:(NSRect)aRect
{
	if(!_highlightPath) {
		_highlightPath = [[NSBezierPath bezierPathWithRect:NSInsetRect([self bounds], 2, 2)] retain];
		[_highlightPath setLineWidth:4];
		[_highlightPath setLineJoinStyle:NSRoundLineJoinStyle];
	}

	int i;
	NSRect const *rects;
	[self getRectsBeingDrawn:&rects count:&i];
	[[NSColor clearColor] set];
	while(i--) NSRectFill(rects[i]);

	[[NSColor alternateSelectedControlColor] set];
	[_highlightPath stroke];
}

#pragma mark NSObject

- (void)dealloc
{
	[_highlightPath release];
	[super dealloc];
}

@end
