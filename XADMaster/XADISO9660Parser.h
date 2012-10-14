#import "XADArchiveParser.h"

@interface XADISO9660Parser:XADArchiveParser
{
	int blocksize;
	BOOL isjoliet,ishighsierra;
	CSHandle *fh;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props;

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name;
-(void)dealloc;

-(void)parse;
-(void)parseVolumeDescriptorAtBlock:(uint32_t)block;
-(void)parseDirectoryWithPath:(XADPath *)path atBlock:(uint32_t)block length:(uint32_t)length;

-(XADString *)readStringOfLength:(int)length;
-(NSDate *)readLongDateAndTime;
-(NSDate *)readShortDateAndTime;
-(NSDate *)parseDateAndTimeWithBytes:(const uint8_t *)buffer long:(BOOL)islong;
-(NSDate *)parseLongDateAndTimeWithBytes:(const uint8_t *)buffer;
-(NSDate *)parseShortDateAndTimeWithBytes:(const uint8_t *)buffer;

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
