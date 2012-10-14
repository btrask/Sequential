#import "CSBlockStreamHandle.h"

@interface XADStuffItXCyanideHandle:CSBlockStreamHandle
{
	uint8_t *block,*sorted;
	uint32_t *table;
	size_t currsize;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

-(void)readTernaryCodedBlock:(int)blocksize numberOfSymbols:(int)numsymbols;

@end
