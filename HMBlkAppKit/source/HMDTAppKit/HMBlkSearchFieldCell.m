#import "HMBlkSearchFieldCell.h"
#import "HMAppKitEx.h"
#import "HMBlkPanel.h"

@implementation HMBlkSearchFieldCell

#pragma mark NSNibAwaking Protocol

- (void)awakeFromNib
{
	NSImage *const searchIcon = [NSImage HM_imageNamed:@"search-icon" for:self flipped:NO];
	[[self searchButtonCell] setImage:searchIcon];
	[[self searchButtonCell] setAlternateImage:searchIcon];
	[[self cancelButtonCell] setImage:[NSImage HM_imageNamed:@"search-cancel" for:self flipped:NO]];
	[[self cancelButtonCell] setAlternateImage:[NSImage HM_imageNamed:@"search-cancel-hilite" for:self flipped:NO]];
	[self setBackgroundColor:[NSColor colorWithDeviceWhite:0.25 alpha:0.8]];
}

#pragma mark NSTextFieldCell

- (NSText *)setUpFieldEditorAttributes:(NSText *)textObj
{
	NSText *const t = [super setUpFieldEditorAttributes:textObj];
	if([t respondsToSelector:@selector(setInsertionPointColor:)]) [(NSTextView *)t setInsertionPointColor:[NSColor whiteColor]];
	return t;
}

#pragma mark NSCell

- (void)drawWithFrame:(NSRect)frame inView:(NSView *)view
{
	NSRect const f = NSInsetRect(frame, 0.5, 0.5);
	float const r = NSHeight(f) / 2;
	NSBezierPath *const path = [[[NSBezierPath alloc] init] autorelease];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(f) + r, NSMinY(f) + r) radius:r startAngle:90 endAngle:270];
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMaxX(f) - r, NSMinY(f) + r) radius:r startAngle:270 endAngle:90];
	[path closePath];
	NSWindow *const window = [view window];
	id const responder = [window firstResponder];
	if([window isKeyWindow] && [responder isKindOfClass:[NSView class]] && [(NSView *)responder isDescendantOf:view]) {
		[NSGraphicsContext saveGraphicsState];
		NSSetFocusRingStyle(NSFocusRingOnly);
		[path stroke];
		[NSGraphicsContext restoreGraphicsState];
	}
	[NSGraphicsContext saveGraphicsState];
	[path addClip];
	[[self backgroundColor] set];
	NSRectFill(frame); // Use NSCompositeCopy.
	[NSGraphicsContext restoreGraphicsState];
	[[HMBlkPanel majorGridColor] set];
	[path stroke];
	[self drawInteriorWithFrame:frame inView:view];
}

@end
