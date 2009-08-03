#import "CSBlockStreamHandle.h"
#import "XADRARParser.h"
#import "RARUnpacker.h"

@interface XADRARHandle:CSBlockStreamHandle
{
	XADRARParser *parser;
	NSArray *parts;
	int method;

	RARUnpacker *unpacker;
	CSHandle *currhandle;
	int part;
	off_t currsize,bytesdone;
}

-(id)initWithRARParser:(XADRARParser *)parent version:(int)version skipOffset:(off_t)skipoffset
inputLength:(off_t)inputlength outputLength:(off_t)outputlength encrypted:(BOOL)encrypted salt:(NSData *)salt;
-(id)initWithRARParser:(XADRARParser *)parent version:(int)version parts:(NSArray *)partarray;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;
-(void)constructInputHandle;

-(int)provideInput:(int)length buffer:(void *)buffer;

@end
