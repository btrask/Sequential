#import "XADDeltaHandle.h"

@implementation XADDeltaHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength deltaDistance:1];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [self initWithHandle:handle length:length deltaDistance:1];
}

-(id)initWithHandle:(CSHandle *)handle deltaDistance:(int)deltadistance
{
	return [self initWithHandle:handle length:CSHandleMaxLength deltaDistance:deltadistance];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length deltaDistance:(int)deltadistance
{
	if((self=[super initWithHandle:handle length:length]))
	{
		distance=deltadistance;
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:propertydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata
{
	int deltadistance=1;

	if(propertydata&&[propertydata length]>=1)
	deltadistance=((uint8_t *)[propertydata bytes])[0]+1;

	return [self initWithHandle:handle length:length deltaDistance:deltadistance];
}

-(void)resetByteStream
{
	memset(deltabuffer,0,sizeof(deltabuffer));
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(CSInputAtEOF(input)) CSByteStreamEOF(self);

	uint8_t b=CSInputNextByte(input);
	uint8_t old=deltabuffer[(pos-distance+0x100)&0xff];
	uint8_t new=b+old;

	deltabuffer[pos&0xff]=new;
	return new;
}

@end
