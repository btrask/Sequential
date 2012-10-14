#import "XADRLE90Handle.h"
#import "XADException.h"

@implementation XADRLE90Handle

-(void)resetByteStream
{
	repeatedbyte=count=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(count)
	{
		count--;
		return repeatedbyte;
	}
	else
	{
		if(CSInputAtEOF(input)) CSByteStreamEOF(self);

		uint8_t b=CSInputNextByte(input);

		if(b!=0x90) return repeatedbyte=b;
		else
		{
			uint8_t c=CSInputNextByte(input);
			if(c==0) return repeatedbyte=0x90;
			else
			{
				if(c==1) [XADException raiseDecrunchException];
				count=c-2;
				return repeatedbyte;
			}
		}
	}
}

@end
