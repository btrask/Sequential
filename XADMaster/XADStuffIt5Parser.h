#import "XADStuffItParser.h"

@interface XADStuffIt5Parser:XADStuffItParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
-(void)parse;
-(void)parseDirectoryWithNumberOfEntries:(int)numentries parent:(XADPath *)parent;
-(NSString *)formatName;

@end

@interface XADStuffIt5ExeParser:XADStuffIt5Parser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
-(void)parse;

@end

