#import "XADStuffItXDarkhorseHandle.h"
#import "XADException.h"

static int NextBitWithWeight(CarrylessRangeCoder *coder,uint32_t *weight)
{
	int bit=NextWeightedBitFromRangeCoder2(coder,*weight,12);
	if(bit==0) *weight+=(0x1000-*weight)>>5;
	else *weight-=*weight>>5;
	return bit;
}

@implementation XADStuffItXDarkhorseHandle

-(void)resetLZSSHandle
{
	next=-1;

	for(int i=0;i<4;i++) flagweights[i]=0x800;
	flagweight2=0x800;

	for(int i=0;i<16;i++)
	for(int j=0;j<256;j++)
	{
		litweights[i][j]=0x800;
		litweights2[i][j][0]=0x800;
		litweights2[i][j][1]=0x800;
	}

	recencyweight1=recencyweight2=recencyweight3=0x800;
	for(int i=0;i<4;i++) recencyweights[i]=0x800;

	lenweight=0x800;

	for(int i=0;i<4;i++)
	for(int j=0;j<16;j++)
	shortweights[i][j]=0x800;

	for(int i=0;i<256;i++) longweights[i]=0x800;

	for(int i=0;i<4;i++)
	for(int j=0;j<64;j++)
	distlenweights[i][j]=0x800;

	for(int i=0;i<10;i++)
	for(int j=0;j<32;j++)
	distweights[i][j]=0x800;

	for(int i=0;i<16;i++) distlowbitweights[i]=0x800;

	for(int i=0;i<4;i++) distancetable[i]=0;

	CSInputSkipBytes(input,1);
	InitializeRangeCoder(&coder,input,NO,0);
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	if(NextBitWithWeight(&coder,&flagweights[pos&3])==0)
	{
		int byte=[self readLiteralWithPrevious:XADLZSSByteFromWindow(self,pos-1) next:next];
		next=-1;

		return byte;
	}
	else
	{

		int len,offs;
		if(NextBitWithWeight(&coder,&flagweight2)==0)
		{
			len=[self readLengthWithIndex:pos&3]+2;
			if(len==0x111) return XADLZSSEnd;
			offs=[self readDistanceWithLength:len];
			[self updateDistanceMemoryWithOldIndex:3 distance:offs];
		}
		else
		{
			int recency=[self readRecencyWithIndex:pos&3];
			if(recency==-1)
			{
				offs=distancetable[0];
				len=1;
			}
			else
			{
				offs=distancetable[recency];
				[self updateDistanceMemoryWithOldIndex:recency distance:offs];
				len=[self readLengthWithIndex:pos&3]+2;
			}
		}

		*offset=offs+1;
		*length=len;

		next=XADLZSSByteFromWindow(self,pos-offs-1+len%(offs+1));

		return XADLZSSMatch;
	}
}

-(int)readLiteralWithPrevious:(int)prev next:(int)guess
{
	int val=1;
	if(guess==-1)
	{
		while(val<0x100)
		{
			val=(val<<1)|NextBitWithWeight(&coder,&litweights[prev/16][val]);
		}
	}
	else
	{
		while(val<0x100)
		{
			int bit=NextBitWithWeight(&coder,&litweights2[prev/16][val][(guess>>7)&1]);
			val=(val<<1)|bit;

			if(bit!=((guess>>7)&1)) break;
			guess<<=1;
		}
		while(val<0x100)
		{
			val=(val<<1)|NextBitWithWeight(&coder,&litweights[prev/16][val]);
		}
	}
	return val&0xff;
}

-(int)readLengthWithIndex:(int)index
{
	if(NextBitWithWeight(&coder,&lenweight)==0)
	{
		return [self readSymbolWithWeights:shortweights[index] numberOfBits:4];
	}
	else
	{
		return [self readSymbolWithWeights:longweights numberOfBits:8]+16;
	}
}

-(int)readDistanceWithLength:(int)len
{
	static int offsettable[64]=
	{
		0,1,2,3,4,6,8,0xc,
		0x10,0x18,0x20,0x30,0x40,0x60,0x80,0xc0,
		0x100,0x180,0x200,0x300,0x400,0x600,0x800,0xc00,
		0x1000,0x1800,0x2000,0x3000,0x4000,0x6000,0x8000,0xc000,
		0x10000,0x18000,0x20000,0x30000,0x40000,0x60000,0x80000,0xc0000,
		0x100000,0x180000,0x200000,0x300000,0x400000,0x600000,0x800000,0xc00000,
		0x1000000,0x1800000,0x2000000,0x3000000,0x4000000,0x6000000,0x8000000,0xc000000,
		0x10000000,0x18000000,0x20000000,0x30000000,0,0,0,0,
	};
	static int bitlengthtable[64]=
	{
		0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,
		10,10,11,11,12,12,13,13,14,14,15,15,16,16,17,17,18,18,19,19,
		20,20,21,21,22,22,23,23,24,24,25,25,26,26,27,27,28,28,0,0,0,0
	};

	len-=2;
	if(len>3) len=3;

	int sym=[self readSymbolWithWeights:distlenweights[len] numberOfBits:6];

	if(sym<4) return sym;
	else if(sym<14)
	{
		return offsettable[sym]+[self readSymbolWithWeights:distweights[sym-4] numberOfBits:bitlengthtable[sym]];
	}
	else
	{
		int numbits=bitlengthtable[sym];
		int val=0;
		for(int i=numbits-1;i>=4;i--) val|=NextBitFromRangeCoder(&coder)<<i;
		return val+offsettable[sym]+[self readSymbolWithWeights:distlowbitweights numberOfBits:4];
	}
}

-(int)readRecencyWithIndex:(int)index
{
	if(NextBitWithWeight(&coder,&recencyweight1)==0)
	{
		if(NextBitWithWeight(&coder,&recencyweights[index])==0) return -1;
		else return 0;
	}
	else
	{
		if(NextBitWithWeight(&coder,&recencyweight2)==0) return 1;
		else if(NextBitWithWeight(&coder,&recencyweight3)==0) return 2;
		else return 3;
	}
}

-(int)readSymbolWithWeights:(uint32_t *)weights numberOfBits:(int)num
{
	int val=1;
	for(int i=0;i<num;i++) val=(val<<1)|NextBitWithWeight(&coder,&weights[val]);
	return val-(1<<num);
}

-(void)updateDistanceMemoryWithOldIndex:(int)oldindex distance:(int)distance
{
	for(int i=oldindex;i>0;i--) distancetable[i]=distancetable[i-1];
	distancetable[0]=distance;
}

@end

