#import "XADArchiveParser.h"
#import "CSStreamHandle.h"

@interface XADGzipParser:XADArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end

@interface XADGzipSFXParser:XADGzipParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parse;
-(NSString *)formatName;

@end

@interface XADGzipHandle:CSStreamHandle
{
	CSHandle *parent,*currhandle;
	off_t startoffs;
	int state;
	BOOL checksumscorrect;
	uint32_t crc;
}

-(id)initWithHandle:(CSHandle *)handle;
-(void)dealloc;
-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;
-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;
-(double)estimatedProgress;

@end
