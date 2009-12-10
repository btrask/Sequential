#import "XAD7ZipFilterHandles.h"

@implementation XAD7ZipDeltaHandle

-(id)initWithHandle:(CSHandle *)handle propertyData:(NSData *)propertydata
{
	return [self initWithHandle:handle length:CSHandleMaxLength propertyData:propertydata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length propertyData:(NSData *)propertydata
{
	if(self=[super initWithHandle:handle length:length])
	{
		if(propertydata&&[propertydata length]>=1) distance=((uint8_t *)[propertydata bytes])[0]+1;
		else distance=1;
	}
	return self;
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
