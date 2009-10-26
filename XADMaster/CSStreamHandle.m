#import "CSStreamHandle.h"

@implementation CSStreamHandle

-(id)initWithName:(NSString *)descname
{
	return [self initWithName:descname length:CSHandleMaxLength];
}

-(id)initWithName:(NSString *)descname length:(off_t)length
{
	if(self=[super initWithName:descname])
	{
		streampos=0;
		streamlength=length;
		endofstream=NO;
		needsreset=YES;
		nextstreambyte=-1;

		input=NULL;
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength bufferSize:4096];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [self initWithHandle:handle length:length bufferSize:4096];
}

-(id)initWithHandle:(CSHandle *)handle bufferSize:(int)buffersize
{
	return [self initWithHandle:handle length:CSHandleMaxLength bufferSize:buffersize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length bufferSize:(int)buffersize;
{
	if(self=[super initWithName:[handle name]])
	{
		streampos=0;
		streamlength=length;
		endofstream=NO;
		needsreset=YES;
		nextstreambyte=-1;

		input=CSInputBufferAlloc(handle,buffersize);
	}
	return self;
}

-(id)initAsCopyOf:(CSStreamHandle *)other
{
	[self _raiseNotSupported:_cmd];
	return nil;
}

-(void)dealloc
{
	CSInputBufferFree(input);
	[super dealloc];
}



-(off_t)fileSize { return streamlength; }

-(off_t)offsetInFile { return streampos; }

-(BOOL)atEndOfFile
{
	if(needsreset) { [self resetStream]; needsreset=NO; }

	if(endofstream) return YES;
	if(streampos==streamlength) return YES;
	if(nextstreambyte>=0) return NO;

	uint8_t b[1];
	@try
	{
		if([self streamAtMost:1 toBuffer:b]==1)
		{
			nextstreambyte=b[0];
			return NO;
		}
	}
	@catch(id e) {}

	endofstream=YES;
	return YES;
}

-(void)seekToFileOffset:(off_t)offs
{
	if(needsreset) { [self resetStream]; needsreset=NO; }

	if(offs==streampos) return;
	if(offs>streamlength) [self _raiseEOF];
	if(nextstreambyte>=0)
	{
		nextstreambyte=-1;
		streampos+=1;
		if(offs==streampos) return;
	}

	if(offs<streampos)
	{
		streampos=0;
		endofstream=NO;
		//nextstreambyte=-1;
		if(input) CSInputRestart(input);
		[self resetStream];
	}

	if(offs==0) return;

	[self readAndDiscardBytes:offs-streampos];
}

-(void)seekToEndOfFile { [self readAndDiscardAtMost:CSHandleMaxLength]; }

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(needsreset) { [self resetStream]; needsreset=NO; }

	if(endofstream) return 0;
	if(streampos+num>streamlength) num=streamlength-streampos;
	if(!num) return 0;

	int offs=0;
	if(nextstreambyte>=0)
	{
		((uint8_t *)buffer)[0]=nextstreambyte;
		streampos++;
		nextstreambyte=-1;
		offs=1;
	}

	int actual=[self streamAtMost:num-offs toBuffer:((uint8_t *)buffer)+offs];

	if(actual==0) endofstream=YES;

	streampos+=actual;

	return actual+offs;
}

-(void)endStream
{
	endofstream=YES;
}

-(void)resetStream {}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer { return 0; }

@end
