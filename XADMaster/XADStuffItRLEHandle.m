#import "XADStuffItRLEHandle.h"
#import "XADException.h"

@implementation XADStuffItRLEHandle

-(void)resetByteStream
{
	byte=count=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(count)
	{
		count--;
		return byte;
	}
	else
	{
		uint8_t b=CSInputNextByte(input);

		if(b!=0x90) return byte=b;
		else
		{
			uint8_t c=CSInputNextByte(input);
			if(c==0) return byte=0x90;
			else
			{
				if(c==1) [XADException raiseDecrunchException];
				count=c-2;
				return byte;
			}
		}
	}
}

@end
