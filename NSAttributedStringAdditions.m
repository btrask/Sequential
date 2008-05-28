#import "NSAttributedStringAdditions.h"

@interface PGIconAttachmentCell : NSTextAttachmentCell

- (id)initImageCell:(NSImage *)anImage;

@end

@implementation NSAttributedString (AEAdditions)

#pragma mark Instance Methods

+ (id)AE_attributedStringWithFileIcon:(NSImage *)anImage
      name:(NSString *)fileName
{
	NSTextAttachment *const attachment = [[[NSTextAttachment alloc] initWithFileWrapper:nil] autorelease];
	[attachment setAttachmentCell:[[[PGIconAttachmentCell alloc] initImageCell:anImage] autorelease]];
	NSMutableAttributedString *const result = [[[NSMutableAttributedString alloc] init] autorelease];
	if(anImage) {
		[result appendAttributedString:[NSAttributedString attributedStringWithAttachment:attachment]];
		[[result mutableString] appendString:@" "];
	}
	[[result mutableString] appendString:fileName];
	[result addAttribute:NSFontAttributeName value:[NSFont menuFontOfSize:14] range:NSMakeRange(0, [result length])]; // Use 14 instead of 0 (default) for the font size because the default seems to be 13, which is wrong.
	return result;
}

@end

@implementation PGIconAttachmentCell

#pragma mark Instance Methods

- (id)initImageCell:(NSImage *)anImage
{
	// This is the ugliest hack I have ever written. The icons fail to draw if there has never been a window loaded. Defer must be NO.
	// The specific error is "-[_NSExistingCGSContext focusView:inWindow:]: selector not recognized" in -[NSTextAttachmentCell drawWithFrame:inView:].
	static BOOL createdWindow = NO;
	if(!createdWindow) {
		[[[NSWindow alloc] initWithContentRect:NSZeroRect styleMask:NSBorderlessWindowMask backing:NSBackingStoreBuffered defer:NO] release];
		createdWindow = YES;
	}

	[anImage setScalesWhenResized:YES];
	[anImage setSize:NSMakeSize(16, 16)];
	return [super initImageCell:anImage];
}

#pragma mark NSTextAttachmentCell Protocol

- (NSPoint)cellBaselineOffset
{
	return NSMakePoint(0, -3);
}

@end
