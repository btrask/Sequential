#import "XADRARInputHandle.h"
#import "XADException.h"
#import "CRC.h"

@implementation XADRARInputHandle

-(id)initWithRARParser:(XADRARParser *)parent parts:(NSArray *)partarray
{
	off_t totallength=0;
	NSEnumerator *enumerator=[partarray objectEnumerator];
	NSDictionary *dict;
	while((dict=[enumerator nextObject]))
	{
		totallength+=[[dict objectForKey:@"InputLength"] longLongValue];
	}

	if((self=[super initWithName:[parent filename] length:totallength]))
	{
		parser=parent;
		parts=[partarray retain];
	}
	return self;
}

-(void)dealloc
{
	[parts release];
	[super dealloc];
}

-(void)resetStream
{
	part=0;
	partend=0;

	[self startNextPart];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	CSHandle *fh=[parser handle];

	uint8_t *bytebuf=buffer;
	int total=0;
	while(total<num)
	{
		if(streampos+total>=partend) [self startNextPart];

		int numbytes=num-total;
		if(streampos+total+numbytes>=partend) numbytes=partend-streampos-total;

		[fh readBytes:numbytes toBuffer:&bytebuf[total]];

		crc=XADCalculateCRC(crc,&bytebuf[total],numbytes,XADCRCTable_edb88320);

		total+=numbytes;

		if(streampos+total>=partend)
		if(partend!=streamlength)
		if(correctcrc!=0xffffffff)
		if(~crc!=correctcrc)
		[XADException raiseChecksumException];
	}

	return num;
}

-(void)startNextPart
{
	if(part>=[parts count]) [XADException raiseInputException];
	NSDictionary *dict=[parts objectAtIndex:part];
	part++;

	off_t offset=[[dict objectForKey:@"Offset"] longLongValue];
	off_t length=[[dict objectForKey:@"InputLength"] longLongValue];

	[[parser handle] seekToFileOffset:offset];
	partend+=length;

	crc=0xffffffff;
	correctcrc=[[dict objectForKey:@"CRC32"] unsignedIntValue];
}

@end

