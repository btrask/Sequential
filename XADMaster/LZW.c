#include "LZW.h"
#include <stdlib.h>

LZW *AllocLZW(int maxsymbols,int reservedsymbols)
{
	LZW *lzw=malloc(sizeof(LZW)+sizeof(LZWTreeNode)*maxsymbols);
	if(!lzw) return 0;

	lzw->nodes=(LZWTreeNode *)&lzw[1];
	lzw->maxsymbols=maxsymbols;
	lzw->reservedsymbols=reservedsymbols;

	for(int i=0;i<256;i++)
	{
		lzw->nodes[i].chr=i;
		lzw->nodes[i].parent=-1;
	}

	ClearLZWTable(lzw);

	return lzw;
}

void FreeLZW(LZW *lzw)
{
	free(lzw);
}

void ClearLZWTable(LZW *lzw)
{
	lzw->numsymbols=256+lzw->reservedsymbols;
	lzw->prevsymbol=-1;
}

static uint8_t FindFirstByte(LZWTreeNode *nodes,int symbol)
{
	while(nodes[symbol].parent>=0) symbol=nodes[symbol].parent;
	return nodes[symbol].chr;
}

int NextLZWSymbol(LZW *lzw,int symbol)
{
	if(lzw->prevsymbol<0)
	{
		if(symbol>=256+lzw->reservedsymbols) return LZWInvalidCodeError;
		lzw->prevsymbol=symbol;
	}
	else
	{
		int postfixbyte;
		if(symbol<lzw->numsymbols) postfixbyte=FindFirstByte(lzw->nodes,symbol);
		else if(symbol==lzw->numsymbols) postfixbyte=FindFirstByte(lzw->nodes,lzw->prevsymbol);
		else return LZWInvalidCodeError;

		if(lzw->numsymbols<lzw->maxsymbols)
		{
			lzw->nodes[lzw->numsymbols].parent=lzw->prevsymbol;
			lzw->nodes[lzw->numsymbols].chr=postfixbyte;
			lzw->numsymbols++;
		}

		lzw->prevsymbol=symbol;
	}

	if(lzw->numsymbols==lzw->maxsymbols) return LZWTooManyCodesError;

	return LZWNoError;
}

int LZWOutputLength(LZW *lzw)
{
	int symbol=lzw->prevsymbol;
	int n=0;

	while(symbol>=0)
	{
		symbol=lzw->nodes[symbol].parent;
		n++;
	}

	return n;
}

int LZWOutputToBuffer(LZW *lzw,uint8_t *buffer)
{
	int symbol=lzw->prevsymbol;
	int n=LZWOutputLength(lzw);
	buffer+=n;

	while(symbol>=0)
	{
		*--buffer=lzw->nodes[symbol].chr;
		symbol=lzw->nodes[symbol].parent;
	}

	return n;
}

int LZWReverseOutputToBuffer(LZW *lzw,uint8_t *buffer)
{
	int symbol=lzw->prevsymbol;
	int n=0;

	while(symbol>=0)
	{
		*buffer++=lzw->nodes[symbol].chr;
		symbol=lzw->nodes[symbol].parent;
		n++;
	}

	return n;
}

int LZWSymbolCount(LZW *lzw)
{
	return lzw->numsymbols;
}

int LZWSymbolListFull(LZW *lzw)
{
	return lzw->numsymbols==lzw->maxsymbols;
}
