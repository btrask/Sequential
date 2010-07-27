#import "../XADMaster/CSBlockStreamHandle.h"
#import "../XADMaster/XADRARParser.h"
#import "RARUnpacker.h"

@interface XADRAROfficialHandle:CSBlockStreamHandle
{
	XADRARParser *parser;
	NSArray *parts;
	int method;

	RARUnpacker *unpacker;
	CSHandle *currhandle;
	int part;
	off_t currsize,bytesdone;
}

-(id)initWithRARParser:(XADRARParser *)parent version:(int)version parts:(NSArray *)partarray;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;
-(void)constructInputHandle;

-(int)provideInput:(int)length buffer:(void *)buffer;

@end
