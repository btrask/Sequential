#import <Foundation/Foundation.h>
#import <zlib.h>

@interface XADPNGWriter:NSObject
{
	NSMutableData *data;
	int bytesperrow;

	z_stream zs;
	BOOL streaminited;

	int idatstart;
}

+(XADPNGWriter *)PNGWriter;

-(id)init;
-(void)dealloc;

-(NSData *)data;

-(void)addIHDRWithWidth:(int)width height:(int)height bitDepth:(int)bitdepth
colourType:(int)colourtype;
-(void)addIEND;
-(void)addChunk:(uint32_t)chunktype bytes:(uint8_t *)bytes length:(int)length;

-(void)startIDAT;
-(void)addIDATRow:(uint8_t *)bytes;
-(void)endIDAT;

@end

