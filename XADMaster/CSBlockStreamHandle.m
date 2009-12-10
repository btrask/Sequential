#import "CSBlockStreamHandle.h"

static inline int imin(int a,int b) { return a<b?a:b; }

@implementation CSBlockStreamHandle

-(id)initWithName:(NSString *)descname length:(off_t)length
{
	if(self=[super initWithName:descname length:length])
	{
		currblock=NULL;
		blockstartpos=0;
		blocklength=0;
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length bufferSize:(int)buffersize;
{
	if(self=[super initWithHandle:handle length:length bufferSize:buffersize])
	{
		currblock=NULL;
		blockstartpos=0;
		blocklength=0;
	}
	return self;
}

-(id)initAsCopyOf:(CSBlockStreamHandle *)other
{
	[self _raiseNotSupported:_cmd];
	return nil;
}


-(uint8_t *)blockPointer { return currblock; }

-(int)blockLength { return blocklength; }

-(off_t)blockStartOffset { return blockstartpos; }

-(void)skipToNextBlock { [self seekToFileOffset:blockstartpos+blocklength]; }



-(void)seekToFileOffset:(off_t)offs
{
	if(![self _prepareStreamSeekTo:offs]) return;

	if(offs<blockstartpos) [super seekToFileOffset:0];

	while(blockstartpos+blocklength<=offs)
	{
		[self _readNextBlock];
		if(endofstream)
		{
			if(offs==blockstartpos) break;
			else [self _raiseEOF];
		}
	}

	streampos=offs;
}

-(void)resetStream
{
	blockstartpos=0;
	blocklength=0;
	endofblocks=NO;
	[self resetBlockStream];
	[self _readNextBlock];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int n=0;

	if(streampos>=blockstartpos&&streampos<blockstartpos+blocklength)
	{
		if(!currblock) return 0;

		int offs=streampos-blockstartpos;
		int count=blocklength-offs;
		if(count>num) count=num;
		memcpy(buffer,currblock+offs,count);
		n+=count;
	}

	while(n<num)
	{
		[self _readNextBlock];
		if(endofstream) break;

		int count=imin(blocklength,num-n);
		memcpy(buffer+n,currblock,count);
		n+=count;
	}

	return n;
}

-(void)_readNextBlock
{
	blockstartpos+=blocklength;
	if(endofblocks) { [self endStream]; return; }
	blocklength=[self produceBlockAtOffset:blockstartpos];

	if(blocklength<=0||!currblock) [self endStream];
}

-(void)resetBlockStream { }

-(int)produceBlockAtOffset:(off_t)pos { return 0; }



-(void)setBlockPointer:(uint8_t *)blockpointer
{
	currblock=blockpointer;
}

-(void)endBlockStream
{
	endofblocks=YES;
}

@end
