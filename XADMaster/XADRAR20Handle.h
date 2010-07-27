#import "XADFastLZSSHandle.h"
#import "XADRARParser.h"
#import "XADPrefixCode.h"
#import "RARAudioDecoder.h"

@interface XADRAR20Handle:XADFastLZSSHandle
{
	XADRARParser *parser;

	NSArray *parts;
	int part;
	off_t endpos;

	XADPrefixCode *maincode,*offsetcode,*lengthcode;
	XADPrefixCode *audiocode[4];

	int lastoffset,lastlength;
	int oldoffset[4],oldoffsetindex;

	BOOL audioblock;
	int channel,channeldelta,numchannels;
	RAR20AudioState audiostate[4];

	int lengthtable[1028];
}

-(id)initWithRARParser:(XADRARParser *)parent parts:(NSArray *)partarray;
-(void)dealloc;

-(void)resetLZSSHandle;
-(void)startNextPart;
-(void)expandFromPosition:(off_t)pos;
-(void)allocAndParseCodes;

@end
