#import "XADCABBlockHandle.h"
#import "XADPrefixCode.h"

@interface XADMSLZXHandle:XADCABBlockHandle
{
	uint8_t *dictionary;
	int dictionarymask;

	XADPrefixCode *maincode,*lengthcode,*offsetcode;

	int numslots;
	BOOL headerhasbeenread,ispreprocessed;
	int32_t preprocesssize;

	off_t inputpos;

	int blocktype;
	off_t blockend;
	int r0,r1,r2;
	int mainlengths[256+50*8],lengthlengths[249];

	uint8_t outbuffer[32768];
}

-(id)initWithBlockReader:(XADCABBlockReader *)blockreader windowBits:(int)windowbits;
-(void)dealloc;

-(void)resetCABBlockHandle;
-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength;

-(void)readBlockHeaderAtPosition:(off_t)pos;
-(void)readDeltaLengths:(int *)lengths count:(int)count alternateMode:(BOOL)altmode;

@end
