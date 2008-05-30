#import "NSTextFieldAdditions.h"

@implementation NSTextField (AEAdditions)

- (void)AE_setAttributedStringValue:(NSAttributedString *)anObject
{
	NSMutableAttributedString *const str = [[anObject mutableCopy] autorelease];
	[str addAttributes:[[self attributedStringValue] attributesAtIndex:0 effectiveRange:NULL] range:NSMakeRange(0, [str length])];
	[self setAttributedStringValue:str];
}

@end
