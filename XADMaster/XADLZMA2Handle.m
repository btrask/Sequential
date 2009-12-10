#import "XADLZMA2Handle.h"
#import "XADException.h"

static void *Alloc(void *p,size_t size) { return malloc(size); }
static void Free(void *p,void *address) { return free(address); }
static ISzAlloc allocator={Alloc,Free};

@implementation XADLZMA2Handle

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:propertydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata
{
	if(self=[super initWithName:[handle name] length:length])
	{
		parent=[handle retain];
		startoffs=[parent offsetInFile];
		seekback=NO;

		Lzma2Dec_Construct(&lzma);
		if([propertydata length]>=1)
		if(Lzma2Dec_Allocate(&lzma,((uint8_t *)[propertydata bytes])[0],&allocator)==SZ_OK)
		{
			return self;
		}
	}

	[self release];
	return nil;
}

-(void)dealloc
{
	Lzma2Dec_Free(&lzma,&allocator);

	[parent release];
	[super dealloc];

}

-(void)setSeekBackAtEOF:(BOOL)seekateof { seekback=seekateof; }

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];
	Lzma2Dec_Init(&lzma);
	bufbytes=bufoffs=0;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int total=0;

	while(total<num)
	{
		size_t destlen=num-total;
		size_t srclen=bufbytes-bufoffs;
		ELzmaStatus status;

		int res=Lzma2Dec_DecodeToBuf(&lzma,buffer+total,&destlen,inbuffer+bufoffs,&srclen,LZMA_FINISH_ANY,&status);

		total+=destlen;
		bufoffs+=srclen;

		if(res!=SZ_OK) [XADException raiseDecrunchException];
		if(status==LZMA_STATUS_NEEDS_MORE_INPUT)
		{
			bufbytes=[parent readAtMost:sizeof(inbuffer) toBuffer:inbuffer];
			if(!bufbytes) [parent _raiseEOF];
			bufoffs=0;
		}
		else if(status==LZMA_STATUS_FINISHED_WITH_MARK)
		{
			if(seekback) [parent skipBytes:-bufbytes+bufoffs];
			[self endStream];
			break;
		}
	}

	return total;
}

@end

