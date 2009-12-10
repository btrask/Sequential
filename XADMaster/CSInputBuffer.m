#import "CSInputBuffer.h"

CSInputBuffer *CSInputBufferAlloc(CSHandle *parent,int size)
{
	CSInputBuffer *buf=malloc(sizeof(CSInputBuffer)+size);
	if(!buf) return NULL;

	buf->parent=[parent retain];
	buf->startoffs=[parent offsetInFile];
	buf->eof=NO;

	buf->buffer=(uint8_t*)&buf[1];
	buf->bufsize=size;
	buf->bufbytes=0;
	buf->currbyte=0;
	buf->currbit=0;

	return buf;
}

CSInputBuffer *CSInputBufferAllocWithBuffer(uint8_t *buffer,int length,off_t startoffs)
{
	CSInputBuffer *buf=malloc(sizeof(CSInputBuffer));
	if(!buf) return NULL;

	buf->parent=NULL;
	buf->startoffs=-startoffs;
	buf->eof=YES;

	buf->buffer=buffer;
	buf->bufsize=length;
	buf->bufbytes=length;
	buf->currbyte=0;
	buf->currbit=0;

	return buf;
}

CSInputBuffer *CSInputBufferAllocEmpty()
{
	CSInputBuffer *buf=malloc(sizeof(CSInputBuffer));
	if(!buf) return NULL;

	buf->parent=NULL;
	buf->startoffs=0;
	buf->eof=YES;

	buf->buffer=NULL;
	buf->bufsize=0;
	buf->bufbytes=0;
	buf->currbyte=0;
	buf->currbit=0;

	return buf;
}

void CSInputBufferFree(CSInputBuffer *buf)
{
	if(buf) [buf->parent release];
	free(buf);
}

void CSInputSetMemoryBuffer(CSInputBuffer *buf,uint8_t *buffer,int length,off_t startoffs)
{
	buf->eof=YES;
	buf->startoffs=-startoffs;
	buf->buffer=buffer;
	buf->bufsize=length;
	buf->bufbytes=length;
	buf->currbyte=0;
	buf->currbit=0;
}

void CSInputRestart(CSInputBuffer *buf)
{
	CSInputSeekToFileOffset(buf,buf->startoffs);
}

void CSInputFlush(CSInputBuffer *buf)
{
	buf->currbyte=buf->bufbytes=0;
	buf->currbit=0;
}

void CSInputSynchronizeFileOffset(CSInputBuffer *buf)
{
	CSInputSeekToFileOffset(buf,CSInputFileOffset(buf));
}

void CSInputSeekToFileOffset(CSInputBuffer *buf,off_t offset)
{
	[buf->parent seekToFileOffset:offset];
	buf->eof=NO;
	CSInputFlush(buf);
}

void CSInputSeekToBufferOffset(CSInputBuffer *buf,off_t offset)
{
	CSInputSeekToFileOffset(buf,offset+buf->startoffs);
}

void CSInputSetStartOffset(CSInputBuffer *buf,off_t offset)
{
	buf->startoffs=offset;
}


off_t CSInputBufferOffset(CSInputBuffer *buf)
{
	return CSInputFileOffset(buf)-buf->startoffs;
}

off_t CSInputFileOffset(CSInputBuffer *buf)
{
	if(buf->parent) return [buf->parent offsetInFile]-buf->bufbytes+buf->currbyte;
	else return buf->currbyte;
}



void _CSInputFillBuffer(CSInputBuffer *buf)
{
	int left=buf->bufbytes-buf->currbyte;

	if(left>=0) memmove(buf->buffer,buf->buffer+buf->currbyte,left);
	else
	{
		[buf->parent skipBytes:-left];
		left=0;
	}

	int actual=[buf->parent readAtMost:buf->bufsize-left toBuffer:buf->buffer+left];
	if(actual==0) buf->eof=YES;

	buf->bufbytes=left+actual;
	buf->currbyte=0;
}



void CSInputSkipBits(CSInputBuffer *buf,int bits)
{
	CSInputSkipBytes(buf,buf->currbit+bits>>3);
	buf->currbit=(buf->currbit+bits)&7;
}

BOOL CSInputOnByteBoundary(CSInputBuffer *buf) { return buf->currbit==0; }

void CSInputSkipToByteBoundary(CSInputBuffer *buf)
{
	if(buf->currbit!=0) CSInputSkipBytes(buf,1);
	buf->currbit=0;
}

void CSInputSkipTo16BitBoundary(CSInputBuffer *buf)
{
	CSInputSkipToByteBoundary(buf);
	if(CSInputBufferOffset(buf)&1) CSInputSkipBytes(buf,1);
}



int CSInputNextBit(CSInputBuffer *buf)
{
	_CSInputCheckAndFillBuffer(buf);

	int bit=(CSInputPeekByte(buf,0)>>7-buf->currbit)&1;

	if(++buf->currbit>=8)
	{
		buf->currbit=0;
		CSInputSkipBytes(buf,1);
	}

	return bit;
}

int CSInputNextBitLE(CSInputBuffer *buf)
{
	_CSInputCheckAndFillBuffer(buf);

	int bit=(CSInputPeekByte(buf,0)>>buf->currbit)&1;

	if(++buf->currbit>=8)
	{
		buf->currbit=0;
		CSInputSkipBytes(buf,1);
	}

	return bit;
}

unsigned int CSInputNextBitString(CSInputBuffer *buf,int bits)
{
	unsigned int val=CSInputPeekBitString(buf,bits);
	CSInputSkipBits(buf,bits);
	return val;
}

unsigned int CSInputNextBitStringLE(CSInputBuffer *buf,int bits)
{
	unsigned int val=CSInputPeekBitStringLE(buf,bits);
	CSInputSkipBits(buf,bits);
	return val;
}

unsigned int CSInputPeekBitString(CSInputBuffer *buf,int bits)
{
	_CSInputCheckAndFillBuffer(buf);

	unsigned int res=0,currbit=buf->currbit;
	while(bits)
	{
		int num=bits;
		if(num>8-(currbit&7)) num=8-(currbit&7);
		res=(res<<num)| ((CSInputPeekByte(buf,currbit>>3)>>(8-(currbit&7)-num))&((1<<num)-1));

		bits-=num;
		currbit+=num;
	}
	return res;
}

unsigned int CSInputPeekBitStringLE(CSInputBuffer *buf,int bits)
{
	_CSInputCheckAndFillBuffer(buf);

	unsigned int res=0,pos=0,currbit=buf->currbit;
	while(pos<bits)
	{
		int num=bits-pos;
		if(num>8-(currbit&7)) num=8-(currbit&7);
		res|=((CSInputPeekByte(buf,currbit>>3)>>(currbit&7))&((1<<num)-1))<<pos;

		pos+=num;
		currbit+=num;
	}
	return res;
}


