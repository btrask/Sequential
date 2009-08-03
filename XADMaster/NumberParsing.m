#import "NumberParsing.h"

int64_t ParseNumberWithBase(const char *num,int length,int base)
{
	char cstr[length+1];
	memcpy(cstr,num,length);
	cstr[length]=0;
	return strtoll(cstr,NULL,base);
}

int64_t ParseDecimalNumber(const char *num,int length)
{
	return ParseNumberWithBase(num,length,10);
}

int64_t ParseHexadecimalNumber(const char *num,int length)
{
	return ParseNumberWithBase(num,length,16);
}

int64_t ParseOctalNumber(const char *num,int length)
{
	return ParseNumberWithBase(num,length,8);
}

@implementation CSHandle (NumberParsing)

-(int64_t)readDecimalNumberWithDigits:(int)numdigits
{
	char buf[numdigits];
	[self readBytes:numdigits toBuffer:buf];
	return ParseDecimalNumber(buf,numdigits);
}

-(int64_t)readHexadecimalNumberWithDigits:(int)numdigits
{
	char buf[numdigits];
	[self readBytes:numdigits toBuffer:buf];
	return ParseHexadecimalNumber(buf,numdigits);
}

-(int64_t)readOctalNumberWithDigits:(int)numdigits
{
	char buf[numdigits];
	[self readBytes:numdigits toBuffer:buf];
	return ParseOctalNumber(buf,numdigits);
}

@end
