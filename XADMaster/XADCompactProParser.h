#import "XADArchiveParser.h"

@interface XADCompactProParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(BOOL)parseDirectoryWithPath:(XADPath *)parent numberOfEntries:(int)numentries entryArray:(NSMutableArray *)entries;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
