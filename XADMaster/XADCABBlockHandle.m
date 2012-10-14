#import "XADCABBlockHandle.h"
#import "XADException.h"

@implementation XADCABBlockHandle

-(id)initWithBlockReader:(XADCABBlockReader *)blockreader
{
	if((self=[super initWithName:[[blockreader handle] name] length:[blockreader uncompressedLength]]))
	{
		blocks=[blockreader retain];
	}
	return self;
}

-(void)dealloc
{
	[blocks release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[blocks restart];
	[self resetCABBlockHandle];
}

-(int)produceBlockAtOffset:(off_t)pos
{
	int complen,uncomplen;
	if([blocks readNextBlockToBuffer:inbuffer compressedLength:&complen
	uncompressedLength:&uncomplen]) [self endBlockStream];

	return [self produceCABBlockWithInputBuffer:inbuffer length:complen atOffset:pos length:uncomplen];
}

-(void)resetCABBlockHandle {}

-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength { return 0; }

@end



@implementation XADCABCopyHandle

-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength
{
	[self setBlockPointer:buffer];
	return length;
}

@end
