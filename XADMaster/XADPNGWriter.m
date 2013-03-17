#import "XADPNGWriter.h"
#import "CSHandle.h"
#import "CRC.h"

@implementation XADPNGWriter

+(XADPNGWriter *)PNGWriter { return [[self new] autorelease]; }

-(id)init
{
	if((self=[super init]))
	{
		data=[NSMutableData new];
		[data appendBytes:(uint8_t[8]){0x89,'P','N','G','\r','\n',0x1a,'\n'} length:8];
		streaminited=NO;
	}
	return self;
}

-(void)dealloc
{
	if(streaminited) deflateEnd(&zs);

	[data release];
	[super dealloc];
}

-(NSData *)data { return data; }

-(void)addIHDRWithWidth:(int)width height:(int)height bitDepth:(int)bitdepth
colourType:(int)colourtype 
{
	uint8_t ihdr[13];
	CSSetUInt32BE(&ihdr[0],width);
	CSSetUInt32BE(&ihdr[4],height);
	ihdr[8]=bitdepth;
	ihdr[9]=colourtype;
	ihdr[10]=0;
	ihdr[11]=0;
	ihdr[12]=0;

	int numchannels=0;
	switch(colourtype)
	{
		case 0: numchannels=1; break;
		case 2: numchannels=3; break;
		case 3: numchannels=1; break;
		case 4: numchannels=2; break;
		case 6: numchannels=4; break;
	}

	bytesperrow=(width*bitdepth*numchannels+7)/8;

	[self addChunk:'IHDR' bytes:ihdr length:sizeof(ihdr)];
}

-(void)addIEND
{
	[self addChunk:'IEND' bytes:NULL length:0];
}

-(void)addChunk:(uint32_t)chunktype bytes:(uint8_t *)bytes length:(int)length
{
	uint8_t buf[4];
	uint32_t crc=0xffffffff;

	// Write length.
	CSSetUInt32BE(buf,length);
	[data appendBytes:buf length:4];

	// Write and checksum chunk type.
	CSSetUInt32BE(buf,chunktype);
	[data appendBytes:buf length:4];
	crc=XADCalculateCRC(crc,buf,4,XADCRCTable_edb88320);

	// Write and checksum chunk data, if any.
	if(length)
	{
		[data appendBytes:bytes length:length];
		crc=XADCalculateCRC(crc,bytes,length,XADCRCTable_edb88320);
	}

	// Write checksum.
	CSSetUInt32BE(buf,~crc);
	[data appendBytes:buf length:4];
}

-(void)startIDAT
{
	uint8_t buf[4];

	// Save start offset.
	idatstart=[data length];

	// Write dummy length.
 	CSSetUInt32BE(buf,0);
	[data appendBytes:buf length:4];

	// Write chunk type.
	CSSetUInt32BE(buf,'IDAT');
	[data appendBytes:buf length:4];

	// Initialize compressor.
	memset(&zs,0,sizeof(zs));
	deflateInit(&zs,Z_DEFAULT_COMPRESSION);
	streaminited=YES;
}

-(void)addIDATRow:(uint8_t *)bytes
{
	uint8_t outbuffer[4096];

	zs.avail_in=1;
	zs.next_in=(uint8_t[1]){ 0x00 };
	do
	{
		zs.avail_out=sizeof(outbuffer);
		zs.next_out=outbuffer;

		deflate(&zs,Z_NO_FLUSH);

		int produced=sizeof(outbuffer)-zs.avail_out;
		if(produced) [data appendBytes:outbuffer length:produced];
	}
	while(zs.avail_in);

	zs.avail_in=bytesperrow;
	zs.next_in=bytes;
	do
	{
		zs.avail_out=sizeof(outbuffer);
		zs.next_out=outbuffer;

		deflate(&zs,Z_NO_FLUSH);

		int produced=sizeof(outbuffer)-zs.avail_out;
		if(produced) [data appendBytes:outbuffer length:produced];
	}
	while(zs.avail_in);
}

-(void)endIDAT
{
	uint8_t outbuffer[4096];
	int res;

	zs.avail_in=0;
	do
	{
		zs.avail_out=sizeof(outbuffer);
		zs.next_out=outbuffer;

		res=deflate(&zs,Z_FINISH);

		int produced=sizeof(outbuffer)-zs.avail_out;
		if(produced) [data appendBytes:outbuffer length:produced];
	} while(res==Z_OK);


	deflateEnd(&zs);
	streaminited=NO;

	// Get data pointer to start modifications to the header.
	uint8_t *bytes=[data mutableBytes];

	// Calculate chunk length and write it to the header.
	int length=[data length]-idatstart-8;
	CSSetUInt32BE(&bytes[idatstart],length);

	// Calculate and write chunk checksum.
	uint8_t buf[4];
	uint32_t crc=XADCalculateCRC(0xffffffff,&bytes[idatstart+4],length+4,XADCRCTable_edb88320);
	CSSetUInt32BE(buf,~crc);
	[data appendBytes:buf length:4];
}

@end

