#import "XADString.h"

#import <unicode/ucnv.h>

@implementation XADString (PlatformSpecific)

+(NSString *)stringForData:(NSData *)data encodingName:(NSString *)encoding
{
	if([data length]==0) return @"";

	UErrorCode err=U_ZERO_ERROR;
	UConverter *conv=ucnv_open([encoding UTF8String],&err);
	if(!conv) return nil;

	int numbytes=[data length];
	const char *bytebuf=[data bytes];

	ucnv_setToUCallBack(conv,UCNV_TO_U_CALLBACK_STOP,NULL,NULL,NULL,&err);
	if(U_FAILURE(err)) { ucnv_close(conv); return nil; }

	int numchars=ucnv_toUChars(conv,NULL,0,bytebuf,numbytes,&err);
	if(err!=U_BUFFER_OVERFLOW_ERROR) { ucnv_close(conv); return nil; }

	err=U_ZERO_ERROR;
	unichar *charbuf=malloc(numchars*sizeof(unichar));
	ucnv_toUChars(conv,charbuf,numchars,bytebuf,numbytes,&err);

	ucnv_close(conv);

	if(U_FAILURE(err))
	{
		free(charbuf);
		return nil;
	}
	else
	{
		return [[[NSString alloc] initWithCharactersNoCopy:charbuf length:numchars freeWhenDone:YES] autorelease];
	}
}

+(NSData *)dataForString:(NSString *)string encodingName:(NSString *)encoding
{
	if([string length]==0) return [NSData data];

	UErrorCode err=U_ZERO_ERROR;
	UConverter *conv=ucnv_open([encoding UTF8String],&err);
	if(!conv) return nil;

	ucnv_setFromUCallBack(conv,UCNV_FROM_U_CALLBACK_STOP,NULL,NULL,NULL,&err);
	if(U_FAILURE(err)) { ucnv_close(conv); return nil; }

	int numchars=[string length];
	unichar charbuf[numchars];
	[string getCharacters:charbuf range:NSMakeRange(0,numchars)];

	int numbytes=ucnv_fromUChars(conv,NULL,0,charbuf,numchars,&err);
	if(err!=U_BUFFER_OVERFLOW_ERROR) { ucnv_close(conv); return nil; }

	err=U_ZERO_ERROR;
	char *bytebuf=malloc(numbytes);
	ucnv_fromUChars(conv,bytebuf,numbytes,charbuf,numchars,&err);

	ucnv_close(conv);

	if(U_FAILURE(err))
	{
		free(bytebuf);
		return nil;
	}
	else
	{
		return [NSData dataWithBytesNoCopy:bytebuf length:numbytes freeWhenDone:YES];
	}

}

+(NSArray *)availableEncodingNames
{
	int numencodings=ucnv_countAvailable();
	NSMutableArray *array=[NSMutableArray arrayWithCapacity:numencodings];
	UErrorCode err=U_ZERO_ERROR;

	for(int i=0;i<numencodings;i++)
	{
		const char *name=ucnv_getAvailableName(i);

		NSMutableArray *encodingarray=[NSMutableArray arrayWithObject:@""];

		err=U_ZERO_ERROR;
		UEnumeration *enumeration=ucnv_openStandardNames(name,"IANA",&err);
		const char *alias;
		while(alias=uenum_next(enumeration,NULL,&err))
		{
			[encodingarray addObject:[NSString stringWithUTF8String:alias]];
		}
		uenum_close(enumeration);

		if([encodingarray count]==1) [encodingarray addObject:[NSString stringWithUTF8String:name]];

		[array addObject:encodingarray];
	}

	return array;
}

@end
