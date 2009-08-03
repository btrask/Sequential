#import "CSByteStreamHandle.h"
#import "BWT.h"

typedef struct ArithmeticSymbol
{
	int symbol;
	int frequency;
} ArithmeticSymbol;

typedef struct ArithmeticModel
{
	int totalfrequency;
	int increment;
	int frequencylimit;

	int numsymbols;
	ArithmeticSymbol symbols[128];
} ArithmeticModel;

typedef struct ArithmeticDecoder
{
	CSInputBuffer *input;
	int range,code;
} ArithmeticDecoder;



@interface XADStuffItArsenicHandle:CSByteStreamHandle
{
	ArithmeticModel initialmodel,selectormodel,mtfmodel[7];
	ArithmeticDecoder decoder;
	MTFState mtf;

	int blockbits,blocksize;
	uint8_t *block;
	BOOL endofblocks;

	int numbytes,bytecount,transformindex;
	uint32_t *transform;

	int randomized,randcount,randindex;

	int repeat,count,last;

	uint32_t crc,compcrc;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

//-(void)resetBlockStream;
//-(int)produceBlockAtOffset:(off_t)pos;
-(void)resetByteStream;
-(void)readBlock;
-(uint8_t)produceByteAtOffset:(off_t)pos;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end
