#import "XADLZSSHandle.h"
#import "CarrylessRangeCoder.h"

@interface XADStuffItXDarkhorseHandle:XADLZSSHandle
{
	CarrylessRangeCoder coder;

	int next;

	uint32_t flagweights[4],flagweight2;
	uint32_t litweights[16][256],litweights2[16][256][2];
	uint32_t recencyweight1,recencyweight2,recencyweight3,recencyweights[4];
	uint32_t lenweight,shortweights[4][16],longweights[256];
	uint32_t distlenweights[4][64],distweights[10][32],distlowbitweights[16];

	int distancetable[4];
}

-(void)resetLZSSHandle;
-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos;

-(int)readLiteralWithPrevious:(int)prev next:(int)next;
-(int)readLengthWithIndex:(int)index;
-(int)readDistanceWithLength:(int)len;
-(int)readRecencyWithIndex:(int)index;

-(int)readSymbolWithWeights:(uint32_t *)weights numberOfBits:(int)num;

-(void)updateDistanceMemoryWithOldIndex:(int)oldindex distance:(int)distance;

@end
