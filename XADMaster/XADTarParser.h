#import "XADMacArchiveParser.h"
#import "XADTarSparseHandle.h"

// TODO later: Multivolume tar.

@interface XADTarParser:XADMacArchiveParser
{
	NSData *currentGlobalHeader;
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;

-(void)parseWithSeparateMacForks;
-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(NSString *)formatName;

@end
