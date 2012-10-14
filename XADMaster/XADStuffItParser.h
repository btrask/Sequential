#import "XADArchiveParser.h"

@interface XADStuffItParser:XADArchiveParser
{
}

-(void)parse;
-(XADString *)nameOfCompressionMethod:(int)method;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)decryptHandleForEntryWithDictionary:(NSDictionary *)dict handle:(CSHandle *)fh;
-(NSString *)formatName;

@end

