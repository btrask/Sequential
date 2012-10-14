#import "XADFastLZSSHandle.h"

// TODO: Seeking

@implementation XADFastLZSSHandle

-(id)initWithName:(NSString *)descname windowSize:(int)windowsize
{
	return [self initWithName:descname length:CSHandleMaxLength windowSize:windowsize];
}

-(id)initWithName:(NSString *)descname length:(off_t)length windowSize:(int)windowsize
{
	if((self=[super initWithName:descname length:length]))
	{
		InitializeLZSS(&lzss,windowsize);
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle windowSize:(int)windowsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength windowSize:windowsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize
{
	if((self=[super initWithHandle:handle length:length]))
	{
		InitializeLZSS(&lzss,windowsize);
	}
	return self;
}

-(void)dealloc
{
	CleanupLZSS(&lzss);
	[super dealloc];
}

-(void)resetStream
{
	RestartLZSS(&lzss);
	[self resetLZSSHandle];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	bufferpointer=buffer;
	bufferpos=streampos;
	bufferend=streampos+num;

	XADLZSSFlushToBuffer(self);

	if(bufferpos!=bufferend)
	{
		flushbarrier=LZSSPosition(&lzss)+LZSSWindowSize(&lzss);

		[self expandFromPosition:LZSSPosition(&lzss)];

		XADLZSSFlushToBuffer(self);
	}

	return bufferpos-streampos;
}

-(void)resetLZSSHandle {}

-(void)expandFromPosition:(off_t)pos {}

-(void)endLZSSHandle { [self endStream]; }

// TODO: remove usage of bufferpos entirely, it's somewhat redundant.
void XADLZSSFlushToBuffer(XADFastLZSSHandle *self)
{
	off_t end=LZSSPosition(&self->lzss);
	if(end>self->bufferend) end=self->bufferend;

	int available=end-self->bufferpos;
	if(available==0) return;
	//if(available<0) [XADException raiseUnknownException]; // TODO: better error

	CopyBytesFromLZSSWindow(&self->lzss,self->bufferpointer,self->bufferpos,available);

	self->bufferpos+=available;
	self->bufferpointer+=available;
	self->flushbarrier+=available;
}

@end

