#import "XADLZMAHandle.h"
#import "XADException.h"

static void *Alloc(void *p,size_t size) { return malloc(size); }
static void Free(void *p,void *address) { return free(address); }
static ISzAlloc allocator={Alloc,Free};

@implementation XADLZMAHandle

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:propertydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata
{
	if((self=[super initWithName:[handle name] length:length]))
	{
		parent=[handle retain];
		startoffs=[parent offsetInFile];

		LzmaDec_Construct(&lzma);
		if(LzmaDec_Allocate(&lzma,[propertydata bytes],[propertydata length],&allocator)==SZ_OK)
		{
			return self;
		}
	}

	[self release];
	return nil;
}

-(void)dealloc
{
	LzmaDec_Free(&lzma,&allocator);

	[parent release];
	[super dealloc];

}

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];
	LzmaDec_Init(&lzma);
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

		int res=LzmaDec_DecodeToBuf(&lzma,buffer+total,&destlen,inbuffer+bufoffs,&srclen,LZMA_FINISH_ANY,&status);

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
			[self endStream];
			break;
		}
	}

	return total;
}

@end

