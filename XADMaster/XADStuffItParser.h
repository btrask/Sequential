#import "XADArchiveParser.h"

@interface XADStuffItParser:XADArchiveParser
{
}

-(void)parse;
-(XADString *)nameOfCompressionMethod:(int)method;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

