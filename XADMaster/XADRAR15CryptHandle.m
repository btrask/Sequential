#import "XADRAR15CryptHandle.h"
#import "CRC.h"

static inline uint16_t ror16(uint16_t val,int n) { return (val>>n)|(val<<(16-n)); }

@implementation XADRAR15CryptHandle

-(id)initWithHandle:(CSHandle *)handle password:(NSData *)passdata
{
	if(self=[super initWithHandle:handle])
	{
		password=[passdata retain];
	}
	return self;
}

-(void)dealloc
{
	[password release];
	[super dealloc];
}



-(void)resetByteStream
{
	int passlength=[password length];
	const uint8_t *passbytes=[password bytes];

	uint32_t crc=XADCalculateCRC(0xffffffff,passbytes,passlength,XADCRCTable_edb88320);

	key0=crc;
	key1=crc>>16;
	key2=key3=0;

	for(int i=0;i<passlength;i++)
	{
		uint8_t c=passbytes[i];
		key2^=c^XADCRCTable_edb88320[c];
		key3+=c+(XADCRCTable_edb88320[c]>>16);
	}
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
    key0+=0x1234;
    key1^=XADCRCTable_edb88320[(key0>>1)&0xff];
    key2-=XADCRCTable_edb88320[(key0>>1)&0xff]>>16;
    key0^=key2;
    key3=ror16(key3&0xffff,1)^key1;
    key3=ror16(key3&0xffff,1);
    key0^=key3;

	if(CSInputAtEOF(input)) CSByteStreamEOF(self);

	return CSInputNextByte(input)^(key0>>8);
}

@end
