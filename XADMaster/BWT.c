#include "BWT.h"

#include <stdlib.h>
#include <string.h>

// Inverse BWT

void CalculateInverseBWT(uint32_t *transform,uint8_t *block,int blocklen)
{
	int counts[256]={0},cumulativecounts[256];
	
	for(int i=0;i<blocklen;i++) counts[block[i]]++;
	
	int total=0;
	for(int i=0;i<256;i++)
	{
		cumulativecounts[i]=total;
		total+=counts[i];
		counts[i]=0;
	}
	
	for(int i=0;i<blocklen;i++)
	{
		transform[cumulativecounts[block[i]]+counts[block[i]]]=i;
		counts[block[i]]++;
	}
}

void UnsortBWT(uint8_t *dest,uint8_t *src,int blocklen,int firstindex,uint32_t *transform)
{
	CalculateInverseBWT(transform,src,blocklen);

	int transformindex=firstindex;
	for(int i=0;i<blocklen;i++)
	{
		transformindex=transform[transformindex];
		dest[i]=src[transformindex];
	}
}

void UnsortST4(uint8_t *dest,uint8_t *src,int blocklen,int firstindex,uint32_t *transform)
{
	int counts[256];
	int array2[256*256];

	for(int i=0;i<256;i++) counts[i]=0;
	for(int i=0;i<256*256;i++) array2[i]=0;

	for(int i=0;i<blocklen;i++) counts[src[i]]++;

	int total=0;
	for(int i=0;i<256;i++)
	{
		int count=counts[i];
		counts[i]=total;

		for(int j=0;j<count;j++) array2[(src[total+j]<<8)|i]++;

		total+=count;
	}

	uint8_t *bitvec=dest;
	memset(bitvec,0,(blocklen+7)/8);

	int array3[256];
	for(int i=0;i<256;i++) array3[i]=-1;

	uint32_t counts2[256];
	memcpy(counts2,counts,sizeof(counts));

	total=0;
	for(int i=0;i<0x10000;i++)
	{
		int count=array2[i];

		for(int j=0;j<count;j++)
		{
			int byte=src[total+j];
			if(array3[byte]!=total)
			{
				array3[byte]=total;
				int x=counts[byte];
				bitvec[x>>3]|=1<<(x&7);
			}
			counts[byte]++;
		}

		total+=count;
	}

	for(int i=0;i<256;i++) array3[i]=0;

	int index=0;
	for(int i=0;i<blocklen;i++)
	{
		if(bitvec[i/8]&(1<<(i&7))) index=i;

		int byte=src[i];
		if(index<array3[byte])
		{
			transform[i]=(array3[byte]-1)|0x800000;
		}
		else
		{
			transform[i]=counts2[byte];
			array3[byte]=i+1;
		}
		counts2[byte]++;
		transform[i]|=byte<<24;
	}

	index=firstindex;
	uint32_t tval=transform[firstindex];

	for(int i=0;i<blocklen;i++)
	{
		if(tval&0x800000)
		{
			index=transform[tval&0x7fffff]&0x7fffff;
			transform[tval&0x7fffff]++;
		}
		else
		{
			transform[index]++;
			index=tval&0x7fffff;
		}

		tval=transform[index];
		dest[i]=tval>>24;
	}
}

/*void UnsortBWTStuffItX(uint8_t *dest,int blocklen,int firstindex,uint8_t *src,uint32_t *transform)
{
	int counts[256]={0};

	for(int i=0;i<blocklen;i++)
	{
		transform[i]=counts[src[i]];
		counts[src[i]]++;
	}

	int total=0;
	for(int i=0;i<256;i++)
	{
		int oldtotal=total;
		total+=counts[i];
		counts[i]=oldtotal;
	}

	int index=firstindex;
	for(int i=blocklen-1;i>=0;i--)
	{
		dest[i]=src[index];
		index=transform[index]+counts[src[index]];
	}
}*/




// MTF Decoder

void ResetMTFDecoder(MTFState *self)
{
	for(int i=0;i<256;i++) self->table[i]=i;
}

int DecodeMTF(MTFState *self,int symbol)
{
	int res=self->table[symbol];
	for(int i=symbol;i>0;i--) self->table[i]=self->table[i-1];
	self->table[0]=res;
	return res;
}

void DecodeMTFBlock(uint8_t *block,int blocklen)
{
	MTFState mtf;
	ResetMTFDecoder(&mtf);
	for(int i=0;i<blocklen;i++) block[i]=DecodeMTF(&mtf,block[i]);
}

void DecodeM1FFNBlock(uint8_t *block,int blocklen,int order)
{
	MTFState mtf;
	ResetMTFDecoder(&mtf);
	int lasthead=order-1;

	for(int i=0;i<blocklen;i++)
	{
		int symbol=block[i];
		block[i]=mtf.table[symbol];

		if(symbol==0)
		{
			lasthead=0;
		}
		else if(symbol==1)
		{
			if(lasthead>=order)
			{
				int val=mtf.table[1];
				mtf.table[1]=mtf.table[0];
				mtf.table[0]=val;
			}
		}
		else
		{
			int val=mtf.table[symbol];
			for(int i=symbol;i>1;i--) mtf.table[i]=mtf.table[i-1];
			mtf.table[1]=val;
		}

		lasthead++;
	}
}
