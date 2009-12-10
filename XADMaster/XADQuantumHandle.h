#import "XADCABBlockHandle.h"

typedef struct QuantumCoder
{
	uint16_t CS_L,CS_H,CS_C;
	CSInputBuffer *input;
} QuantumCoder;

typedef struct QuantumModelSymbol
{
	uint16_t symbol;
	uint16_t cumfreq;
} QuantumModelSymbol;

typedef struct QuantumModel
{
	int numsymbols,shiftsleft; 
	QuantumModelSymbol symbols[65];
} QuantumModel;

@interface XADQuantumHandle:XADCABBlockHandle
{
	uint8_t *dictionary;
	int dictionarymask;

	int numslots4,numslots5,numslots6;

	QuantumCoder coder;
	QuantumModel selectormodel;
	QuantumModel literalmodel[4];
	QuantumModel offsetmodel4,offsetmodel5,offsetmodel6;
	QuantumModel lengthmodel6;
}

-(id)initWithBlockReader:(XADCABBlockReader *)blockreader windowBits:(int)windowbits;

-(void)resetCABBlockHandle;
-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength;

@end

