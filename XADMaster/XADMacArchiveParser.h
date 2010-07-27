#import "XADArchiveParser.h"
#import "CSStreamHandle.h"

extern NSString *XADIsMacBinaryKey;
extern NSString *XADMightBeMacBinaryKey;
extern NSString *XADDisableMacForkExpansionKey;

@interface XADMacArchiveParser:XADArchiveParser
{
	CSHandle *currhandle;
	NSMutableDictionary *queuedditto;
	NSMutableArray *dittostack;
	NSMutableData *kludgedata;
}

+(int)macBinaryVersionForHeader:(NSData *)header;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(void)parse;
-(void)parseWithSeparateMacForks;

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos cyclePools:(BOOL)cyclepools;

-(BOOL)parseAppleDoubleWithDictionary:(NSMutableDictionary *)dict name:(XADPath *)name
retainPosition:(BOOL)retainpos cyclePools:(BOOL)cyclepools;
-(void)popDittoStackUntilPrefixFor:(XADPath *)path;
-(void)queueDittoDictionary:(NSMutableDictionary *)dict;
-(void)addQueuedDittoDictionaryAsDirectory:(BOOL)isdir retainPosition:(BOOL)retainpos;

-(BOOL)parseMacBinaryWithDictionary:(NSMutableDictionary *)dict name:(XADPath *)name
retainPosition:(BOOL)retainpos cyclePools:(BOOL)cyclepools;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(void)inspectEntryDictionary:(NSMutableDictionary *)dict;

@end





@interface XADKludgeHandle:CSStreamHandle
{
	CSHandle *parent;
	NSData *header;
}

-(id)initWithHeaderData:(NSData *)headerdata handle:(CSHandle *)handle;
-(void)dealloc;
-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

@end
