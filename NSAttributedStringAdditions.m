/* Copyright © 2007-2008 Ben Trask. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
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
