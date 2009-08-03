#import "XADArchiveParser.h"
#import "CSBlockStreamHandle.h"

#import <openssl/des.h>

@interface XADPackItParser:XADArchiveParser
{
	NSMutableDictionary *currdesc;
	CSHandle *currhandle;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

@interface XADPackItXORHandle:CSBlockStreamHandle
{
	uint8_t key[8],block[8];
}

-(id)initWithHandle:(CSHandle *)handle password:(NSData *)passdata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata;

-(int)produceBlockAtOffset:(off_t)pos;

@end

@interface XADPackItDESHandle:CSBlockStreamHandle
{
	DES_cblock inblock,outblock;
	DES_key_schedule schedule;
}

-(id)initWithHandle:(CSHandle *)handle password:(NSData *)passdata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata;

-(int)produceBlockAtOffset:(off_t)pos;

@end
