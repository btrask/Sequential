#import <Foundation/Foundation.h>

#import "NSDictionaryNumberExtension.h"

#import "../CSHandle.h"
#import "../CSByteStreamHandle.h"

#define PDFUnsupportedImageType 0
#define PDFIndexedImageType 1
#define PDFGrayImageType 2
#define PDFRGBImageType 3
#define PDFCMYKImageType 4
#define PDFLabImageType 5
#define PDFSeparationImageType 6
#define PDFMaskImageType 7

@class PDFParser,PDFObjectReference;

@interface PDFStream:NSObject
{
	NSDictionary *dict;
	CSHandle *fh;
	off_t offs;
	PDFObjectReference *ref;
	PDFParser *parser;
}

-(id)initWithDictionary:(NSDictionary *)dictionary fileHandle:(CSHandle *)filehandle
offset:(off_t)offset reference:(PDFObjectReference *)reference parser:(PDFParser *)owner;
-(void)dealloc;

-(NSDictionary *)dictionary;
-(PDFObjectReference *)reference;

-(BOOL)isImage;
-(BOOL)isJPEGImage;
-(BOOL)isJPEG2000Image;

-(int)imageWidth;
-(int)imageHeight;
-(int)imageBitsPerComponent;

-(int)imageType;
-(int)numberOfImageComponents;
-(NSString *)imageColourSpaceName;

-(int)imagePaletteType;
-(int)numberOfImagePaletteComponents;
-(NSString *)imagePaletteColourSpaceName;
-(int)numberOfImagePaletteColours;
-(NSData *)imagePaletteData;
-(id)_paletteColourSpaceObject;

-(int)_typeForColourSpaceObject:(id)colourspace;
-(int)_numberOfComponentsForColourSpaceObject:(id)colourspace;
-(NSString *)_nameForColourSpaceObject:(id)colourspace;

-(NSData *)imageICCColourProfile;
-(NSData *)_ICCColourProfileForColourSpaceObject:(id)colourspace;

-(NSString *)imageSeparationName;
-(NSArray *)imageDecodeArray;

-(BOOL)hasMultipleFilters;
-(NSString *)finalFilter;

-(CSHandle *)rawHandle;
-(CSHandle *)handle;
-(CSHandle *)JPEGHandle;
-(CSHandle *)handleExcludingLast:(BOOL)excludelast;
-(CSHandle *)handleExcludingLast:(BOOL)excludelast decrypted:(BOOL)decrypted;
-(CSHandle *)handleForFilterName:(NSString *)filtername decodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent;
-(CSHandle *)predictorHandleForDecodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent;

-(NSString *)description;

@end

@interface PDFASCII85Handle:CSByteStreamHandle
{
	uint32_t val;
	BOOL finalbytes;
}

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface PDFHexHandle:CSByteStreamHandle
{
}

-(uint8_t)produceByteAtOffset:(off_t)pos;

@end




@interface PDFTIFFPredictorHandle:CSByteStreamHandle
{
	int cols,comps,bpc;
	int prev[4];
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

@interface PDFPNGPredictorHandle:CSByteStreamHandle
{
	int cols,comps,bpc;
	uint8_t *prevbuf;
	int type;
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp;
-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end

