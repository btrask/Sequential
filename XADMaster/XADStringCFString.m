#import "XADString.h"

@implementation XADString (PlatformSpecific)

+(NSString *)encodingNameForEncoding:(NSStringEncoding)encoding
{
	// Internal kludge: Don't actually return an NSString. Instead,
	// return an NSNumber containing the encoding number, that can
	// be quickly unpacked later. This should be safe, as the object
	// will not actually be touched by any other function than the
	// ones in XADStringCFString.
	return (NSString *)[NSNumber numberWithLong:encoding];
}

+(NSStringEncoding)encodingForEncodingName:(NSString *)encoding
{
	if([encoding isKindOfClass:[NSNumber class]])
	{
		// If the encodingname is actually an NSNumber, just unpack it and convert.
		return [(NSNumber *)encoding longValue];
	}
	else
	{
		// Look up the encoding number for the name.
		return CFStringConvertEncodingToNSStringEncoding(
		CFStringConvertIANACharSetNameToEncoding((CFStringRef)encoding));
	}
}

+(CFStringEncoding)CFStringEncodingForEncodingName:(NSString *)encodingname
{
	return CFStringConvertNSStringEncodingToEncoding([self encodingForEncodingName:encodingname]);
}

+(BOOL)canDecodeData:(NSData *)data encodingName:(NSString *)encoding
{
	return [self canDecodeBytes:[data bytes] length:[data length] encodingName:encoding];
}

+(BOOL)canDecodeBytes:(const void *)bytes length:(size_t)length encodingName:(NSString *)encoding
{
	CFStringEncoding cfenc=[XADString CFStringEncodingForEncodingName:encoding];
	if(cfenc==kCFStringEncodingInvalidId) return NO;
	CFStringRef str=CFStringCreateWithBytes(kCFAllocatorDefault,bytes,length,cfenc,false);
	if(str) { CFRelease(str); return YES; }
	else return NO;
}

+(NSString *)stringForData:(NSData *)data encodingName:(NSString *)encoding
{
	return [self stringForBytes:[data bytes] length:[data length] encodingName:encoding];
}

+(NSString *)stringForBytes:(const void *)bytes length:(size_t)length encodingName:(NSString *)encoding
{
	CFStringEncoding cfenc=[XADString CFStringEncodingForEncodingName:encoding];
	if(cfenc==kCFStringEncodingInvalidId) return nil;
	CFStringRef str=CFStringCreateWithBytes(kCFAllocatorDefault,bytes,length,cfenc,false);
	return [(id)str autorelease];
}

+(NSData *)dataForString:(NSString *)string encodingName:(NSString *)encoding
{
	int numchars=[string length];

	CFIndex numbytes;
	if(CFStringGetBytes((CFStringRef)string,CFRangeMake(0,numchars),
	[self CFStringEncodingForEncodingName:encoding],0,false,
	NULL,0,&numbytes)!=numchars) return nil;

	uint8_t *bytes=malloc(numbytes);

	CFStringGetBytes((CFStringRef)string,CFRangeMake(0,numchars),
	[self CFStringEncodingForEncodingName:encoding],0,false,
	bytes,numbytes,NULL);

	return [NSData dataWithBytesNoCopy:bytes length:numbytes freeWhenDone:YES];
}

+(NSArray *)availableEncodingNames
{
	NSMutableArray *array=[NSMutableArray array];

	const CFStringEncoding *encodings=CFStringGetListOfAvailableEncodings();

	while(*encodings!=kCFStringEncodingInvalidId)
	{
		NSString *name=(NSString *)CFStringConvertEncodingToIANACharSetName(*encodings);
		NSString *description=[NSString localizedNameOfStringEncoding:CFStringConvertEncodingToNSStringEncoding(*encodings)];
		if(name)
		{
			[array addObject:[NSArray arrayWithObjects:description,name,nil]];
		}
		encodings++;
	}

	return array;
}

@end
