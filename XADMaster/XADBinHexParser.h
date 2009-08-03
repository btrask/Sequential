#import "XADArchiveParser.h"
#import "CSByteStreamHandle.h"

@interface XADBinHexParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end



@interface XADBinHexHandle:CSByteStreamHandle
{
	uint32_t bytes;
	uint8_t prev_bits;
	int rle_byte,rle_num;
}

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
