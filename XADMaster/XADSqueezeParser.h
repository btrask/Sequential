#import "XADArchiveParser.h"

BOOL IsSqueezeHeader(const uint8_t *bytes,int length);

@interface XADSqueezeParser:XADArchiveParser
{
}

+(NSMutableDictionary *)parseWithHandle:(CSHandle *)fh endOffset:(off_t)end parser:(XADArchiveParser *)parser;
+(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum handle:(CSHandle *)handle;

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

