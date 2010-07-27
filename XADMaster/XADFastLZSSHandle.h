#import "CSStreamHandle.h"
#import "LZSS.h"

@interface XADFastLZSSHandle:CSStreamHandle
{
	@public
	LZSS lzss;
	off_t flushbarrier;

	off_t bufferpos,bufferend;
	uint8_t *bufferpointer;
}

-(id)initWithName:(NSString *)descname windowSize:(int)windowsize;
-(id)initWithName:(NSString *)descname length:(off_t)length windowSize:(int)windowsize;
-(id)initWithHandle:(CSHandle *)handle windowSize:(int)windowsize;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length windowSize:(int)windowsize;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(void)resetLZSSHandle;
-(void)expandFromPosition:(off_t)pos;

-(void)endLZSSHandle;

@end



void XADLZSSFlushToBuffer(XADFastLZSSHandle *self);

static inline BOOL XADLZSSShouldKeepExpanding(XADFastLZSSHandle *self)
{
	return LZSSPosition(&self->lzss)<self->bufferend;
}

static inline void XADLZSSLiteral(XADFastLZSSHandle *self,uint8_t byte,off_t *pos)
{
	if(LZSSPosition(&self->lzss)==self->flushbarrier) XADLZSSFlushToBuffer(self);

	EmitLZSSLiteral(&self->lzss,byte);
	if(pos) *pos=LZSSPosition(&self->lzss);
}

static inline void XADLZSSMatch(XADFastLZSSHandle *self,int offset,int length,off_t *pos)
{
	if(LZSSPosition(&self->lzss)+length>self->flushbarrier) XADLZSSFlushToBuffer(self);

	EmitLZSSMatch(&self->lzss,offset,length);
	if(pos) *pos=LZSSPosition(&self->lzss);
}

/*static inline uint8_t XADLZSSByteFromWindow2(XADFastLZSSHandle *self,off_t absolutepos)
{
	return self->windowbuffer[absolutepos&self->windowmask];
}*/
