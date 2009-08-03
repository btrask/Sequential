#import "XADLZHParser.h"

@interface XADLZHAmigaSFXParser:XADLZHParser
{
	BOOL lha150r;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
-(void)parse;
-(CSHandle *)handleAtDataOffsetForDictionary:(NSDictionary *)dict;
-(NSString *)formatName;

@end

@interface XADLZHCommodore64SFXParser:XADLZHParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
-(void)parse;
-(NSString *)formatName;

@end

@interface XADLZHSFXParser:XADLZHParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
-(void)parse;
-(NSString *)formatName;

@end
