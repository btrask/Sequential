#import "CSZlibHandle.h"



NSString *CSZlibException=@"CSZlibException";



@implementation CSZlibHandle


+(CSZlibHandle *)zlibHandleWithHandle:(CSHandle *)handle
{
	return [[[CSZlibHandle alloc] initWithHandle:handle length:CSHandleMaxLength header:YES name:[handle name]] autorelease];
}

+(CSZlibHandle *)zlibHandleWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [[[CSZlibHandle alloc] initWithHandle:handle length:length header:YES name:[handle name]] autorelease];
}

+(CSZlibHandle *)deflateHandleWithHandle:(CSHandle *)handle
{
	return [[[CSZlibHandle alloc] initWithHandle:handle length:CSHandleMaxLength header:NO name:[handle name]] autorelease];
}

+(CSZlibHandle *)deflateHandleWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [[[CSZlibHandle alloc] initWithHandle:handle length:length header:NO name:[handle name]] autorelease];
}




-(id)initWithHandle:(CSHandle *)handle length:(off_t)length header:(BOOL)header name:(NSString *)descname
{
	if(self=[super initWithName:descname length:length])
	{
		parent=[handle retain];
		startoffs=[parent offsetInFile];
		inited=YES;
		seekback=NO;

		if(header) inflateInit(&zs);
		else inflateInit2(&zs,-MAX_WBITS);
	}
	return self;
}

-(id)initAsCopyOf:(CSZlibHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		parent=[other->parent copy];
		startoffs=other->startoffs;
		inited=NO;
		seekback=other->seekback;

		memset(&zs,0,sizeof(zs));

		if(inflateCopy(&zs,&other->zs)==Z_OK)
		{
			zs.next_in=inbuffer;
			memcpy(inbuffer,other->zs.next_in,zs.avail_in);

			inited=YES;
			return self;
		}

		[self release];
	}
	return nil;
}

-(void)dealloc
{
	if(inited) inflateEnd(&zs);
	[parent release];

	[super dealloc];
}

-(void)setSeekBackAtEOF:(BOOL)seekateof { seekback=seekateof; }

-(void)setEndStreamAtInputEOF:(BOOL)endateof { endstreamateof=endateof; } // Hack for NSIS's broken zlib usage

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];
	zs.avail_in=0;
	inflateReset(&zs);
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	zs.next_out=buffer;
	zs.avail_out=num;

	while(zs.avail_out)
	{
		if(!zs.avail_in)
		{
			zs.avail_in=[parent readAtMost:sizeof(inbuffer) toBuffer:inbuffer];
			zs.next_in=(void *)inbuffer;

			if(!zs.avail_in)
			{
				if(endstreamateof)
				{
					[self endStream];
					return num-zs.avail_out;
				}
				else [parent _raiseEOF];
			}
		}

		int err=inflate(&zs,0);
		if(err==Z_STREAM_END)
		{
			if(seekback) [parent skipBytes:-(off_t)zs.avail_in];
			[self endStream];
			break;
		}
		else if(err!=Z_OK) [self _raiseZlib];
	}

	return num-zs.avail_out;
}

-(void)_raiseZlib
{
	[NSException raise:CSZlibException
	format:@"Zlib error while attepting to read from \"%@\": %s.",name,zs.msg];
}

@end
