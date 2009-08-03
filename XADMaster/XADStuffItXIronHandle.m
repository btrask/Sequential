#import "XADStuffItXIronHandle.h"
#import "XADException.h"
#import "StuffItXUtilities.h"
#import "CarrylessRangeCoder.h"
#import "BWT.h"
#import "SystemSpecific.h"



static int NextBitWithWeight(CarrylessRangeCoder *coder,uint32_t *weight,int shift)
{
	int bit=NextWeightedBitFromRangeCoder(coder,*weight,0x1000);
	if(bit==0) *weight+=(0x1000-*weight)>>shift;
	else *weight-=*weight>>shift;
	return bit;
}

static int NextBitWithDoubleWeights(CarrylessRangeCoder *coder,uint32_t *weight1,int shift1,uint32_t *weight2,int shift2)
{
	int bit=NextWeightedBitFromRangeCoder(coder,(*weight1+*weight2)/2,0x1000);
	if(bit==0)
	{
		*weight1+=(0x1000-*weight1)>>shift1;
		*weight2+=(0x1000-*weight2)>>shift2;
	}
	else
	{
		*weight1-=*weight1>>shift1;
		*weight2-=*weight2>>shift2;
	}
	return bit;
}



@implementation XADStuffItXIronHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if(self=[super initWithHandle:handle length:length])
	{
		block=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(block);
	[super dealloc];
}

-(void)resetBlockStream
{
	st4transform=CSInputNextBitLE(input);
	fancymtf=CSInputNextBitLE(input);

	maxfreq1=1<<CSInputNextSitxP2(input);
	maxfreq2=1<<CSInputNextSitxP2(input);
	maxfreq3=1<<CSInputNextSitxP2(input);

	byteshift1=CSInputNextSitxP2(input);
	byteshift2=CSInputNextSitxP2(input);
	byteshift3=CSInputNextSitxP2(input);
	countshift1=CSInputNextSitxP2(input);
	countshift2=CSInputNextSitxP2(input);
	countshift3=CSInputNextSitxP2(input);
}

-(int)produceBlockAtOffset:(off_t)pos
{
	CSInputSkipToByteBoundary(input);

	if(CSInputNextBitLE(input)==1) return -1;

	int blocksize=CSInputNextSitxP2(input);

	// TODO: maybe avoid copying memory?
	block=reallocf(block,blocksize*6);
	sorted=block+blocksize;
	table=(uint32_t *)(block+2*blocksize);

	if(CSInputNextBitLE(input)==0) // compressed
	{
		int firstindex=CSInputNextSitxP2(input);

		CSInputSkipToByteBoundary(input);

		[self decodeBlockWithLength:blocksize];

		if(st4transform)
		{
			UnsortST4(block,sorted,blocksize,firstindex,table);
		}
		else
		{
			UnsortBWT(block,sorted,blocksize,firstindex,table);
		}
	}
	else // uncompressed
	{
		CSInputSkipToByteBoundary(input); // necessary?
		for(int i=0;i<blocksize;i++) block[i]=CSInputNextByte(input);
	}

	[self setBlockPointer:block];
	return blocksize;
}

