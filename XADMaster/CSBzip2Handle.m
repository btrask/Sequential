#import "CSBzip2Handle.h"

NSString *CSBzip2Exception=@"CSBzip2Exception";

@implementation CSBzip2Handle

+(CSBzip2Handle *)bzip2HandleWithHandle:(CSHandle *)handle
{
	return [[[self alloc] initWithHandle:handle length:CSHandleMaxLength name:[handle name]] autorelease];
}

+(CSBzip2Handle *)bzip2HandleWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [[[self alloc] initWithHandle:handle length:length name:[handle name]] autorelease];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length name:(NSString *)descname
{
	if(self=[super initWithName:descname])
	{
		parent=[handle retain];
		startoffs=[parent offsetInFile];
		inited=NO;
	}
	return self;
}

-(void)dealloc
{
	if(inited) BZ2_bzDecompressEnd(&bzs);
	[parent release];

	[super dealloc];
}

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];

	if(inited) BZ2_bzDecompressEnd(&bzs);
	memset(&bzs,0,sizeof(bzs));
	BZ2_bzDecompressInit(&bzs,0,0);
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	bzs.next_out=buffer;
	bzs.avail_out=num;

	while(bzs.avail_out)
	{
		if(!bzs.avail_in)
		{
			bzs.avail_in=[parent readAtMost:sizeof(inbuffer) toBuffer:inbuffer];
			bzs.next_in=(void *)inbuffer;

			if(!bzs.avail_in) [parent _raiseEOF];
		}

		int err=BZ2_bzDecompress(&bzs);
		if(err==BZ_STREAM_END)
		{
			[self endStream];
			break;
		}
		else if(err!=BZ_OK) [self _raiseBzip2:err];
	}

	return num-bzs.avail_out;
}

-(void)_raiseBzip2:(int)error
{
	[NSException raise:CSBzip2Exception
	format:@"Bzlib error while attepting to read from \"%@\": %d.",name,error];
}

@end

