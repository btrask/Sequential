#import "XADArchiveParser.h"

@interface XADStuffItXParser:XADArchiveParser
{
	NSMutableDictionary *currstream;
	CSHandle *currstreamhandle;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(void)parseCatalogWithHandle:(CSHandle *)fh entryArray:(NSArray *)entries entryDictionary:(NSDictionary *)dict;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
