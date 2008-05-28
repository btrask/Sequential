#import "NSColorAdditions.h"

#define PGCheckerboardSquareSize 8
#define PGCheckerboardSize (PGCheckerboardSquareSize * 2)

@implementation NSColor (AEAdditions)

- (NSColor *)AE_checkerboardPatternColor
{
	NSImage *const checkerboard = [[[NSImage alloc] initWithSize:NSMakeSize(PGCheckerboardSize, PGCheckerboardSize)] autorelease];
	[checkerboard lockFocus];
	[self set];
	NSRectFill(NSMakeRect(0, 0, PGCheckerboardSize, PGCheckerboardSize));
	[[NSColor colorWithDeviceWhite:1 alpha:0.1] set];
	NSRectFillUsingOperation(NSMakeRect(0, 0, PGCheckerboardSquareSize, PGCheckerboardSquareSize), NSCompositeSourceOver);
	NSRectFillUsingOperation(NSMakeRect(PGCheckerboardSquareSize, PGCheckerboardSquareSize, PGCheckerboardSquareSize, PGCheckerboardSquareSize), NSCompositeSourceOver);
	[[NSColor colorWithDeviceWhite:0 alpha:0.1] set];
	NSRectFillUsingOperation(NSMakeRect(0, PGCheckerboardSquareSize, PGCheckerboardSquareSize, PGCheckerboardSquareSize), NSCompositeSourceOver);
	NSRectFillUsingOperation(NSMakeRect(PGCheckerboardSquareSize, 0, PGCheckerboardSquareSize, PGCheckerboardSquareSize), NSCompositeSourceOver);
	[checkerboard unlockFocus];
	return [NSColor colorWithPatternImage:checkerboard];
}

@end
