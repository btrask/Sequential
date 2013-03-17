#import "XADArchiveParser.h"

#if MAC_OS_X_VERSION_MAX_ALLOWED>=1060
@interface XADXARParser:XADArchiveParser <NSXMLParserDelegate>
#else
@interface XADXARParser:XADArchiveParser
#endif
{
	off_t heapoffset;
	int state;

	NSDictionary *filedefinitions,*datadefinitions,*eadefinitions;

	NSMutableDictionary *currfile,*currea;
	NSMutableArray *files,*filestack,*curreas;
	NSMutableString *currstring;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;

-(void)finishFile:(NSMutableDictionary *)file parentPath:(XADPath *)parentpath;

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name
namespaceURI:(NSString *)namespace qualifiedName:(NSString *)qname
attributes:(NSDictionary *)attributes;
-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name
namespaceURI:(NSString *)namespace qualifiedName:(NSString *)qname;
-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string;

-(void)startSimpleElement:(NSString *)name attributes:(NSDictionary *)attributes
definitions:(NSDictionary *)definitions destinationDictionary:(NSMutableDictionary *)dest;
-(void)endSimpleElement:(NSString *)name definitions:(NSDictionary *)definitions
destinationDictionary:(NSMutableDictionary *)dest;
-(void)parseDefinition:(NSArray *)definition string:(NSString *)string
destinationDictionary:(NSMutableDictionary *)dest;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)handleForEncodingStyle:(NSString *)encodingstyle offset:(NSNumber *)offset
length:(NSNumber *)length size:(NSNumber *)size checksum:(NSData *)checksum checksumStyle:(NSString *)checksumstyle;

-(NSString *)formatName;

@end
