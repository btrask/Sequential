#import "CSBlockStreamHandle.h"
#import "BWT.h"

/* Constants for huffman coding */
#define MAX_GROUPS			6
#define GROUP_SIZE   		50		/* 64 would have been more efficient */
#define MAX_HUFCODE_BITS 	20		/* Longest huffman code allowed */
#define MAX_SYMBOLS 		258		/* 256 literals + RUNA + RUNB */
#define SYMBOL_RUNA			0
#define SYMBOL_RUNB			1

/* Other housekeeping constants */
#define IOBUF_SIZE			4096

/* This is what we know about each huffman coding group */
struct group_data {
	/* We have an extra slot at the end of limit[] for a sentinal value. */
	int limit[MAX_HUFCODE_BITS+1],base[MAX_HUFCODE_BITS],permute[MAX_SYMBOLS];
	int minLen, maxLen;
};
/* Structure holding all the housekeeping data, including IO buffers and
   memory that persists between calls to bunzip */
typedef struct {
	/* State for interrupting output loop */
	int writeCopies,writePos,writeRunCountdown,writeCount,writeCurrent;
	/* I/O tracking data (file handles, buffers, positions, etc.) */
	CSHandle *inhandle;
	int inbufCount,inbufPos;
	unsigned char inbuf[IOBUF_SIZE];
	unsigned int inbufBitCount, inbufBits;
	bool hasrand;
	/* Intermediate buffer and its size (in bytes) */
	unsigned int *dbuf, dbufSize;
	/* These things are a bit too big to go on the stack */
	unsigned char selectors[32768];			/* nSelectors=15 bits */
	struct group_data groups[MAX_GROUPS];	/* huffman coding tables */
	/* For I/O error handling */
	jmp_buf jmpbuf;
} bunzip_data;

@interface XADNSISBzip2Handle:CSBlockStreamHandle
{
	CSHandle *parent;
	off_t startoffs;
	BOOL hasrand;

	bunzip_data bd;
	uint32_t blocktable[900000];
	uint8_t outblock[65536];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length hasRandomizationBit:(BOOL)hasrandbit;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
