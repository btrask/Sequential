#import "CSSubHandle.h"

@implementation CSSubHandle

-(id)initWithHandle:(CSHandle *)handle from:(off_t)from length:(off_t)length
{
	if(self=[super initWithName:[NSString stringWithFormat:@"%@ (Subrange from %qd, length %qd)",[handle name],from,length]])
	{
		parent=[handle retain];
		start=from;
		end=from+length;

		[parent seekToFileOffset:start];

		if(parent) return self;

		[self release];
	}
	return nil;
}

-(id)initAsCopyOf:(CSSubHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		parent=[other->parent copy];
		start=other->start;
		end=other->end;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}

-(off_t)fileSize
{
	return end-start;
/*	off_t parentsize=[parent fileSize];
	if(parentsize>end) return end-start;
	else if(parentsize<start) return 0;
	else return parentsize-start;*/
}

-(off_t)offsetInFile
{
	return [parent offsetInFile]-start;
}

-(BOOL)atEndOfFile
{
	return [parent offsetInFile]==end||[parent atEndOfFile];
}

-(void)seekToFileOffset:(off_t)offs
{
	if(offs<0) [self _raiseNotSupported:_cmd];
	if(offs>end) [self _raiseEOF];
	[parent seekToFileOffset:offs+start];
}

-(void)seekToEndOfFile
{
//	@try
	{
		[parent seekToFileOffset:end];
	}
/*	@catch(NSException *e)
	{
		if([[e name] isEqual:@"CSEndOfFileException"]) [parent seekToEndOfFile];
		else @throw;
	}*/
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	off_t curr=[parent offsetInFile];
	if(curr+num>end) num=end-curr;
	if(num<=0) return 0;
	else return [parent readAtMost:num toBuffer:buffer];
}

@end
