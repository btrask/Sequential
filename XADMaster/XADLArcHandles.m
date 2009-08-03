#import "XADLArcHandles.h"

@implementation XADLArcLZSHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [super initWithHandle:handle length:length windowSize:2048];
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	if(CSInputNextBit(input)) return CSInputNextBitString(input,8);
	else
	{
		*offset=pos-CSInputNextBitString(input,11)-17;
		*length=CSInputNextBitString(input,4)+2; // TODO: 3 or 2?

		return XADLZSSMatch;
	}
}

@end

@implementation XADLArcLZ5Handle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [super initWithHandle:handle length:length windowSize:4096];
}

-(void)resetLZSSHandle
{
	flagbit=7;

	for(int i=0;i<256;i++) memset(&windowbuffer[i*13+18],i,13);
	for(int i=0;i<256;i++) windowbuffer[256*13+18+i]=i;
	for(int i=0;i<256;i++) windowbuffer[256*13+256+18+i]=255-i;
	memset(&windowbuffer[256*13+512+18],0,128);
	memset(&windowbuffer[256*13+512+128+18],' ',128-18);
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	flagbit++;
	if(flagbit>7)
	{
		flagbit=0;
		flags=CSInputNextByte(input);
	}

	int byte=CSInputNextByte(input);

	if(flags&(1<<flagbit)) return byte;
	else
	{
		int byte2=CSInputNextByte(input);

		*offset=pos-byte-((byte2&0xf0)<<4)-18;
		*length=(byte2&0x0f)+3;

		return XADLZSSMatch;
	}
}

@end

