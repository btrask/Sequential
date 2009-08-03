#import "XADCompressHandle.h"
#import "XADException.h"
#import "SystemSpecific.h"


@implementation XADCompressHandle

-(id)initWithHandle:(CSHandle *)handle flags:(int)compressflags
{
	return [self initWithHandle:handle length:CSHandleMaxLength flags:compressflags];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length flags:(int)compressflags
{
	if(self=[super initWithHandle:handle length:length])
	{
		blockmode=compressflags&0x80;
		lzw=AllocLZW(1<<(compressflags&0x1f),blockmode?1:0);
		bufsize=1024;
		buffer=malloc(bufsize);
	}
	return self;
}

-(void)dealloc
{
	FreeLZW(lzw);
	free(buffer);
	[super dealloc];
}

-(void)resetByteStream
{
	ClearLZWTable(lzw);
	symbolsize=9;
	symbolcounter=0;
	currbyte=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!currbyte)
	{
		int symbol;
		for(;;)
		{
			if(CSInputAtEOF(input)) CSByteStreamEOF(self);

			symbol=CSInputNextBitStringLE(input,symbolsize);
			symbolcounter++;
			if(symbol==256&&blockmode)
			{
				// Skip garbage data after a clear. God damn, this is dumb.
				CSInputSkipBits(input,symbolsize*(8-symbolcounter%8));
				
				ClearLZWTable(lzw);
				symbolsize=9;
				symbolcounter=0;
			}
			else break;
		}

		if(NextLZWSymbol(lzw,symbol)==LZWInvalidCodeError)
		[XADException raiseDecrunchException];

		currbyte=LZWOutputLength(lzw);
		if(currbyte>bufsize) buffer=reallocf(buffer,bufsize*=2);

		LZWReverseOutputToBuffer(lzw,buffer);

		int numsymbols=LZWSymbolCount(lzw);
		if(!LZWSymbolListFull(lzw))
		if((numsymbols&numsymbols-1)==0) symbolsize++;
	}

	return buffer[--currbyte];
}

@end
