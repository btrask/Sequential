#import "NSDateXAD.h"

@implementation NSDate (XAD)

+(NSDate *)XADDateWithTimeIntervalSince1904:(NSTimeInterval)interval
{
	return [NSDate dateWithTimeIntervalSince1970:interval-2082938400];
}

+(NSDate *)XADDateWithTimeIntervalSince1601:(NSTimeInterval)interval
{
	return [NSDate dateWithTimeIntervalSince1970:interval-11644473600];
}

+(NSDate *)XADDateWithMSDOSDateTime:(unsigned long)msdos
{
	int second=(msdos&31)*2;
	int minute=(msdos>>5)&63;
	int hour=(msdos>>11)&31;
	int day=(msdos>>16)&31;
	int month=(msdos>>21)&15;
	int year=1980+(msdos>>25);
	return [NSCalendarDate dateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:nil];
}

+(NSDate *)XADDateWithWindowsFileTimeLow:(uint32_t)low high:(uint32_t)high;
{
	uint64_t ticks=((uint64_t)high<<32)|(uint64_t)low;
	return [NSDate dateWithTimeIntervalSince1970:(double)ticks/10000000-11644473600];
}

@end
