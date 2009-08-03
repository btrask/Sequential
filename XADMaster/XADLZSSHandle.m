#import "XADLZSSHandle.h"

@implementation XADLZSSHandle

-(id)initWithHandle:(CSHandle *)handle windowSize:(int)windowsize
{
	if(self=[super initWithHandle:handle])
	{
		nextliteral_ptr=(int (*)(id,SEL,int *,int *,off_t))
		[self methodForSelector:@selector(nextLiteralOrOffset:andLength:atPosition:)];

		windowbuffer=malloc(windowsize);
		windowmask=windowsize-1; // Assumes windows are always power-of-two sized!
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize
{
	if(self=[super initWithHandle:handle length:length])
	{
		nextliteral_ptr=(int (*)(id,SEL,int *,int *,off_t))
		[self methodForSelector:@selector(nextLiteralOrOffset:andLength:atPosition:)];

		windowbuffer=malloc(windowsize);
		windowmask=windowsize-1; // Assumes windows are always power-of-two sized!
	}
	return self;
}

-(void)dealloc
{
	free(windowbuffer);
	[super dealloc];
}

-(void)resetByteStream
{
	matchlength=0;
	matchoffset=0;
	memset(windowbuffer,0,windowmask+1);

	[self resetLZSSHandle];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!matchlength)
	{
		int offset,length;
		int val=nextliteral_ptr(self,@selector(nextLiteralOrOffset:andLength:atPosition:),&offset,&length,pos);

		if(val>=0) return windowbuffer[pos&windowmask]=val;
		else if(val==XADLZSSEnd) CSByteStreamEOF(self);
		else
		{
			matchlength=length;
			matchoffset=pos-offset;
		}
	}

	matchlength--;
	uint8_t byte=windowbuffer[matchoffset++&windowmask];
	return windowbuffer[pos&windowmask]=byte;
}

-(void)resetLZSSHandle {}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos { return XADLZSSEnd; }

@end
