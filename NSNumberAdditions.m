/* Copyright © 2007-2008, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "NSNumberAdditions.h"

@implementation NSNumber (AEAdditions)

- (NSString *)AE_localizedStringWithFractionDigits:(unsigned)placesAfterDecimal
{
	static CFNumberFormatterRef f = nil;
	if(!f) {
		CFLocaleRef const locale = CFLocaleCopyCurrent();
		f = CFNumberFormatterCreate(kCFAllocatorDefault, locale, kCFNumberFormatterDecimalStyle);
		CFRelease(locale);
	}
	NSNumber *const precision = [NSNumber numberWithInt:placesAfterDecimal];
	CFNumberFormatterSetProperty(f, kCFNumberFormatterMinFractionDigits, (CFNumberRef)precision);
	CFNumberFormatterSetProperty(f, kCFNumberFormatterMaxFractionDigits, (CFNumberRef)precision);
	return [(NSString *)CFNumberFormatterCreateStringWithNumber(kCFAllocatorDefault, f, (CFNumberRef)self) autorelease];
}
- (NSString *)AE_localizedStringAsBytes
{
	double b = (double)[self unsignedLongLongValue];
	unsigned magnitude = 0;
	for(; b >= 1024 && magnitude < 4; magnitude++) b /= 1024;
	NSString *unit = nil;
	switch(magnitude) {
		case 0: unit = @"B"; break;
		case 1: unit = @"KB"; break;
		case 2: unit = @"MB"; break;
		case 3: unit = @"GB"; break;
		case 4: unit = @"TB"; break;
		default: NSAssert(0, @"Divided too far.");
	}
	static CFNumberFormatterRef f = nil;
	if(!f) {
		CFLocaleRef const locale = CFLocaleCopyCurrent();
		f = CFNumberFormatterCreate(kCFAllocatorDefault, locale, kCFNumberFormatterDecimalStyle);
		CFRelease(locale);
		CFNumberFormatterSetProperty(f, kCFNumberFormatterMaxFractionDigits, (CFNumberRef)[NSNumber numberWithInt:1]);
	}
	return [NSString stringWithFormat:@"%@ %@", [(NSString *)CFNumberFormatterCreateStringWithNumber(kCFAllocatorDefault, f, (CFNumberRef)[NSNumber numberWithDouble:b]) autorelease], NSLocalizedString(unit, @"Units (bytes, kilobytes, etc).")];
}

@end
