#import "XADArchivePipe.h"


@implementation XADArchivePipe

static xadUINT32 out_func(struct Hook *hook,xadPTR object,struct xadHookParam *param);
static xadUINT32 in_func(struct Hook *hook,xadPTR object,struct xadHookParam *param);


-(id)initWithArchive:(XADArchive *)archive entry:(int)n bufferSize:(int)buffersize
{
	if(self=[super init])
	{
		sourcearchive=[archive retain];
		entry=n;

		inhook.h_Entry=in_func;
		inhook.h_Data=(void *)self;

		outhook.h_Entry=out_func;
		outhook.h_Data=(void *)self;

		bufsize=buffersize;
		buf=malloc(bufsize);

		if([archive entryHasSize:entry]) fullsize=[archive sizeOfEntry:entry];
		else fullsize=0x7fffffffffffffff;

		bufstart=0;
		buflen=0;
		readpos=0;
		writepos=0;
		requestbuffer=NULL;
		requeststart=0;
		requestlength=0;
		resetwrite=NO;
		writefailed=NO;

		writelock=[[NSLock alloc] init];
		readlock=[[NSLock alloc] init];
		[writelock lock];
		[readlock lock];

		if(buf)
		{
//NSLog(@"init1");
			[NSThread detachNewThreadSelector:@selector(decompress:) toTarget:self withObject:nil];
//NSLog(@"init2");
			[readlock lock]; // Simulate a request
//NSLog(@"init3");
			return self;
		}
		[self release];
	}
	return nil;
}

-(void)dealloc
{
	free(buf);

	[sourcearchive release];
	[writelock release];
	[readlock release];

	[super dealloc];
}

-(void)dismantle
{
//NSLog(@"dismantle");
	resetwrite=YES;
	writefailed=YES;

	[writelock unlock];
}

-(struct Hook *)outHook { return &outhook; }

-(struct Hook *)inHook { return &inhook; }



-(void)decompress:(id)dummy
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];
	[self retain];

	do
	{
//NSLog(@"*** Starting decomression");
		struct TagItem tags[]={
			XAD_OUTHOOK,(xadPTRINT)&outhook,
		TAG_DONE};
		[sourcearchive _extractFileInfo:[sourcearchive xadFileInfoForEntry:entry] tags:tags reportProgress:YES];
	}
	while(!writefailed);

	[self release];
	[pool release];
}



-(xadUINT32)writeStarted
{
//NSLog(@"writeStarted");
	// Reset the write position, and clear the buffer.
	writepos=0;
	bufstart=0;
	buflen=0;

	// Start off read process by waiting for a request, unless this is a restart.
	if(resetwrite) resetwrite=NO;
	else
	{
		[self waitForRequest];
		if(resetwrite) return XADERR_UNKNOWN;
	}

	return 0;
}

-(void)writeStopped
{
	if(!resetwrite)
	{
		writefailed=YES;
		[self waitForRequest];
	}
}

-(xadUINT32)writeBytes:(xadPTR)bytes length:(xadSize)length newPosition:(xadSize *)newpos
{
//NSLog(@"writeBytes:%x(%d) length:%qu (writepos=%qu, buffer=[%qu,%qu])",bytes,bytes,length,writepos,bufstart,bufstart+buflen-1);
	xadPTR currbytes=bytes;
	xadSize currpos=writepos;
	xadSize currlength=length;

	// Buffer bytes.
	[self writeBytesToBuffer:bytes length:length];

	// Update XAD's data position.
	*newpos=writepos;

	// Discard all data if none of it is requested.
	if(currpos+currlength<=requeststart)
	{
//NSLog(@"discarding all data");
		return 0;
	}

	// Discard the beginning of the data if part of it is not requested.
	if(currpos<requeststart)
	{
		int unwanted=requeststart-currpos;
//NSLog(@"discarding start (%d)",unwanted);
		currbytes+=unwanted;
		currpos+=unwanted;
		currlength-=unwanted;
	}

	if(currlength<requestlength)
	{
//NSLog(@"writing all data and getting more");
		// All data will fit in the request, so copy it, and get more.
		memcpy(requestbuffer,currbytes,currlength);
		requestbuffer+=currlength;
		requeststart+=currlength;
		requestlength-=currlength;
		readpos+=currlength;
	}
	else
	{
//NSLog(@"writing part and waiting for request %x %x(%d) %qu",requestbuffer,currbytes,currbytes,requestlength);
		// We have more data than (or as much as) the request needs, so copy
		// as much as possible, then wait for a new request.
		memcpy(requestbuffer,currbytes,requestlength);
		currbytes+=requestlength;
		currpos+=requestlength;
		currlength-=requestlength;
		readpos+=requestlength;

		// We've fulfilled the request, wait for another one.
		[self waitForRequest];

		// Make unpacking fail if needed, so we can restart.
		if(resetwrite) return XADERR_UNKNOWN;
	}
	return 0;
}



-(xadUINT32)readStarted
{
//NSLog(@"readStarted");
	if(writefailed) return XADERR_INPUT;

	readpos=0;

	return 0;
}

-(void)readStopped
{
//NSLog(@"readStopped");
}

