#import "CSInputBuffer.h"



// Allocation and management

CSInputBuffer *CSInputBufferAlloc(CSHandle *parent,int size)
{
	CSInputBuffer *self=malloc(sizeof(CSInputBuffer)+size);
	if(!self) return NULL;

	self->parent=[parent retain];
	self->startoffs=[parent offsetInFile];
	self->eof=NO;

	self->buffer=(uint8_t *)&self[1];
	self->bufsize=size;
	self->bufbytes=0;
	self->currbyte=0;
	self->bits=0;
	self->numbits=0;

	return self;
}

CSInputBuffer *CSInputBufferAllocWithBuffer(const uint8_t *buffer,int length,off_t startoffs)
{
	CSInputBuffer *self=malloc(sizeof(CSInputBuffer));
	if(!self) return NULL;

	self->parent=NULL;
	self->startoffs=-startoffs;
	self->eof=YES;

	self->buffer=(uint8_t *)buffer; // Since eof is set, the buffer won't be written to.
	self->bufsize=length;
	self->bufbytes=length;
	self->currbyte=0;
	self->bits=0;
	self->numbits=0;

	return self;
}

CSInputBuffer *CSInputBufferAllocEmpty()
{
	CSInputBuffer *self=malloc(sizeof(CSInputBuffer));
	if(!self) return NULL;

	self->parent=NULL;
	self->startoffs=0;
	self->eof=YES;

	self->buffer=NULL;
	self->bufsize=0;
	self->bufbytes=0;
	self->currbyte=0;
	self->bits=0;
	self->numbits=0;

	return self;
}

void CSInputBufferFree(CSInputBuffer *self)
{
	if(self) [self->parent release];
	free(self);
}

void CSInputSetMemoryBuffer(CSInputBuffer *self,uint8_t *buffer,int length,off_t startoffs)
{
	self->eof=YES;
	self->startoffs=-startoffs;
	self->buffer=buffer;
	self->bufsize=length;
	self->bufbytes=length;
	self->currbyte=0;
	self->bits=0;
	self->numbits=0;
}





// Buffer and file positioning

void CSInputRestart(CSInputBuffer *self)
{
	CSInputSeekToFileOffset(self,self->startoffs);
}

void CSInputFlush(CSInputBuffer *self)
{
	self->currbyte=self->bufbytes=0;
	self->bits=0;
	self->numbits=0;
}

void CSInputSynchronizeFileOffset(CSInputBuffer *self)
{
	CSInputSeekToFileOffset(self,CSInputFileOffset(self));
}

void CSInputSeekToFileOffset(CSInputBuffer *self,off_t offset)
{
	[self->parent seekToFileOffset:offset];
	self->eof=NO;
	CSInputFlush(self);
}

void CSInputSeekToBufferOffset(CSInputBuffer *self,off_t offset)
{
	CSInputSeekToFileOffset(self,offset+self->startoffs);
}

void CSInputSetStartOffset(CSInputBuffer *self,off_t offset)
{
	self->startoffs=offset;
}

off_t CSInputBufferOffset(CSInputBuffer *self)
{
	return CSInputFileOffset(self)-self->startoffs;
}

off_t CSInputFileOffset(CSInputBuffer *self)
{
	if(self->parent) return [self->parent offsetInFile]-self->bufbytes+self->currbyte;
	else return self->currbyte;
}

off_t CSInputBufferBitOffset(CSInputBuffer *self)
{
	return CSInputBufferOffset(self)*8-(self->numbits&7);
}




// Byte reading

void _CSInputFillBuffer(CSInputBuffer *self)
{
	int left=_CSInputBytesLeftInBuffer(self);

	if(left>=0) memmove(self->buffer,self->buffer+self->currbyte,left);
	else
	{
		[self->parent skipBytes:-left];
		left=0;
	}

	int actual=[self->parent readAtMost:self->bufsize-left toBuffer:self->buffer+left];
	if(actual==0) self->eof=YES;

	self->bufbytes=left+actual;
	self->currbyte=0;
}




// Bitstream reading

static inline int imin(int a,int b) { return a<b?a:b; }

static inline int iswap16(uint16_t v) { return (v>>8)|(v<<8); }

