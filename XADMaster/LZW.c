#include "LZW.h"
#include <stdlib.h>

LZW *AllocLZW(int maxsymbols,int reservedsymbols)
{
	LZW *self=(LZW *)malloc(sizeof(LZW)+sizeof(LZWTreeNode)*maxsymbols);
	if(!self) return 0;

	self->maxsymbols=maxsymbols;
	self->reservedsymbols=reservedsymbols;

	self->buffer=NULL;
	self->buffersize=0;

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
	if(self)
	{
		free(self->buffer);
		free(self);
	}
}

void ClearLZWTable(LZW *self)
{
	self->numsymbols=256+self->reservedsymbols;
	self->prevsymbol=-1;
	self->symbolsize=9; // TODO: technically this depends on reservedsymbols
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
		if(symbol>=self->numsymbols) return LZWInvalidCodeError;
		self->prevsymbol=symbol;

		return LZWNoError;
	}

	int postfixbyte;
	if(symbol<self->numsymbols) postfixbyte=FindFirstByte(self->nodes,symbol);
	else if(symbol==self->numsymbols) postfixbyte=FindFirstByte(self->nodes,self->prevsymbol);
	else return LZWInvalidCodeError;

	int parent=self->prevsymbol;
	self->prevsymbol=symbol;

	if(!LZWSymbolListFull(self))
	{
		self->nodes[self->numsymbols].parent=parent;
		self->nodes[self->numsymbols].chr=postfixbyte;
		self->numsymbols++;

		if(!LZWSymbolListFull(self))
		if((self->numsymbols&self->numsymbols-1)==0) self->symbolsize++;

		return LZWNoError;
	}
	else
	{
		return LZWTooManyCodesError;
	}
}

int ReplaceLZWSymbol(LZW *self,int oldsymbol,int symbol)
{
	if(symbol>=self->numsymbols) return LZWInvalidCodeError;

	self->nodes[oldsymbol].parent=self->prevsymbol;
	self->nodes[oldsymbol].chr=FindFirstByte(self->nodes,symbol);

	self->prevsymbol=symbol;

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

int LZWOutputToInternalBuffer(LZW *self)
{
	int symbol=self->prevsymbol;
	int n=LZWOutputLength(self);

	if(n>self->buffersize)
	{
		free(self->buffer);
		self->buffersize+=1024;
		self->buffer=malloc(self->buffersize);
	}

	uint8_t *buffer=self->buffer+n;
	while(symbol>=0)
	{
		*--buffer=self->nodes[symbol].chr;
		symbol=self->nodes[symbol].parent;
	}

	return n;
}
