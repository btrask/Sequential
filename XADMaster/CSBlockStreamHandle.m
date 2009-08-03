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



-(void)setBlockPointer:(uint8_t *)blockpointer
{
	currblock=blockpointer;
}



-(void)seekToFileOffset:(off_t)offs
{
	if(offs==streampos) return;
	if(nextstreambyte>=0) // NOTE: Undoes the lookahead done by StreamHandle.
	{
		nextstreambyte=-1;
		streampos+=1;
	}

	if(offs>=blockstartpos&&offs<blockstartpos+blocklength)
	{
		streampos=offs;
	}
	else
	{
		if(offs>=blockstartpos+blocklength) streampos=blockstartpos+blocklength;
		[super seekToFileOffset:offs];
	}
}

-(void)resetStream
{
	blockstartpos=0;
	blocklength=0;
	endofblocks=NO;
	[self resetBlockStream];
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
		blockstartpos+=blocklength;
		if(endofblocks) { [self endStream]; break; }
		blocklength=[self produceBlockAtOffset:streampos+n];

		if(blocklength<=0||!currblock) { [self endStream]; break; }

		int count=imin(blocklength,num-n);
		memcpy(buffer+n,currblock,count);
		n+=count;
	}

	return n;
}

-(void)resetBlockStream { }

-(int)produceBlockAtOffset:(off_t)pos { return 0; }

-(void)endBlockStream
{
	endofblocks=YES;
}

@end
