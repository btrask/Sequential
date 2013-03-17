#import "LZWHandle.h"

NSString *LZWInvalidCodeException=@"LZWInvalidCodeException";


@implementation LZWHandle

-(id)initWithHandle:(CSHandle *)handle earlyChange:(BOOL)earlychange
{
	if(self=[super initWithHandle:handle])
	{
		early=earlychange;
		lzw=AllocLZW(4096+1,2);
	}
	return self;
}

-(void)dealloc
{
	FreeLZW(lzw);
	[super dealloc];
}

-(void)clearTable
{
	ClearLZWTable(lzw);
	symbolsize=9;
	currbyte=0;
}

-(void)resetByteStream
{
	[self clearTable];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!currbyte)
	{
		int symbol;
		for(;;)
		{
			symbol=CSInputNextBitString(input,symbolsize);
			if(symbol==256) [self clearTable];
			else break;
		}

		if(symbol==257) CSByteStreamEOF(self);

		int err=NextLZWSymbol(lzw,symbol);
		if(err!=LZWNoError) [NSException raise:LZWInvalidCodeException format:@"Invalid code in LZW stream (error code %d)",err];
		currbyte=LZWReverseOutputToBuffer(lzw,buffer);

		int offs=early?1:0;
		int numsymbols=LZWSymbolCount(lzw);
		if(numsymbols==512-offs) symbolsize=10;
		else if(numsymbols==1024-offs) symbolsize=11;
		else if(numsymbols==2048-offs) symbolsize=12;
	}

	return buffer[--currbyte];
}

@end