-(xadUINT32)readBytes:(xadPTR)bytes length:(xadSize)length newPosition:(xadSize *)newpos
{
//NSLog(@"readBytes:%x length:%qu (readpos=%qu, buffer=[%qu,%qu])",bytes,length,readpos,bufstart,bufstart+buflen-1);
	xadSize bufend=bufstart+buflen;

	if(readpos+length>fullsize) return XADERR_INPUT;

	// Update XAD's data position.
	*newpos=readpos+length;

	if(readpos>=bufstart&&readpos+length<=bufend)
	{
//NSLog(@"filling from buffer");
		// All of the requested data is available in the buffer, copy.
		[self readBytesFromBufferTo:bytes length:length];

		return 0;
	}
	else if(readpos>=bufstart&&readpos<bufend)
	{
//NSLog(@"requesting part");
		// The first part of the data is available in the buffer. Copy, and request the rest.
		int bufpart=bufend-readpos;
		[self readBytesFromBufferTo:bytes length:bufpart];
		requeststart=bufend;
		requestlength=length-bufpart;
		requestbuffer=bytes+bufpart;

		return [self issueRequestAndWait];
	}
	else
	{
//NSLog(@"requesting all");
		// None of the data is available, or only the last part. Request all of it.
		requeststart=readpos;
		requestlength=length;
		requestbuffer=bytes;

		// If the read position has moved to before the buffer, reset the write process.
		if(readpos<bufstart) resetwrite=YES;

		return [self issueRequestAndWait];
	}
}

-(xadUINT32)seekReadPosition:(xadSize)offset newPosition:(xadSize *)newpos
{
//NSLog(@"seekReadPosition:%qi newPosition:",offset);
	readpos+=offset;
	*newpos=readpos;

	// Make sure we are not seeking outside the available data.
	if(readpos<0||(readpos>=fullsize)) return XADERR_INPUT;
	else return 0;
}

-(xadSize)fullSize { return fullsize; }



-(xadUINT32)issueRequestAndWait
{
//NSLog(@"issueRequestAndWait1");
	[writelock unlock];
//NSLog(@"issueRequestAndWait2");
	[readlock lock];
//NSLog(@"issueRequestAndWait3 %d",writefailed);

	if(writefailed) return XADERR_INPUT;
	else return 0;
}

-(void)waitForRequest
{
//NSLog(@"waitForRequest1");
	[readlock unlock];
//NSLog(@"waitForRequest2");
	[writelock lock];
//NSLog(@"waitForRequest3");
}

-(void)readBytesFromBufferTo:(xadPTR)destbuf length:(xadSize)length
{
//NSLog(@"readBytesFromBufferTo:%x length:%qu",destbuf,length);
	int start=readpos%bufsize;
	int laterhalf=bufsize-start;

	if(length<laterhalf) memcpy(destbuf,buf+start,length);
	else
	{
		memcpy(destbuf,buf+start,laterhalf);
		memcpy(destbuf+laterhalf,buf,length-laterhalf);
	}

	readpos+=length;
}

-(void)writeBytesToBuffer:(xadPTR)bytes length:(xadSize)length
{
//NSLog(@"writeBytesToBuffer:%x length:%qu [%qu,%qu]",bytes,length,bufstart,bufstart+buflen-1);
	if(length>bufsize)
	{
		int skip=length-bufsize;
		bytes+=skip;
		writepos+=skip;
		length=bufsize;
	}

	int start=writepos%bufsize;
	int laterhalf=bufsize-start;

	if(length<laterhalf) memcpy(buf+start,bytes,length);
	else
	{
		memcpy(buf+start,bytes,laterhalf);
		memcpy(buf,bytes+laterhalf,length-laterhalf);
	}

	writepos+=length;
	buflen+=length;
	if(buflen>bufsize)
	{
		bufstart+=buflen-bufsize;
		buflen=bufsize;
	}

//NSLog(@"new size: [%qu,%qu]",bufstart,bufstart+buflen-1);
}

@end



static xadUINT32 out_func(struct Hook *hook,xadPTR object,struct xadHookParam *param)
{
//NSLog(@"out_func");
	XADArchivePipe *pipe=(XADArchivePipe *)hook->h_Data;

	switch(param->xhp_Command)
	{
		case XADHC_INIT:
			return [pipe writeStarted];

		case XADHC_SEEK:
			return XADERR_NOTSUPPORTED;

		case XADHC_WRITE:
			return param->xhp_DataPos=[pipe writeBytes:param->xhp_BufferPtr length:param->xhp_BufferSize newPosition:&param->xhp_DataPos];

		case XADHC_ABORT:
		case XADHC_FREE:
			[pipe writeStopped];
			return 0;

 		default:
			return XADERR_NOTSUPPORTED;
	}
}


static xadUINT32 in_func(struct Hook *hook,xadPTR object,struct xadHookParam *param)
{
//NSLog(@"in_func");
	XADArchivePipe *pipe=(XADArchivePipe *)hook->h_Data;

	switch(param->xhp_Command)
	{
		case XADHC_INIT:
			[pipe readStarted];
			return 0;

		case XADHC_SEEK:
			return [pipe seekReadPosition:param->xhp_CommandData newPosition:&param->xhp_DataPos];

		case XADHC_READ:
			return [pipe readBytes:param->xhp_BufferPtr length:param->xhp_BufferSize newPosition:&param->xhp_DataPos];

		case XADHC_FULLSIZE:
			param->xhp_CommandData=[pipe fullSize];
			return 0;

		case XADHC_FREE:
//NSLog(@"free in hook");
			return 0;

 		default:
			return XADERR_NOTSUPPORTED;
	}
}
