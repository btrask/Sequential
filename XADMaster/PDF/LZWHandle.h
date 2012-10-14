#import "../CSByteStreamHandle.h"
#import "../LZW.h"

extern NSString *LZWInvalidCodeException;

@interface LZWHandle:CSByteStreamHandle
{
	BOOL early;

	LZW *lzw;
	int symbolsize;

	int currbyte;
	uint8_t buffer[4096];
}

-(id)initWithHandle:(CSHandle *)handle earlyChange:(BOOL)earlychange;

-(void)clearTable;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

@end
