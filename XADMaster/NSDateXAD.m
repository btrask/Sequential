#import "NSDateXAD.h"

#import <math.h>

#define SecondsFrom1904To1970 2082844800
#define SecondsFrom1601To1970 11644473600

@implementation NSDate (XAD)

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
	return [self XADDateWithMSDOSDateTime:((uint32_t)date<<16)|(uint32_t)time];
}

+(NSDate *)XADDateWithMSDOSDateTime:(uint32_t)msdos
{
	int second=(msdos&31)*2;
	int minute=(msdos>>5)&63;
	int hour=(msdos>>11)&31;
	int day=(msdos>>16)&31;
	int month=(msdos>>21)&15;
	int year=1980+(msdos>>25);
	return [NSCalendarDate dateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:nil];
}

+(NSDate *)XADDateWithWindowsFileTime:(uint64_t)filetime
{
	return [NSDate XADDateWithTimeIntervalSince1601:(double)filetime/10000000];
}

+(NSDate *)XADDateWithWindowsFileTimeLow:(uint32_t)low high:(uint32_t)high
{
	return [NSDate XADDateWithWindowsFileTime:((uint64_t)high<<32)|(uint64_t)low];
}



#ifndef __MINGW32__
-(struct timeval)timevalStruct
{
	NSTimeInterval seconds=[self timeIntervalSince1970];
	struct timeval tv={ (time_t)seconds, (suseconds_t)(fmod(seconds,1.0)*1000000) };
	return tv;
}
#endif



#ifdef __APPLE__
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
