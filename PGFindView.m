#import "PGFindView.h"

// Views
@class PGBezelPanel;

@implementation PGFindView

#pragma mark PGBezelPanelContentView Protocol

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)s
{
	return (NSRect){aRect.origin, NSWidth([self frame]) * s, NSHeight([self frame]) * s};
}

@end

@implementation PGFindlessTextView

#pragma mark NSTextView

- (IBAction)performFindPanelAction:(id)sender
{
	[self doesNotRecognizeSelector:_cmd];
}

#pragma mark NSObject

+ (BOOL)instancesRespondToSelector:(SEL)aSelector
{
	return @selector(performFindPanelAction:) == aSelector ? NO : [super instancesRespondToSelector:aSelector];
}
- (BOOL)respondsToSelector:(SEL)aSelector
{
	return @selector(performFindPanelAction:) == aSelector ? NO : [super respondsToSelector:aSelector];
}

@end
