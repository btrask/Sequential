#import <Cocoa/Cocoa.h>

@interface PGKeyViewLoopView : NSView

@end

int main(int argc, char **argv)
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	[PGKeyViewLoopView poseAsClass:[NSView class]];
	[pool release];
	return NSApplicationMain(argc, (const char **)argv);
}

@implementation PGKeyViewLoopView

- (NSView *)nextValidKeyView
{
	NSView *const view = [super nextValidKeyView];
	return view ? view : self;
}
- (NSView *)previousValidKeyView
{
	NSView *const view = [super previousValidKeyView];
	return view ? view : self;
}

@end
