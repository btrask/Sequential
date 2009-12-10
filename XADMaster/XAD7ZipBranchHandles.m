#import "XAD7ZipBranchHandles.h"

#if !__LP64__
#define _LZMA_UINT32_IS_ULONG
#endif

#import "lzma/Bra.h"

@implementation XAD7ZipBranchHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:nil];
}

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:propertydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [self initWithHandle:handle length:length propertyData:nil];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata
{
	if(self=[super initWithName:[handle name] length:length])
	{
		parent=[handle retain];
		startoffs=[handle offsetInFile];

		if(propertydata&&[propertydata length]>=4) baseoffset=CSUInt32LE([propertydata bytes]);
		else baseoffset=0;

		[self setBlockPointer:inbuffer];
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
	leftoverstart=leftoverlength=0;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	memmove(inbuffer,inbuffer+leftoverstart,leftoverlength);

	int bytesread=[parent readAtMost:sizeof(inbuffer)-leftoverlength toBuffer:inbuffer+leftoverlength];
	if(bytesread==0)
	{
		[self endBlockStream];

		if(leftoverlength) return leftoverlength;
		else return 0;
	}

	int processed=[self decodeBlock:inbuffer length:bytesread+leftoverlength offset:pos+baseoffset];
	leftoverstart=processed;
	leftoverlength=bytesread+leftoverlength-processed;

	return processed;
}

-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos { return 0; }

@end



@implementation XAD7ZipBCJHandle
-(void)resetBlockStream
{
	[super resetBlockStream];
	x86_Convert_Init(state);
}
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return x86_Convert(block,length,pos,(UInt32 *)&state,0); }
@end

@implementation XAD7ZipPPCHandle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return PPC_Convert(block,length,pos,0); }
@end

@implementation XAD7ZipIA64Handle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return IA64_Convert(block,length,pos,0); }
@end

@implementation XAD7ZipARMHandle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return ARM_Convert(block,length,pos,0); }
@end

@implementation XAD7ZipThumbHandle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return ARMT_Convert(block,length,pos,0); }
@end

@implementation XAD7ZipSPARCHandle
-(int)decodeBlock:(uint8_t *)block length:(int)length offset:(off_t)pos
{ return SPARC_Convert(block,length,pos,0); }
@end
