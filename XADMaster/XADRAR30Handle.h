#import "CSBlockStreamHandle.h"
#import "XADRARParser.h"
#import "LZSS.h"
#import "XADPrefixCode.h"
#import "PPMdVariantH.h"
#import "PPMdSubAllocatorVariantH.h"
#import "XADRARVirtualMachine.h"

@interface XADRAR30Handle:CSBlockStreamHandle
{
	XADRARParser *parser;

	NSArray *parts;
	int part;
	off_t lastend;
	BOOL startnewpart,startnewtable;

	LZSS lzss;

	XADPrefixCode *maincode,*offsetcode,*lowoffsetcode,*lengthcode;

	int lastoffset,lastlength;
	int oldoffset[4];
	int lastlowoffset,numlowoffsetrepeats;

	BOOL ppmblock;
	PPMdModelVariantH ppmd;
	PPMdSubAllocatorVariantH *alloc;
	int ppmescape;

	XADRARVirtualMachine *vm;
	NSMutableArray *filtercode,*stack;
	off_t filterstart;
	int lastfilternum;
	int oldfilterlength[1024],usagecount[1024];

	int lengthtable[299+60+17+28];
}

-(id)initWithRARParser:(XADRARParser *)parent parts:(NSArray *)partarray;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;
-(off_t)expandToPosition:(off_t)end;
-(void)allocAndParseCodes;

-(void)readFilterFromInput;
-(void)readFilterFromPPMd;
-(void)parseFilter:(const uint8_t *)bytes length:(int)length flags:(int)flags;

@end
