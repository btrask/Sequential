#import "CSBlockStreamHandle.h"

@interface XADNowCompressHandle:CSBlockStreamHandle
{
	CSHandle *parent;

	NSMutableArray *files;
	int nextfile;

	struct
	{
		uint32_t offset,length;
		int flags;
	} *blocks;
	int maxblocks,numblocks,nextblock;

	uint8_t inblock[0x8000],outblock[0x10000],dictionarycache[0x8000];
}

-(id)initWithHandle:(CSHandle *)handle files:(NSMutableArray *)filesarray;

-(void)resetBlockStream;

-(BOOL)parseAndCheckFileHeaderWithHeaderOffset:(uint32_t)headeroffset
firstOffset:(uint32_t)firstoffset delta:(int32_t)delta;
-(int)findFileHeaderDeltaWithHeaderOffset:(uint32_t)headeroffset firstOffset:(uint32_t)firstoffset;
-(BOOL)readNextFileHeader;
-(int)produceBlockAtOffset:(off_t)pos;

@end
