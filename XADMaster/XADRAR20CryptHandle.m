#import "XADRAR20CryptHandle.h"
#import "CRC.h"

@implementation XADRAR20CryptHandle

-(id)initWithHandle:(CSHandle *)handle password:(NSData *)passdata
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		startoffs=[handle offsetInFile];
		password=[passdata retain];
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[password release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
	[self calculateKey];
	[self setBlockPointer:outblock];
}


static inline void swap(uint8_t *b1,uint8_t *b2) { uint8_t b=*b1; *b1=*b2; *b2=b; }

static inline uint32_t rol(uint32_t x,int n,int xsize) { return (x<<n)|(x>>(xsize-n)); }

static inline int SubstituteBytes(uint8_t *table,uint32_t t)
{
	return (uint32_t)table[t&255]|
	((uint32_t)table[(t>>8)&255]<<8)|
	((uint32_t)table[(t>>16)&255]<<16)|
	((uint32_t)table[(t>>24)&255]<<24);
}

static const uint8_t InitSubstTable[256]=
{
	215, 19,149, 35, 73,197,192,205,249, 28, 16,119, 48,221,  2, 42,
	232,  1,177,233, 14, 88,219, 25,223,195,244, 90, 87,239,153,137,
	255,199,147, 70, 92, 66,246, 13,216, 40, 62, 29,217,230, 86,  6,
	 71, 24,171,196,101,113,218,123, 93, 91,163,178,202, 67, 44,235,
	107,250, 75,234, 49,167,125,211, 83,114,157,144, 32,193,143, 36,
	158,124,247,187, 89,214,141, 47,121,228, 61,130,213,194,174,251,
	 97,110, 54,229,115, 57,152, 94,105,243,212, 55,209,245, 63, 11,
	164,200, 31,156, 81,176,227, 21, 76, 99,139,188,127, 17,248, 51,
	207,120,189,210,  8,226, 41, 72,183,203,135,165,166, 60, 98,  7,
	122, 38,155,170, 69,172,252,238, 39,134, 59,128,236, 27,240, 80,
	131,  3, 85,206,145, 79,154,142,159,220,201,133, 74, 64, 20,129,
	224,185,138,103,173,182, 43, 34,254, 82,198,151,231,180, 58, 10,
	118, 26,102, 12, 50,132, 22,191,136,111,162,179, 45,  4,148,108,
	161, 56, 78,126,242,222, 15,175,146, 23, 33,241,181,190, 77,225,
	  0, 46,169,186, 68, 95,237, 65, 53,208,253,168,  9, 18,100, 52,
	116,184,160, 96,109, 37, 30,106,140,104,150,  5,204,117,112, 84
};

-(void)calculateKey
{
	uint8_t passbuf[128];

	key[0]=0xd3a3b879;
	key[1]=0x3f6d12f7;
	key[2]=0x7515a235;
	key[3]=0xa4e7f123;

	const uint8_t *passbytes=[password bytes];
	int passlength=[password length];
	if(passlength>127) passlength=127;

	memset(passbuf,0,sizeof(passbuf));
	memcpy(passbuf,passbytes,passlength);

	memcpy(table,InitSubstTable,sizeof(table));

	for(int j=0;j<256;j++)
	for(int i=0;i<passlength;i+=2)
	{
		int n1=XADCRCTable_edb88320[(passbuf[i]-j)&0xff]&0xff;
		int n2=XADCRCTable_edb88320[(passbuf[i+1]+j)&0xff]&0xff;
		for(int k=1;n1!=n2;n1=(n1+1)&0xff,k++) swap(&table[n1],&table[(n1+i+k)&0xff]);
	}

	for(int j=0;j<passlength;j+=16)
	{
		uint8_t *block=&passbuf[j];

		uint32_t A=CSUInt32LE(&block[0])^key[0];
		uint32_t B=CSUInt32LE(&block[4])^key[1];
		uint32_t C=CSUInt32LE(&block[8])^key[2];
		uint32_t D=CSUInt32LE(&block[12])^key[3];

		for(int i=0;i<32;i++)
		{
			uint32_t TA=A^SubstituteBytes(table,(C+rol(D,11,32))^key[i&3]);
			uint32_t TB=B^SubstituteBytes(table,(D^rol(C,17,32))+key[i&3]);
			A=C; B=D; C=TA; D=TB;
		}

		CSSetUInt32LE(&block[0],C^key[0]);
		CSSetUInt32LE(&block[4],D^key[1]);
		CSSetUInt32LE(&block[8],A^key[2]);
		CSSetUInt32LE(&block[12],B^key[3]);

		for(int i=0;i<16;i+=4)
		{
			key[0]^=XADCRCTable_edb88320[block[i]];
			key[1]^=XADCRCTable_edb88320[block[i+1]];
			key[2]^=XADCRCTable_edb88320[block[i+2]];
			key[3]^=XADCRCTable_edb88320[block[i+3]];
		}
	}
}

-(int)produceBlockAtOffset:(off_t)pos
{
	uint8_t inblock[16];

	int actual=[parent readAtMost:16 toBuffer:inblock];
	if(actual!=16) return -1;

	uint32_t A=CSUInt32LE(&inblock[0])^key[0];
	uint32_t B=CSUInt32LE(&inblock[4])^key[1];
	uint32_t C=CSUInt32LE(&inblock[8])^key[2];
	uint32_t D=CSUInt32LE(&inblock[12])^key[3];

	for(int i=31;i>=0;i--)
	{
		uint32_t TA=A^SubstituteBytes(table,(C+rol(D,11,32))^key[i&3]);
		uint32_t TB=B^SubstituteBytes(table,(D^rol(C,17,32))+key[i&3]);
		A=C; B=D; C=TA; D=TB;
	}

	CSSetUInt32LE(&outblock[0],C^key[0]);
	CSSetUInt32LE(&outblock[4],D^key[1]);
	CSSetUInt32LE(&outblock[8],A^key[2]);
	CSSetUInt32LE(&outblock[12],B^key[3]);

	for(int i=0;i<16;i+=4)
	{
		key[0]^=XADCRCTable_edb88320[inblock[i]];
		key[1]^=XADCRCTable_edb88320[inblock[i+1]];
		key[2]^=XADCRCTable_edb88320[inblock[i+2]];
		key[3]^=XADCRCTable_edb88320[inblock[i+3]];
	}

	return 16;
}

@end
