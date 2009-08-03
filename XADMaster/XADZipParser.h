#import "XADMacArchiveParser.h"

@interface XADZipParser:XADMacArchiveParser
{
}

+(int)requiredHeaderSize;
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
+(XADRegex *)volumeRegexForFilename:(NSString *)filename;
+(BOOL)isFirstVolume:(NSString *)filename;

-(void)parse;
-(void)findCentralDirectory;
//-(void)findNextZipMarkerStartingAt:(off_t)startpos;
//-(void)findNoSeekMarkerForDictionary:(NSMutableDictionary *)dict;
-(void)parseZipExtraWithDictionary:(NSMutableDictionary *)dict length:(int)length;

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum;
-(CSHandle *)decompressionHandleWithHandle:(CSHandle *)parent method:(int)method flags:(int)flags size:(off_t)size;

-(NSString *)formatName;

@end
