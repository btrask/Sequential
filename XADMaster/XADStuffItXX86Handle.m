#import "XADStuffItXX86Handle.h"
#import "XADException.h"

@implementation XADStuffItXX86Handle

-(void)resetByteStream
{
	lasthit=-6;
	bitfield=0;

	numbufferbytes=0;
	currbufferbyte=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(currbufferbyte<numbufferbytes) return buffer[currbufferbyte++];

	if(CSInputAtEOF(input)) CSByteStreamEOF(self);

	uint8_t b=CSInputNextByte(input);

	if(b==0xe8||b==0xe9)
	{
		int dist=pos-lasthit;
		lasthit=pos;

		if(dist>5)
		{
			bitfield=0;
		}
		else
		{
			for(int i=0;i<dist;i++)
			{
				bitfield=(bitfield&0x77)<<1;
			}
		}

		// Read offset into buffer.
		for(int i=0;i<4;i++)
		{
/*			if(CSInputAtEOF(input))
			{
				currbufferbyte=0;
				numbufferbytes=i;
				return b;
			}*/

			buffer[i]=CSInputPeekByte(input,i);
		}

		static const BOOL table[8]={YES,YES,YES,NO,YES,NO,NO,NO};

		if(buffer[3]==0x00 || buffer[3]==0xff)
		{
			if(table[(bitfield>>1)&0x07] && (bitfield>>1)<=0x0f)
			{
				int32_t absaddress=CSInt32LE(buffer);
				int32_t reladdress;

				for(;;)
				{
					reladdress=absaddress-pos-6;
					if(bitfield==0) break;

					static const int shifts[8]={24,16,8,8,0,0,0,0};
					int shift=shifts[bitfield>>1];
					int something=(reladdress>>shift)&0xff;
					if(something!=0&&something!=0xff) break;
					absaddress=reladdress^((1<<(shift+8))-1);
				}

				reladdress&=0x1ffffff;
				if(reladdress>=0x1000000) reladdress|=0xff000000;

				CSSetInt32LE(buffer,reladdress);
				currbufferbyte=0;
				numbufferbytes=4;

				bitfield=0;

				CSInputSkipBytes(input,4);
			}
			else
			{
				bitfield|=0x11;
			}
		}
		else
		{
			bitfield|=0x01;
		}
	}

	return b;
}

@end
