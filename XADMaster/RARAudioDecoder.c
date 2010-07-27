#include "RARAudioDecoder.h"

#include <stdint.h>
#include <string.h>

static inline int iabs(int x) { return x<0?-x:x; }

int DecodeRAR20Audio(RAR20AudioState *state,int *channeldelta,int delta)
{
	state->count++;

	state->delta4=state->delta3;
	state->delta3=state->delta2;
	state->delta2=state->lastdelta-state->delta1;
	state->delta1=state->lastdelta;

	int predbyte=((
		8*state->lastbyte+
		state->weight1*state->delta1+
		state->weight2*state->delta2+
		state->weight3*state->delta3+
		state->weight4*state->delta4+
		state->weight5**channeldelta
	)>>3)&0xff;

	int byte=predbyte-delta&0xff;

	int prederror=((int8_t)delta)<<3;
	state->error[0]+=iabs(prederror);
	state->error[1]+=iabs(prederror-state->delta1);
	state->error[2]+=iabs(prederror+state->delta1);
	state->error[3]+=iabs(prederror-state->delta2);
	state->error[4]+=iabs(prederror+state->delta2);
	state->error[5]+=iabs(prederror-state->delta3);
	state->error[6]+=iabs(prederror+state->delta3);
	state->error[7]+=iabs(prederror-state->delta4);
	state->error[8]+=iabs(prederror+state->delta4);
	state->error[9]+=iabs(prederror-*channeldelta);
	state->error[10]+=iabs(prederror+*channeldelta);

	*channeldelta=state->lastdelta=(int8_t)(byte-state->lastbyte);
	state->lastbyte=byte;

	if((state->count&0x1f)==0)
	{
		int minerror=state->error[0];
		int minindex=0;
		for(int i=1;i<11;i++)
		{
			if(state->error[i]<minerror)
			{
				minerror=state->error[i];
				minindex=i;
			}
		}

		memset(state->error,0,sizeof(state->error));

		switch(minindex)
		{
			case 1: if(state->weight1>=-16) state->weight1--; break;
			case 2: if(state->weight1<16) state->weight1++; break;
			case 3: if(state->weight2>=-16) state->weight2--; break;
			case 4: if(state->weight2<16) state->weight2++; break;
			case 5: if(state->weight3>=-16) state->weight3--; break;
			case 6: if(state->weight3<16) state->weight3++; break;
			case 7: if(state->weight4>=-16) state->weight4--; break;
			case 8: if(state->weight4<16) state->weight4++; break;
			case 9: if(state->weight5>=-16) state->weight5--; break;
			case 10: if(state->weight5<16) state->weight5++; break;
		}
	}

	return byte;
}

int DecodeRAR30Audio(RAR30AudioState *state,int delta)
{
	state->delta3=state->delta2;
	state->delta2=state->lastdelta-state->delta1;
	state->delta1=state->lastdelta;

	int predbyte=((
		8*state->lastbyte+
		state->weight1*state->delta1+
		state->weight2*state->delta2+
		state->weight3*state->delta3
	)>>3)&0xff;

	int byte=predbyte-delta&0xff;

	int prederror=((int8_t)delta)<<3;
	state->error[0]+=iabs(prederror);
	state->error[1]+=iabs(prederror-state->delta1);
	state->error[2]+=iabs(prederror+state->delta1);
	state->error[3]+=iabs(prederror-state->delta2);
	state->error[4]+=iabs(prederror+state->delta2);
	state->error[5]+=iabs(prederror-state->delta3);
	state->error[6]+=iabs(prederror+state->delta3);

	state->lastdelta=(int8_t)(byte-state->lastbyte);
	state->lastbyte=byte;

	if((state->count&0x1f)==0)
	{
		int minerror=state->error[0];
		int minindex=0;
		for(int i=1;i<7;i++)
		{
			if(state->error[i]<minerror)
			{
				minerror=state->error[i];
				minindex=i;
			}
		}

		memset(state->error,0,sizeof(state->error));

		switch(minindex)
		{
			case 1: if(state->weight1>=-16) state->weight1--; break;
			case 2: if(state->weight1<16) state->weight1++; break;
			case 3: if(state->weight2>=-16) state->weight2--; break;
			case 4: if(state->weight2<16) state->weight2++; break;
			case 5: if(state->weight3>=-16) state->weight3--; break;
			case 6: if(state->weight3<16) state->weight3++; break;
		}
	}

	state->count++;

	return byte;
}
