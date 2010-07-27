#import "CSMultiHandle.h"

NSString *CSSizeOfSegmentUnknownException=@"CSSizeOfSegmentUnknownException";

@implementation CSMultiHandle

+(CSMultiHandle *)multiHandleWithHandleArray:(NSArray *)handlearray
{
	if(!handlearray) return nil;
	int count=[handlearray count];
	if(count==0) return nil;
	else if(count==1) return [handlearray objectAtIndex:0];
	else return [[[self alloc] initWithHandles:handlearray] autorelease];
}

+(CSMultiHandle *)multiHandleWithHandles:(CSHandle *)firsthandle,...
{
	if(!firsthandle) return nil;

	NSMutableArray *array=[NSMutableArray arrayWithObject:firsthandle];
	CSHandle *handle;
	va_list va;

	va_start(va,firsthandle);
	while(handle=va_arg(va,CSHandle *)) [array addObject:handle];
	va_end(va);

	return [self multiHandleWithHandleArray:array];
}


-(id)initWithHandles:(NSArray *)handlearray
{
	if(self=[super initWithName:[NSString stringWithFormat:@"%@, and %d more combined",[[handlearray objectAtIndex:0] name],[handlearray count]-1]])
	{
		handles=[handlearray copy];
		currhandle=0;
	}
	return self;
}

-(id)initAsCopyOf:(CSMultiHandle *)other
{
	if(self=[super initAsCopyOf:other])
	{
		NSMutableArray *handlearray=[NSMutableArray arrayWithCapacity:[other->handles count]];
		NSEnumerator *enumerator=[other->handles objectEnumerator];
		CSHandle *handle;
		while(handle=[enumerator nextObject]) [handlearray addObject:[[handle copy] autorelease]];

		handles=[[NSArray arrayWithArray:handlearray] retain];
		currhandle=other->currhandle;
	}
	return self;
}

-(void)dealloc
{
	[handles release];
	[super dealloc];
}

-(NSArray *)handles { return handles; }

-(CSHandle *)currentHandle { return [handles objectAtIndex:currhandle]; }

-(off_t)fileSize
{
	off_t size=0;
	int count=[handles count];
	for(int i=0;i<count-1;i++)
	{
		off_t segsize=[(CSHandle *)[handles objectAtIndex:i] fileSize];
		if(segsize==CSHandleMaxLength) [self _raiseSizeUnknownForSegment:i];
		size+=segsize;
	}

	off_t segsize=[(CSHandle *)[handles lastObject] fileSize];
	if(segsize==CSHandleMaxLength) return CSHandleMaxLength;
	else return size+segsize;
}

-(off_t)offsetInFile
{
	off_t offs=0;
	for(int i=0;i<currhandle;i++)
	{
		off_t segsize=[(CSHandle *)[handles objectAtIndex:i] fileSize];
		if(segsize==CSHandleMaxLength) [self _raiseSizeUnknownForSegment:i];
		offs+=segsize;
	}
	return offs+[[handles objectAtIndex:currhandle] offsetInFile];
}

-(BOOL)atEndOfFile
{
	return currhandle==[handles count]-1&&[[handles objectAtIndex:currhandle] atEndOfFile];
}

-(void)seekToFileOffset:(off_t)offs
{
	int count=[handles count];

	if(offs==0)
	{
		currhandle=0;
	}
	else
	{
		for(currhandle=0;currhandle<count-1;currhandle++)
		{
			off_t segsize=[(CSHandle *)[handles objectAtIndex:currhandle] fileSize];
			if(segsize==CSHandleMaxLength) [self _raiseSizeUnknownForSegment:currhandle];
			if(offs<segsize) break;
			offs-=segsize;
		}
	}

	[(CSHandle *)[handles objectAtIndex:currhandle] seekToFileOffset:offs];
}

-(void)seekToEndOfFile
{
	currhandle=[handles count]-1;
	[(CSHandle *)[handles objectAtIndex:currhandle] seekToEndOfFile];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	off_t total=0;
	for(;;)
	{
		off_t actual=[[handles objectAtIndex:currhandle] readAtMost:num-total toBuffer:((char *)buffer)+total];
		total+=actual;
		if(total==num||currhandle==[handles count]-1) return total;
		currhandle++;
		[(CSHandle *)[handles objectAtIndex:currhandle] seekToFileOffset:0];
	}
}

-(void)_raiseSizeUnknownForSegment:(int)i
{
	[NSException raise:CSSizeOfSegmentUnknownException
	format:@"Size of CSMultiHandle segment %d (%@) unknown.",i,[handles objectAtIndex:i]];
}

@end
