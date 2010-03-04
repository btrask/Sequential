#import "XADLZSSHandle.h"
#import "XADPrefixCode.h"

@interface XADDiskDoublerDDnHandle:XADLZSSHandle
{
	int blocksize;
	off_t blockend;
	int literalsleft;

	int correctxor;

	XADPrefixCode *lengthcode;

	uint8_t buffer[0x10000];
	uint8_t *literalptr;
	uint16_t *offsetptr;
	off_t nextblock;

	BOOL checksumcorrect,uncompressed;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offsetptr andLength:(int *)lengthptr atPosition:(off_t)pos;
-(void)readBlockAtPosition:(off_t)pos;
-(XADPrefixCode *)readCode;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end
