#import "NSNumberAdditions.h"

@implementation NSNumber (AEAdditions)

- (NSString *)AE_localizedStringAsBytes
{
	double b = (double)[self unsignedLongLongValue];
	unsigned magnitude = 0;
	for(; b >= 1024 && magnitude < 4; magnitude++) b /= 1024;
	NSString *unit = nil;
	switch(magnitude) {
		case 0: unit = NSLocalizedString(@"B", nil); break;
		case 1: unit = NSLocalizedString(@"KB", nil); break;
		case 2: unit = NSLocalizedString(@"MB", nil); break;
		case 3: unit = NSLocalizedString(@"GB", nil); break;
		case 4: unit = NSLocalizedString(@"TB", nil); break;
		default: NSAssert(0, @"Divided too far.");
	}
	return [NSString stringWithFormat:@"%.1f %@", b, unit];
}

@end
