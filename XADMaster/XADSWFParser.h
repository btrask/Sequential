#import "XADArchiveParser.h"
#import "XADSWFTagParser.h"

@interface XADSWFParser:XADArchiveParser
{
	XADSWFTagParser *parser;
	NSMutableArray *dataobjects;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;

-(NSData *)createWAVHeaderForFlags:(int)flags length:(int)length;

-(void)addEntryWithName:(NSString *)name data:(NSData *)data;
-(void)addEntryWithName:(NSString *)name
offset:(off_t)offset length:(off_t)length;
-(void)addEntryWithName:(NSString *)name data:(NSData *)data
offset:(off_t)offset length:(off_t)length;
-(void)addEntryWithName:(NSString *)name losslessFormat:(int)format
width:(int)width height:(int)height alpha:(BOOL)alpha
offset:(off_t)offset length:(off_t)length;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSData *)convertLosslessFormat:(int)format width:(int)width height:(int)height
alpha:(BOOL)alpha handle:(CSHandle *)handle;

-(NSString *)formatName;

@end
