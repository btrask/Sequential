#import "XADZipShrinkHandle.h"
#import "XADException.h"


@implementation XADZipShrinkHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithHandle:handle length:length]))
	{
		lzw=AllocLZW(8192,1);
	}
	return self;
}

-(void)dealloc
{
	FreeLZW(lzw);
	[super dealloc];
}

-(void)resetByteStream
{
	ClearLZWTable(lzw);
	symbolsize=9;
	currbyte=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!currbyte)
	{
		int symbol;
		for(;;)
		{
			symbol=CSInputNextBitStringLE(input,symbolsize);
			if(symbol==256)
			{
				int next=CSInputNextBitStringLE(input,symbolsize);
				if(next==1)
				{
					symbolsize++;
					if(symbolsize>13) [XADException raiseDecrunchException];
				}
				else if(next==2) ClearLZWTable(lzw);
			}
			else break;
		}

		if(NextLZWSymbol(lzw,symbol)!=LZWNoError) [XADException raiseDecrunchException];
		currbyte=LZWReverseOutputToBuffer(lzw,buffer);
	}

	return buffer[--currbyte];
}

@end
