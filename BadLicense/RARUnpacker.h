#ifndef __RARUNPACKER_h__
#define __RARUNPACKER_h__

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/types.h>

typedef int (*RARReadFunc)(void *,const void *,int,void *);

typedef struct RARUnpacker
{
	void *io,*unpack;

	int method,solid;
	void *blockbytes;
	int blocklength,maxblocklength;

	RARReadFunc readfunc;
	void *readparam1;
	const void *readparam2;
} RARUnpacker;

RARUnpacker *AllocRARUnpacker(RARReadFunc readfunc,void *readparam1,const void *readparam2);
void FreeRARUnpacker(RARUnpacker *self);
void StartRARUnpacker(RARUnpacker *self,off_t length,int method,int solid);
void *NextRARBlock(RARUnpacker *self,int *length);
int IsRARFinished(RARUnpacker *self);

#ifdef __cplusplus
}
#endif

#endif
