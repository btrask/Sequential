#import "XADArchiveParser.h"
#import "XADRegex.h"

extern NSString *XADIsMacBinaryKey;
extern NSString *XADMightBeMacBinaryKey;
extern NSString *XADDisableMacForkExpansionKey;

@interface XADMacArchiveParser:XADArchiveParser
{
	CSHandle *currhandle;
	NSMutableArray *dittostack;
}

+(int)macBinaryVersionForHeader:(NSData *)header;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos;
-(BOOL)parseAppleDoubleWithDictionary:(NSMutableDictionary *)dict name:(XADPath *)name;
-(BOOL)parseMacBinaryWithDictionary:(NSMutableDictionary *)dict name:(XADPath *)name;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(void)inspectEntryDictionary:(NSMutableDictionary *)dict;

@end
