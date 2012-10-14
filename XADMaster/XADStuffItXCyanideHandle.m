#import "XADStuffItXCyanideHandle.h"
#import "XADException.h"
#import "CarrylessRangeCoder.h"
#import "BWT.h"



@implementation XADStuffItXCyanideHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithHandle:handle length:length]))
	{
		block=NULL;
		currsize=0;
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
	/*int something=*/CSInputNextByte(input);
}

-(int)produceBlockAtOffset:(off_t)pos
{
	int marker=CSInputNextByte(input);
	if(marker==0xff) return 0;
	else if(marker!=0x77) [XADException raiseIllegalDataException];

	uint32_t blocksize=CSInputNextUInt32BE(input);
	uint32_t firstindex=CSInputNextUInt32BE(input);
	int numsymbols=CSInputNextByte(input);

	if(blocksize>currsize)
	{
		free(block);
		block=malloc(blocksize*6);
		sorted=block+blocksize;
		table=(uint32_t *)(block+2*blocksize);
		currsize=blocksize;
	}

	[self readTernaryCodedBlock:blocksize numberOfSymbols:numsymbols];

	DecodeM1FFNBlock(sorted,blocksize,2);
	UnsortBWT(block,sorted,blocksize,firstindex,table);

	[self setBlockPointer:block];
	return blocksize;
}

static void CalculateTernaryFrequencies(uint32_t *outfreqs,uint32_t *meanings,uint32_t *infreqs)
{
	uint32_t a=infreqs[0],b=infreqs[1],c=infreqs[2];

	if(a<b)
	{
		if(a<c)
		{
			if(b<c) { meanings[0]=0; meanings[1]=1; meanings[2]=2; }
			else { meanings[0]=0; meanings[1]=2; meanings[2]=1; }
		}
		else { meanings[0]=2; meanings[1]=0; meanings[2]=1; }
	}
	else
	{
		if(b<c)
		{
			if(c<a) { meanings[0]=1; meanings[1]=2; meanings[2]=0; }
			else { meanings[0]=1; meanings[1]=0; meanings[2]=2; }
		}
		else { meanings[0]=2; meanings[1]=1; meanings[2]=0; }
	}

	outfreqs[0]=infreqs[meanings[0]]+1;
	outfreqs[1]=infreqs[meanings[1]]+1;
	outfreqs[2]=infreqs[meanings[2]]+1;
}


typedef struct RangeCoderModel
{
	int num;
	uint32_t frequencies[256],mapping[256];
} RangeCoderModel;



static void InitializeRangeCoderModel(RangeCoderModel *model,int numsymbols)
{
	model->num=numsymbols;
	for(int i=0;i<numsymbols;i++)
	{
		model->frequencies[i]=1;
		model->mapping[i]=numsymbols-1-i;
	}
}

static int BumpFrequencyInModel(int index,RangeCoderModel *model,int maxtotal)
{
	uint32_t total=0;
	for(int i=0;i<model->num;i++) total+=model->frequencies[i];

	if(total>=maxtotal)
	for(int i=0;i<model->num;i++) model->frequencies[i]=(model->frequencies[i]+1)/2;

	int freq=model->frequencies[index];
	int last=index;
	while(last<model->num-1&&model->frequencies[last+1]==freq) last++;
	if(last!=index)
	{
		int tmp=model->mapping[index];
		model->mapping[index]=model->mapping[last];
		model->mapping[last]=tmp;
	}
	model->frequencies[last]++;
	return last;
}

static int NextIndexFromRangeCoderWithModel(CarrylessRangeCoder *coder,RangeCoderModel *model)
{
	return NextSymbolFromRangeCoder(coder,model->frequencies,model->num);
}

static int DecodeSymbolForModel(RangeCoderModel *model,int index)
{
	return model->mapping[index];
}



-(void)readTernaryCodedBlock:(int)blocksize numberOfSymbols:(int)numsymbols
{
	static int markovgroups[27]={0,1,2,3,4,5,6,7,8,3,9,10,3,4,5,11,11,8,6,2,5,6,7,8,12,12,13};

	CarrylessRangeCoder coder;
	InitializeRangeCoder(&coder,input,YES,0x10000);

	uint32_t markovfreqs[14][3]={0};

	RangeCoderModel lowbitsmodels[8];

	int b=numsymbols;
	int shift=1;
	while(b)
	{
		int n=1<<shift;
		if(b<(3<<shift)) n=b;

		InitializeRangeCoderModel(&lowbitsmodels[shift-1],n);

		b-=n;
		shift++;
	}

	RangeCoderModel highbitmodel;
	InitializeRangeCoderModel(&highbitmodel,shift);

	int prev=0,prev2=0,prev3=0;
	int someflag=1;

	for(int i=0;i<blocksize;i++)
	{
		int contextindex=prev3*9+prev2*3+prev;
		int markovindex=markovgroups[contextindex];

		uint32_t freqs[3],meanings[3];
		CalculateTernaryFrequencies(freqs,meanings,markovfreqs[markovindex]);
		int symbol=NextSymbolFromRangeCoder(&coder,freqs,3);
		int tresym=meanings[symbol];

		if(tresym==0&&someflag==0&&markovindex==0)
		{
			someflag=1;
			markovfreqs[markovindex][0]>>=1;
			markovfreqs[markovindex][1]>>=1;
			markovfreqs[markovindex][2]>>=1;
			markovfreqs[markovindex][0]+=3;

			sorted[i]=0;
		}
		else
		{
			if(tresym!=0) someflag=0;

			uint32_t total=freqs[0]+freqs[1]+freqs[2];

			uint32_t limit;
			if(someflag) limit=4096;
			else limit=128;

			if(total>limit)
			{
				markovfreqs[markovindex][0]>>=1;
				markovfreqs[markovindex][1]>>=1;
				markovfreqs[markovindex][2]>>=1;
			}
			markovfreqs[markovindex][tresym]+=2;

			if(tresym<=1) sorted[i]=tresym;
			else
			{
				int highbitindex=NextIndexFromRangeCoderWithModel(&coder,&highbitmodel);
				int highbit=DecodeSymbolForModel(&highbitmodel,highbitindex);
				int newindex=BumpFrequencyInModel(highbitindex,&highbitmodel,0x100);
				BumpFrequencyInModel(newindex,&highbitmodel,0x10000);

				if(highbit==0) sorted[i]=2;
				else
				{
					RangeCoderModel *lowbitsmodel=&lowbitsmodels[highbit-1];

					int lowbitsindex=NextIndexFromRangeCoderWithModel(&coder,lowbitsmodel);
					int lowbits=DecodeSymbolForModel(lowbitsmodel,lowbitsindex);

					int max=lowbitsmodel->num*128;
					if(max>0x4000) max=0x4000;
					BumpFrequencyInModel(lowbitsindex,lowbitsmodel,max);

					sorted[i]=(1<<highbit)+lowbits+1;
				}
			}
		}
		prev3=prev2;
		prev2=prev;
		prev=tresym;
	}
}

@end
