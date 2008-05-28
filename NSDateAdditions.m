#import "NSDateAdditions.h"

@implementation NSDate (AEAdditions)

+ (NSString *)AE_localizedStringFromTimeInterval:(NSTimeInterval)interval
{
	unsigned const hours = floor(interval / (60 * 60));
	if(hours) return 1 == hours ? NSLocalizedString(@"1 hour", nil) : [NSString stringWithFormat:NSLocalizedString(@"%u hours", nil), hours];
	unsigned const minutes = floor(((unsigned)interval % (60 * 60)) / 60.0);
	if(minutes) return 1 == minutes ? NSLocalizedString(@"1 minute", nil) : [NSString stringWithFormat:NSLocalizedString(@"%u minutes", nil), minutes];
	unsigned const seconds = (unsigned)ceil(interval) % 60;
	return 1 == seconds ? NSLocalizedString(@"1 second", nil) : [NSString stringWithFormat:NSLocalizedString(@"%u seconds", nil), seconds];
}
- (NSString *)AE_localizedStringWithDateStyle:(CFDateFormatterStyle)dateStyle
              timeStyle:(CFDateFormatterStyle)timeStyle
{
	static CFDateFormatterRef f = nil;
	if(f && (CFDateFormatterGetDateStyle(f) != dateStyle || CFDateFormatterGetTimeStyle(f) != timeStyle)) {
		CFRelease(CFDateFormatterGetLocale(f));
		CFRelease(f);
		f = nil;
	}
	if(!f) f = CFDateFormatterCreate(kCFAllocatorDefault, CFLocaleCopyCurrent(), dateStyle, timeStyle);
	return [(NSString *)CFDateFormatterCreateStringWithDate(kCFAllocatorDefault, f, (CFDateRef)self) autorelease];
}

@end