// TODO: clean up and/or make faster
void _CSInputFillBits(CSInputBuffer *self)
{
	_CSInputCheckAndFillBuffer(self);

	int numbytes=(32-self->numbits)>>3;
	int left=_CSInputBytesLeftInBuffer(self);
	if(numbytes>left) numbytes=left;

	int startoffset=self->numbits>>3;
//	int shift=24-self->numbits;

//	for(int i=0;i<numbytes;i++)
//	{
//		self->bits|=_CSInputPeekByteWithoutEOF(self,i+startoffset)<<shift;
//		shift-=8;
//	}

	switch(numbytes)
	{
		case 4:
			self->bits=
			(_CSInputPeekByteWithoutEOF(self,startoffset)<<24)|
			(_CSInputPeekByteWithoutEOF(self,startoffset+1)<<16)|
			(_CSInputPeekByteWithoutEOF(self,startoffset+2)<<8)|
			_CSInputPeekByteWithoutEOF(self,startoffset+3);
		break;
		case 3:
			self->bits|=(
				(_CSInputPeekByteWithoutEOF(self,startoffset)<<16)|
				(_CSInputPeekByteWithoutEOF(self,startoffset+1)<<8)|
				(_CSInputPeekByteWithoutEOF(self,startoffset+2)<<0)
			)<<8-self->numbits;
		break;
		case 2:
			self->bits|=(
				(_CSInputPeekByteWithoutEOF(self,startoffset)<<8)|
				(_CSInputPeekByteWithoutEOF(self,startoffset+1)<<0)
			)<<16-self->numbits;
		break;
		case 1:
			self->bits|=_CSInputPeekByteWithoutEOF(self,startoffset)<<24-self->numbits;
		break;
	}

	self->numbits+=numbytes*8;
}

void _CSInputFillBitsLE(CSInputBuffer *self)
{
	_CSInputCheckAndFillBuffer(self);

	int numbytes=(32-self->numbits)>>3;
	int left=_CSInputBytesLeftInBuffer(self);
	if(numbytes>left) numbytes=left;

	int startoffset=self->numbits>>3;

	for(int i=0;i<numbytes;i++)
	{
		self->bits|=_CSInputPeekByteWithoutEOF(self,i+startoffset)<<self->numbits;
		self->numbits+=8;
	}
}

unsigned int CSInputNextBit(CSInputBuffer *self)
{
	unsigned int bit=CSInputPeekBitString(self,1);
	CSInputSkipPeekedBits(self,1);
	return bit;
}

unsigned int CSInputNextBitLE(CSInputBuffer *self)
{
	unsigned int bit=CSInputPeekBitStringLE(self,1);
	CSInputSkipPeekedBitsLE(self,1);
	return bit;
}

unsigned int CSInputNextBitString(CSInputBuffer *self,int numbits)
{
	if(numbits==0) return 0;
	unsigned int bits=CSInputPeekBitString(self,numbits);
	CSInputSkipPeekedBits(self,numbits);
	return bits;
}

unsigned int CSInputNextBitStringLE(CSInputBuffer *self,int numbits)
{
	if(numbits==0) return 0;
	unsigned int bits=CSInputPeekBitStringLE(self,numbits);
	CSInputSkipPeekedBitsLE(self,numbits);
	return bits;
}

unsigned int CSInputNextLongBitString(CSInputBuffer *self,int numbits)
{
	if(numbits<=25) return CSInputNextBitString(self,numbits);
	else
	{
		int rest=numbits-25;
		unsigned int bits=CSInputNextBitString(self,25)<<rest;
		return bits|CSInputNextBitString(self,rest);
	}
}

unsigned int CSInputNextLongBitStringLE(CSInputBuffer *self,int numbits)
{
	if(numbits<=25) return CSInputNextBitStringLE(self,numbits);
	else
	{
		int rest=numbits-25;
		unsigned int bits=CSInputNextBitStringLE(self,25);
		return bits|(CSInputNextBitStringLE(self,rest)<<25);
	}
}

void CSInputSkipBits(CSInputBuffer *self,int numbits)
{
	if(numbits<=self->numbits) CSInputSkipPeekedBits(self,numbits);
	else
	{
		int skipbits=numbits-(self->numbits&7);
		CSInputSkipToByteBoundary(self);
		CSInputSkipBytes(self,skipbits>>3);
		if(skipbits&7) CSInputNextBitString(self,skipbits&7);
	}
}

void CSInputSkipBitsLE(CSInputBuffer *self,int numbits)
{
	if(numbits<=self->numbits) CSInputSkipPeekedBitsLE(self,numbits);
	else
	{
		int skipbits=numbits-(self->numbits&7);
		CSInputSkipToByteBoundary(self);
		CSInputSkipBytes(self,skipbits>>3);
		if(skipbits&7) CSInputNextBitStringLE(self,skipbits&7);
	}	
}



BOOL CSInputOnByteBoundary(CSInputBuffer *self)
{
	return (self->numbits&7)==0;
}

void CSInputSkipToByteBoundary(CSInputBuffer *self)
{
	self->bits=0;
	self->numbits=0;
}

void CSInputSkipTo16BitBoundary(CSInputBuffer *self)
{
	CSInputSkipToByteBoundary(self);
	if(CSInputBufferOffset(self)&1) CSInputSkipBytes(self,1);
}
