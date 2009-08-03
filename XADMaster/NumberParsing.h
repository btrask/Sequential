#import "CSHandle.h"

int64_t ParseNumberWithBase(const char *num,int length,int base);
int64_t ParseDecimalNumber(const char *num,int length);
int64_t ParseHexadecimalNumber(const char *num,int length);
int64_t ParseOctalNumber(const char *num,int length);

@interface CSHandle (NumberParsing)

-(int64_t)readDecimalNumberWithDigits:(int)numdigits;
-(int64_t)readHexadecimalNumberWithDigits:(int)numdigits;
-(int64_t)readOctalNumberWithDigits:(int)numdigits;

@end