-(void)decodeBlockWithLength:(int)blocksize
{
	uint32_t mainfrequencies[4];
	uint32_t lastbytefrequencies[256][4];
	uint32_t somethingfrequencies[4][256][4];

	uint32_t bytelengthweights[8];
	uint32_t bytelengthweights2[8][8];
	uint32_t bytebitweights[8][128];

	uint32_t countlengthweights[4][16][24];
	uint32_t countlengthweights2[256][24];
	uint32_t countbitweights[24][24];

	uint8_t mtfbuffer[256];
	uint32_t numbytes;
	uint32_t intarray1[257];
	uint32_t intarray2[257];
	uint32_t intarray3[257];

	for(int i=0;i<4;i++) mainfrequencies[i]=1;

	for(int i=0;i<256;i++)
	for(int j=0;j<4;j++) lastbytefrequencies[i][j]=0;

	for(int i=0;i<4;i++)
	for(int j=0;j<256;j++)
	for(int k=0;k<4;k++) somethingfrequencies[i][j][k]=0;

	for(int i=0;i<8;i++) bytelengthweights[i]=0x800;

	for(int i=0;i<8;i++)
	for(int j=0;j<8;j++) bytelengthweights2[i][j]=0x800;

	for(int i=0;i<8;i++)
	for(int j=0;j<128;j++) bytebitweights[i][j]=0x800;

	for(int i=0;i<4;i++)
	for(int j=0;j<16;j++)
	for(int k=0;k<24;k++) countlengthweights[i][j][k]=0x800;

	for(int i=0;i<256;i++)
	for(int j=0;j<24;j++) countlengthweights2[i][j]=0x800;

	for(int i=0;i<24;i++)
	for(int j=0;j<24;j++) countbitweights[i][j]=0x800;

	if(fancymtf)
	{
		for(int i=0;i<257;i++)
		{
			intarray1[i]=i;
			intarray2[i]=i;
			intarray3[i]=0;
		}
		intarray3[256]=-1; // unnecessary?

		numbytes=0;
	}
	else
	{
		for(int i=0;i<256;i++) mtfbuffer[i]=i;
	}



	CarrylessRangeCoder coder;

	CSInputSkipBytes(input,1);
	InitializeRangeCoder(&coder,input,NO,0);

	int valuehistory=0,lengthhistory=0,lastbits=0,lastbyte=0;

	for(int i=0;i<blocksize;)
	{
		uint32_t *freqs1=mainfrequencies;
		uint32_t *freqs2=lastbytefrequencies[lastbyte];
		uint32_t *freqs3=somethingfrequencies[lengthhistory&3][valuehistory];
		uint32_t frequencies[4];
		for(int j=0;j<4;j++) frequencies[j]=freqs1[j]+freqs2[j]+freqs3[j];

		int symbol=NextSymbolFromRangeCoder(&coder,frequencies,4);

		freqs1[symbol]+=2;
		freqs2[symbol]+=2;
		freqs3[symbol]+=2;

		uint32_t total1=0,total2=0,total3=0;
		for(int j=0;j<4;j++)
		{
			total1+=freqs1[j];
			total2+=freqs2[j];
			total3+=freqs3[j];
		}

		if(total1>maxfreq1) for(int j=0;j<4;j++) freqs1[j]=(freqs1[j]+1)/2;
		if(total2>maxfreq2) for(int j=0;j<4;j++) freqs2[j]/=2;
		if(total3>maxfreq3) for(int j=0;j<4;j++) freqs3[j]/=2;

		int value;
		if(symbol!=3) value=symbol;
		else
		{
			int bits=0;
			while(bits<6)
			{
				int bit=NextBitWithDoubleWeights(&coder,
				&bytelengthweights[bits],byteshift1,
				&bytelengthweights2[lastbits][bits],byteshift2);
				if(bit==0) break;
				bits++;
			}

			value=1;
			for(int j=0;j<=bits;j++)
			{
				int bit=NextBitWithWeight(&coder,&bytebitweights[bits][value],byteshift3);
				value=(value<<1)|bit;
			}
			value++;

			lastbits=bits;
		}

		int byte;
		if(fancymtf)
		{
			int index=(value+1)&0xff;

			byte=intarray1[index]&0xff;
			block[numbytes]=byte;

			intarray3[byte]+=0x4000;

			for(int i=intarray2[byte];i>0;i--)
			{
				intarray1[i]=intarray1[i-1];
				intarray2[intarray1[i-1]]=i;
			}

			intarray1[0]=byte;
			intarray2[byte]=0;

			for(int j=0;j<12;j++)
			{
				int n=1<<j;
				if(n<=numbytes)
				{
					int b2=block[numbytes-n];

					if(j==0) intarray3[b2]-=0x3801;
					else intarray3[b2]-=0x800>>j;

					if(b2!=byte)
					{
						uint32_t val=intarray2[b2];
						while(intarray3[intarray1[val+1]]>intarray3[b2])
						{
							intarray1[val]=intarray1[val+1];
							intarray2[intarray1[val+1]]=val;
							val++;
						}
						intarray1[val]=b2;
						intarray2[b2]=val;
					}
				}
			}

			numbytes++;
		}
		else
		{
			int index=(value+1)&0xff;
			byte=mtfbuffer[index];
			memmove(mtfbuffer+1,mtfbuffer,index);
			mtfbuffer[0]=byte;
		}

		int shortvalue;
		if(value<=3) shortvalue=value;
		else shortvalue=3;

		int bits=0;
		for(;;)
		{
			int bit=NextBitWithDoubleWeights(&coder,
			&countlengthweights[shortvalue][lengthhistory][bits],countshift1,
			&countlengthweights2[byte][bits],countshift2);
			if(bit==0) break;

			bits++;
			if(bits>=24) [XADException raiseIllegalDataException];
		}

		int count=1;
		for(int j=0;j<bits;j++)
		{
			int bit=NextBitWithWeight(&coder,&countbitweights[bits][j],countshift3);
			count=(count<<1)|bit;
		}

		for(int j=0;j<count;j++)
		{
			if(i>=blocksize) [XADException raiseIllegalDataException];
			sorted[i++]=byte;
		}

		valuehistory=((valuehistory<<2)|shortvalue)&0xff;

		lengthhistory=((lengthhistory<<1)&0x0e);
		if(bits>1) lengthhistory|=1;

		lastbyte=byte;
	}
}

@end
