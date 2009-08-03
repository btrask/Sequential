#import "XADCompactProRLEHandle.h"

@implementation XADCompactProRLEHandle:CSByteStreamHandle

-(void)resetByteStream
{
	saved=0;
	repeat=0;
	halfescaped=NO;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
//NSLog(@"rle %d %d",(int)pos,(int)CSInputBufferOffset(input));
	if(repeat)
	{
		repeat--;
		return saved;
	}

	int byte;
	if(halfescaped)
	{
		byte=0x81;
		halfescaped=NO;
	}
	else byte=CSInputNextByte(input);

	if(byte==0x81)
	{
		byte=CSInputNextByte(input);
		if(byte==0x82)
		{
			byte=CSInputNextByte(input);
			if(byte!=0)
			{
				repeat=byte-2; // ?
				return saved;
			}
			else
			{
				repeat=1;
				saved=0x82;
				return 0x81;
			}
		}
		else
		{
			if(byte==0x81)
			{
				halfescaped=YES;
				return saved=0x81;
			}
			else
			{
				repeat=1;
				saved=byte;
				return 0x81;
			} 
		}
	}
	else return saved=byte;
}

@end

