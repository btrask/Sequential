#include "RARUnpacker.h"
#include "../XADMaster/SystemSpecific.h"
#include "unrar/rar.hpp"
#include <stdint.h>

extern "C" {

RARUnpacker *AllocRARUnpacker(RARReadFunc readfunc,void *readparam1,const void *readparam2)
{
	RARUnpacker *self=(RARUnpacker *)malloc(sizeof(RARUnpacker));
	if(!self) return NULL;

	ComprDataIO *io=new ComprDataIO(self);
	Unpack *unpack=new Unpack(io);
	unpack->Init(NULL);

	self->io=(void *)io;
	self->unpack=(void *)unpack;

	self->blockbytes=NULL;
	self->maxblocklength=0;

	self->readfunc=readfunc;
	self->readparam1=readparam1;
	self->readparam2=readparam2;

	return self;
}

void FreeRARUnpacker(RARUnpacker *self)
{
	delete (Unpack *)self->unpack;
	delete (ComprDataIO *)self->io;
	free(self->blockbytes);
	free(self);
}

void StartRARUnpacker(RARUnpacker *self,off_t length,int method,int solid)
{
	Unpack *unpack=(Unpack *)self->unpack;
	unpack->SetDestSize(length);
	unpack->SetSuspended(false);
	self->method=method;
	self->solid=solid;
}

void *NextRARBlock(RARUnpacker *self,int *length)
{
	Unpack *unpack=(Unpack *)self->unpack;

	self->blocklength=0;
	unpack->DoUnpack(self->method,self->solid);
	*length=self->blocklength;

	return self->blockbytes;
}

int IsRARFinished(RARUnpacker *self)
{
	Unpack *unpack=(Unpack *)self->unpack;
	return unpack->IsFileExtracted();
}

}


ComprDataIO::ComprDataIO(RARUnpacker *unpacker)
{
	this->unpacker=unpacker;
}

int ComprDataIO::UnpRead(byte *Addr,uint Count)
{
	return unpacker->readfunc(unpacker->readparam1,unpacker->readparam2,Count,Addr);
}

void ComprDataIO::UnpWrite(byte *Addr,uint Count)
{
	Unpack *unpack=(Unpack *)unpacker->unpack;
	unpack->SetSuspended(true);

	if(unpacker->blocklength+Count>unpacker->maxblocklength)
	{
		unpacker->maxblocklength=unpacker->blocklength+Count;
		unpacker->blockbytes=reallocf(unpacker->blockbytes,unpacker->maxblocklength);
	}

	memcpy(((unsigned char *)unpacker->blockbytes)+unpacker->blocklength,Addr,Count);

	unpacker->blocklength+=Count;
}



extern "C" uint32_t XADCalculateCRC(uint32_t prevcrc,const uint8_t *buffer,int length,const uint32_t *table);
extern const uint32_t XADCRCTable_edb88320[256];

uint CRC(uint StartCRC,const void *Addr,uint Size)
{
	return XADCalculateCRC(StartCRC,(const uint8_t *)Addr,Size,XADCRCTable_edb88320);
}

ErrorHandler ErrHandler;

void ErrorHandler::MemoryError() { /*throw XADERR_NOMEMORY;*/ }

