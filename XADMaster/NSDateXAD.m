#import "NSDateXAD.h"

#import <math.h>

#define SecondsFrom2000To2001 31622400
#define SecondsFrom1904To1970 2082844800
#define SecondsFrom1601To1970 11644473600
#define SecondsFrom1970ToLastDayOf1978 283910400

@implementation NSDate (XAD)

+(NSDate *)XADDateWithYear:(int)year month:(int)month day:(int)day
hour:(int)hour minute:(int)minute second:(int)second timeZone:(NSTimeZone *)timezone
{
	#if MAC_OS_X_VERSION_MIN_REQUIRED>=1040
	NSDateComponents *components=[[NSDateComponents new] autorelease];
	[components setYear:year];
	[components setMonth:month];
	[components setDay:day];
	[components setHour:hour];
	[components setMinute:minute];
	[components setSecond:second];
	if(timezone) [components setTimeZone:timezone];

	NSCalendar *gregorian=[[[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar] autorelease];
	return [gregorian dateFromComponents:components];
	#else
	return [NSCalendarDate dateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:nil];
	#endif
}

+(NSDate *)XADDateWithTimeIntervalSince2000:(NSTimeInterval)interval
{
	return [NSDate dateWithTimeIntervalSinceReferenceDate:interval-SecondsFrom2000To2001];
}

+(NSDate *)XADDateWithTimeIntervalSince1904:(NSTimeInterval)interval
{
	return [NSDate dateWithTimeIntervalSince1970:interval-SecondsFrom1904To1970
	-[[NSTimeZone defaultTimeZone] secondsFromGMT]];
}

+(NSDate *)XADDateWithTimeIntervalSince1601:(NSTimeInterval)interval
{
	return [NSDate dateWithTimeIntervalSince1970:interval-SecondsFrom1601To1970];
}

+(NSDate *)XADDateWithMSDOSDate:(uint16_t)date time:(uint16_t)time
{
	return [self XADDateWithMSDOSDate:date time:time timeZone:nil];
}

+(NSDate *)XADDateWithMSDOSDate:(uint16_t)date time:(uint16_t)time timeZone:(NSTimeZone *)tz
{
	return [self XADDateWithMSDOSDateTime:((uint32_t)date<<16)|(uint32_t)time timeZone:tz];
}

+(NSDate *)XADDateWithMSDOSDateTime:(uint32_t)msdos
{
	return [self XADDateWithMSDOSDateTime:msdos timeZone:nil];
}

+(NSDate *)XADDateWithMSDOSDateTime:(uint32_t)msdos timeZone:(NSTimeZone *)tz
{
	int second=(msdos&31)*2;
	int minute=(msdos>>5)&63;
	int hour=(msdos>>11)&31;
	int day=(msdos>>16)&31;
	int month=(msdos>>21)&15;
	int year=1980+(msdos>>25);
	return [self XADDateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:tz];
}

+(NSDate *)XADDateWithWindowsFileTime:(uint64_t)filetime
{
	return [NSDate XADDateWithTimeIntervalSince1601:(double)filetime/10000000];
}

+(NSDate *)XADDateWithWindowsFileTimeLow:(uint32_t)low high:(uint32_t)high
{
	return [NSDate XADDateWithWindowsFileTime:((uint64_t)high<<32)|(uint64_t)low];
}

+(NSDate *)XADDateWithCPMDate:(uint16_t)date time:(uint16_t)time
{
	int second=(time&31)*2;
	int minute=(time>>5)&63;
	int hour=(time>>11)&31;

	double seconds=second+minute*60+hour*3600+date*86400;

	return [NSDate dateWithTimeIntervalSince1970:seconds+SecondsFrom1970ToLastDayOf1978];
}



#ifndef __MINGW32__
-(struct timeval)timevalStruct
{
	NSTimeInterval seconds=[self timeIntervalSince1970];
	struct timeval tv={ (time_t)seconds, (suseconds_t)(fmod(seconds,1.0)*1000000) };
	return tv;
}

-(struct timespec)timespecStruct;
{
	NSTimeInterval seconds=[self timeIntervalSince1970];
	struct timespec ts={ (time_t)seconds, (long)(fmod(seconds,1.0)*1000000000) };
	return ts;
}
#endif



#ifdef __APPLE__
#ifdef __UTCUTILS__
-(UTCDateTime)UTCDateTime
{
	NSTimeInterval seconds=[self timeIntervalSince1970]+SecondsFrom1904To1970;
	UTCDateTime utc={
		.highSeconds=(UInt16)(seconds/4294967296.0),
		.lowSeconds=(UInt32)seconds,
		.fraction=(UInt16)(seconds*65536.0)
	};
	return utc;
}
#endif
#endif



#ifdef __MINGW32__
-(FILETIME)FILETIME
{
	int64_t val=([self timeIntervalSince1970]+SecondsFrom1601To1970)*10000000;
	FILETIME filetime={
		.dwLowDateTime=val&0xffffffff,
		.dwHighDateTime=val>>32
	};
	return filetime;
}
#endif

@end
