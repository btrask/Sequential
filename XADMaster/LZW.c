#include "LZW.h"
#include <stdlib.h>

LZW *AllocLZW(int maxsymbols,int reservedsymbols)
{
	LZW *self=(LZW *)malloc(sizeof(LZW)+sizeof(LZWTreeNode)*maxsymbols);
	if(!self) return 0;

	self->nodes=(LZWTreeNode *)&self[1];
	self->maxsymbols=maxsymbols;
	self->reservedsymbols=reservedsymbols;

	for(int i=0;i<256;i++)
	{
		self->nodes[i].chr=i;
		self->nodes[i].parent=-1;
	}

	ClearLZWTable(self);

	return self;
}

void FreeLZW(LZW *self)
{
	free(self);
}

void ClearLZWTable(LZW *self)
{
	self->numsymbols=256+self->reservedsymbols;
	self->prevsymbol=-1;
}

static uint8_t FindFirstByte(LZWTreeNode *nodes,int symbol)
{
	while(nodes[symbol].parent>=0) symbol=nodes[symbol].parent;
	return nodes[symbol].chr;
}

int NextLZWSymbol(LZW *self,int symbol)
{
	if(self->prevsymbol<0)
	{
		if(symbol>=256+self->reservedsymbols) return LZWInvalidCodeError;
		self->prevsymbol=symbol;
	}
	else
	{
		int postfixbyte;
		if(symbol<self->numsymbols) postfixbyte=FindFirstByte(self->nodes,symbol);
		else if(symbol==self->numsymbols) postfixbyte=FindFirstByte(self->nodes,self->prevsymbol);
		else return LZWInvalidCodeError;

		if(self->numsymbols<self->maxsymbols)
		{
			self->nodes[self->numsymbols].parent=self->prevsymbol;
			self->nodes[self->numsymbols].chr=postfixbyte;
			self->numsymbols++;
		}

		self->prevsymbol=symbol;
	}

	if(self->numsymbols==self->maxsymbols) return LZWTooManyCodesError;

	return LZWNoError;
}

int LZWOutputLength(LZW *self)
{
	int symbol=self->prevsymbol;
	int n=0;

	while(symbol>=0)
	{
		symbol=self->nodes[symbol].parent;
		n++;
	}

	return n;
}

int LZWOutputToBuffer(LZW *self,uint8_t *buffer)
{
	int symbol=self->prevsymbol;
	int n=LZWOutputLength(self);
	buffer+=n;

	while(symbol>=0)
	{
		*--buffer=self->nodes[symbol].chr;
		symbol=self->nodes[symbol].parent;
	}

	return n;
}

int LZWReverseOutputToBuffer(LZW *self,uint8_t *buffer)
{
	int symbol=self->prevsymbol;
	int n=0;

	while(symbol>=0)
	{
		*buffer++=self->nodes[symbol].chr;
		symbol=self->nodes[symbol].parent;
		n++;
	}

	return n;
}

int LZWSymbolCount(LZW *self)
{
	return self->numsymbols;
}

int LZWSymbolListFull(LZW *self)
{
	return self->numsymbols==self->maxsymbols;
}
