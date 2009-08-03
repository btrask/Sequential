#ifndef __RARUnpacker_h__
#define __RARUnpacker_h__

#ifdef __cplusplus
extern "C" {
#endif

#include <sys/types.h>

typedef int (*RARReadFunc)(void *,void *,int,void *);

typedef struct RARUnpacker
{
	void *io,*unpack;

	int method,solid;
	void *blockbytes;
	int blocklength,maxblocklength;

	RARReadFunc readfunc;
	void *readparam1,*readparam2;
} RARUnpacker;

RARUnpacker *AllocRARUnpacker(RARReadFunc readfunc,void *readparam1,void *readparam2);
void FreeRARUnpacker(RARUnpacker *self);
void StartRARUnpacker(RARUnpacker *self,off_t length,int method,int solid);
void *NextRARBlock(RARUnpacker *self,int *length);
int IsRARFinished(RARUnpacker *self);

#ifdef __cplusplus
}
#endif

#endif
