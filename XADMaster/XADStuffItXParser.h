#import "XADArchiveParser.h"
#import "CSMemoryHandle.h"

@interface XADStuffItXParser:XADArchiveParser
{
	NSData *repeatedentrydata;
	NSArray *repeatedentries;
	BOOL repeatedentryhaschecksum,repeatedentryiscorrect;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(void)parseCatalogWithHandle:(CSHandle *)fh entryArray:(NSArray *)entries entryDictionary:(NSDictionary *)dict;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

@interface XADStuffItXRepeatedEntryHandle:CSMemoryHandle
{
	BOOL haschecksum,ischecksumcorrect;
}

-(id)initWithData:(NSData *)data hasChecksum:(BOOL)hascheck isChecksumCorrect:(BOOL)iscorrect;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end
