#include "../../include/xadmaster.h"

#include "rar.hpp"

#include "unpack.cpp"
#include "rarvm.cpp"
#include "getbits.cpp"



ErrorHandler ErrHandler;



void ErrorHandler::MemoryError() { throw XADERR_NOMEMORY; }




ComprDataIO::ComprDataIO(struct xadArchiveInfo *archiveinfo,struct xadMasterBase *xadMasterBase)
{
	ai=archiveinfo;
	xmb=xadMasterBase;
}

int ComprDataIO::UnpRead(byte *Addr,uint Count)
{
	if(Count>bytesleft) Count=bytesleft;

	xadERROR err=xadHookTagAccess(xmb,XADAC_READ,Count,Addr,ai,
		XAD_USESKIPINFO,1,
	TAG_DONE);
	if(err) throw err;

	bytesleft-=Count;

	return Count;
}

void ComprDataIO::UnpWrite(byte *Addr,uint Count)
{
	if(dryrun) return;
	xadERROR err=xadHookTagAccess(xmb,XADAC_WRITE,Count,Addr,ai,
		XAD_GETCRC32,crcptr,
	TAG_DONE);
	if(err) throw err;
}



uint CRC(uint StartCRC,const void *Addr,uint Size)
{
	static uint CRCTab[256]={0};
	if (CRCTab[1]==0)
	{
		for (int I=0;I<256;I++)
		{
			uint C=I;
			for (int J=0;J<8;J++) C=(C & 1) ? (C>>1)^0xEDB88320L : (C>>1);
			CRCTab[I]=C;
		}
	}
	byte *Data=(byte *)Addr;
	for (int I=0;I<Size;I++) StartCRC=CRCTab[(byte)(StartCRC^Data[I])]^(StartCRC>>8);
	return(StartCRC);
}



struct RarCppPrivate
{
	ComprDataIO *io;
	Unpack *unpack;
};

extern "C" xadPTR rar_make_unpacker(struct xadArchiveInfo *ai,struct xadMasterBase *xadMasterBase)
{
	RarCppPrivate *unpacker=new RarCppPrivate;
	if(!unpacker) return NULL;

	unpacker->io=new ComprDataIO(ai,xadMasterBase);
	unpacker->unpack=new Unpack(unpacker->io);

	if(!unpacker->io||!unpacker->unpack) { delete unpacker->unpack; delete unpacker->io; delete unpacker; return NULL; }

	try { unpacker->unpack->Init(NULL); }
	catch(xadERROR error) { delete unpacker->unpack; delete unpacker->io; delete unpacker; return NULL; }

	return (xadPTR)unpacker;
}

extern "C" xadERROR rar_run_unpacker(xadPTR *unpacker,xadSize packedsize,xadSize fullsize,xadUINT8 version,xadBOOL solid,xadBOOL dryrun,xadUINT32 *crc)
{
	Unpack *unp=((RarCppPrivate *)unpacker)->unpack;
	ComprDataIO *io=((RarCppPrivate *)unpacker)->io;

	io->bytesleft=packedsize;
	io->crcptr=crc;
	io->dryrun=dryrun;

	unp->SetDestSize(fullsize);

	try { unp->DoUnpack(version,solid); }
	catch(xadERROR err) { return err; }

	return XADERR_OK;
}

extern "C" void rar_destroy_unpacker(xadPTR *unpacker)
{
	if(unpacker)
	{
		delete ((RarCppPrivate *)unpacker)->unpack;
		delete ((RarCppPrivate *)unpacker)->io;
		delete (RarCppPrivate *)unpacker;
	}
}
