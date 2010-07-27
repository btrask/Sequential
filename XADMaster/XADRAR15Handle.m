#import "XADRAR15Handle.h"
#import "XADException.h"

static BOOL GetFlagBit(XADRAR15Handle *self);
static void EmitLiteral(XADRAR15Handle *self,off_t *posptr);
static void EmitLongMatch(XADRAR15Handle *self,off_t *posptr);
static void EmitShortMatch(XADRAR15Handle *self,off_t *posptr);
static int LookupByte(int *table,int *reverse,int limit,int index);
static void ResetTable(int *table,int *reverse);

@implementation XADRAR15Handle

-(id)initWithRARParser:(XADRARParser *)parent parts:(NSArray *)partarray
{
	if(self=[super initWithName:[parent filename] windowSize:0x10000])
	{
		parser=parent;
		parts=[partarray retain];

		lengthcode1=[[XADPrefixCode alloc] initWithLengths:(int[256]){
		2,2,3,4,4,5,5,6,6,6,6,7,7,7,7,7,8,8,8,8,9,9,9,9,10,10,10,10,10,10,10,10,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		} numberOfSymbols:256 maximumLength:12 shortestCodeIsZeros:YES];

		lengthcode2=[[XADPrefixCode alloc] initWithLengths:(int[256]){
		3,3,3,3,3,4,4,5,5,6,6,6,6,7,7,7,7,7,8,8,8,8,9,9,9,9,10,10,10,10,10,10,10,10,11,
		11,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,
		} numberOfSymbols:256 maximumLength:12 shortestCodeIsZeros:YES];

		huffmancode0=[[XADPrefixCode alloc] initWithLengths:(int[257]){
		4,4,4,4,4,4,4,4,5,5,5,5,5,5,5,5,6,6,6,6,6,6,6,6,7,7,7,7,7,7,7,7,7,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,
		} numberOfSymbols:257 maximumLength:12 shortestCodeIsZeros:YES];

		huffmancode1=[[XADPrefixCode alloc] initWithLengths:(int[257]){
		5,5,5,5,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,6,
		6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,9,9,
		9,9,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,
		11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,11,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,12,
		} numberOfSymbols:257 maximumLength:12 shortestCodeIsZeros:YES];

		huffmancode2=[[XADPrefixCode alloc] initWithLengths:(int[257]){
		5,5,6,6,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,7,
		7,7,7,7,7,7,7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,10,
		10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,10,
		} numberOfSymbols:257 maximumLength:10 shortestCodeIsZeros:YES];

		huffmancode3=[[XADPrefixCode alloc] initWithLengths:(int[257]){
		6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,7,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,
		9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,9,10,10,10,10,10,10,
		} numberOfSymbols:257 maximumLength:10 shortestCodeIsZeros:YES];

		huffmancode4=[[XADPrefixCode alloc] initWithLengths:(int[257]){
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,
		8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,8,9,9,
		} numberOfSymbols:257 maximumLength:9 shortestCodeIsZeros:YES];

		shortmatchcode0=[[XADPrefixCode alloc] init];
		[shortmatchcode0 addValue:0 forCodeWithHighBitFirst:0x00 length:1];
		[shortmatchcode0 addValue:1 forCodeWithHighBitFirst:0x0a length:4];
		[shortmatchcode0 addValue:2 forCodeWithHighBitFirst:0x0d length:4];
		[shortmatchcode0 addValue:3 forCodeWithHighBitFirst:0x0e length:4];
		[shortmatchcode0 addValue:4 forCodeWithHighBitFirst:0x1e length:5];
		[shortmatchcode0 addValue:5 forCodeWithHighBitFirst:0x3e length:6];
		[shortmatchcode0 addValue:6 forCodeWithHighBitFirst:0x7e length:7];
		[shortmatchcode0 addValue:7 forCodeWithHighBitFirst:0xfe length:8];
		[shortmatchcode0 addValue:8 forCodeWithHighBitFirst:0xff length:8];
		[shortmatchcode0 addValue:9 forCodeWithHighBitFirst:0x0c length:4];
		[shortmatchcode0 addValue:10 forCodeWithHighBitFirst:0x08 length:4];
		[shortmatchcode0 addValue:11 forCodeWithHighBitFirst:0x12 length:5];
		[shortmatchcode0 addValue:12 forCodeWithHighBitFirst:0x26 length:6];
		[shortmatchcode0 addValue:13 forCodeWithHighBitFirst:0x27 length:6];
		[shortmatchcode0 addValue:14 forCodeWithHighBitFirst:0x0b length:4];

		shortmatchcode1=[[XADPrefixCode alloc] init];
		[shortmatchcode1 addValue:0 forCodeWithHighBitFirst:0x00 length:1];
		[shortmatchcode1 addValue:1 forCodeWithHighBitFirst:0x05 length:3];
		[shortmatchcode1 addValue:2 forCodeWithHighBitFirst:0x0d length:4];
		[shortmatchcode1 addValue:3 forCodeWithHighBitFirst:0x0e length:4];
		[shortmatchcode1 addValue:4 forCodeWithHighBitFirst:0x1e length:5];
		[shortmatchcode1 addValue:5 forCodeWithHighBitFirst:0x3e length:6];
		[shortmatchcode1 addValue:6 forCodeWithHighBitFirst:0x7e length:7];
		[shortmatchcode1 addValue:7 forCodeWithHighBitFirst:0xfe length:8];
		[shortmatchcode1 addValue:8 forCodeWithHighBitFirst:0xff length:8];
		[shortmatchcode1 addValue:9 forCodeWithHighBitFirst:0x0c length:4];
		[shortmatchcode1 addValue:10 forCodeWithHighBitFirst:0x08 length:4];
		[shortmatchcode1 addValue:11 forCodeWithHighBitFirst:0x12 length:5];
		[shortmatchcode1 addValue:12 forCodeWithHighBitFirst:0x26 length:6];
		[shortmatchcode1 addValue:13 forCodeWithHighBitFirst:0x27 length:6];

		shortmatchcode2=[[XADPrefixCode alloc] init];
		[shortmatchcode2 addValue:0 forCodeWithHighBitFirst:0x00 length:2];
		[shortmatchcode2 addValue:1 forCodeWithHighBitFirst:0x02 length:3];
		[shortmatchcode2 addValue:2 forCodeWithHighBitFirst:0x03 length:3];
		[shortmatchcode2 addValue:3 forCodeWithHighBitFirst:0x0a length:4];
		[shortmatchcode2 addValue:4 forCodeWithHighBitFirst:0x0d length:4];
		[shortmatchcode2 addValue:5 forCodeWithHighBitFirst:0x3e length:4];
		[shortmatchcode2 addValue:6 forCodeWithHighBitFirst:0x1e length:5];
		[shortmatchcode2 addValue:7 forCodeWithHighBitFirst:0x3e length:6];
		[shortmatchcode2 addValue:8 forCodeWithHighBitFirst:0x3f length:6];
		[shortmatchcode2 addValue:9 forCodeWithHighBitFirst:0x0c length:4];
		[shortmatchcode2 addValue:10 forCodeWithHighBitFirst:0x08 length:4];
		[shortmatchcode2 addValue:11 forCodeWithHighBitFirst:0x12 length:5];
		[shortmatchcode2 addValue:12 forCodeWithHighBitFirst:0x26 length:6];
		[shortmatchcode2 addValue:13 forCodeWithHighBitFirst:0x27 length:6];
		[shortmatchcode2 addValue:14 forCodeWithHighBitFirst:0x0b length:4];

		shortmatchcode3=[[XADPrefixCode alloc] init];
		[shortmatchcode3 addValue:0 forCodeWithHighBitFirst:0x00 length:2];
		[shortmatchcode3 addValue:1 forCodeWithHighBitFirst:0x02 length:3];
		[shortmatchcode3 addValue:2 forCodeWithHighBitFirst:0x03 length:3];
		[shortmatchcode3 addValue:3 forCodeWithHighBitFirst:0x05 length:3];
		[shortmatchcode3 addValue:4 forCodeWithHighBitFirst:0x0d length:4];
		[shortmatchcode3 addValue:5 forCodeWithHighBitFirst:0x3e length:4];
		[shortmatchcode3 addValue:6 forCodeWithHighBitFirst:0x1e length:5];
		[shortmatchcode3 addValue:7 forCodeWithHighBitFirst:0x3e length:6];
		[shortmatchcode3 addValue:8 forCodeWithHighBitFirst:0x3f length:6];
		[shortmatchcode3 addValue:9 forCodeWithHighBitFirst:0x0c length:4];
		[shortmatchcode3 addValue:10 forCodeWithHighBitFirst:0x08 length:4];
		[shortmatchcode3 addValue:11 forCodeWithHighBitFirst:0x12 length:5];
		[shortmatchcode3 addValue:12 forCodeWithHighBitFirst:0x26 length:6];
		[shortmatchcode3 addValue:13 forCodeWithHighBitFirst:0x27 length:6];
	}
	return self;
}

-(void)dealloc
{
	[lengthcode1 release];
	[lengthcode2 release];
	[huffmancode0 release];
	[huffmancode1 release];
	[huffmancode2 release];
	[huffmancode3 release];
	[huffmancode4 release];
	[shortmatchcode0 release];
	[shortmatchcode1 release];
	[shortmatchcode2 release];
	[shortmatchcode3 release];
	[super dealloc];
}

-(void)resetLZSSHandle
{
	part=0;
	endpos=0;

	numrepeatedliterals=0;
	bugfixflag=NO;

	runningaverageselector=0;
	runningaverageliteral=0x3500;
	runningaveragelength=0;
	runningaverageoffset=0;
	runningaveragebelowmaximum=0;

	maximumoffset=0x2001;
	literalweight=matchweight=0x80;

	for(int i=0;i<256;i++)
	{
		flagtable[i]=((-i)&0xff)<<8;
		literaltable[i]=i<<8;
		offsettable[i]=i<<8;
		shortoffsettable[i]=i;
	}
	memset(flagreverse,0,sizeof(flagreverse));
	memset(literalreverse,0,sizeof(literalreverse));

	ResetTable(offsettable,offsetreverse);

	lastoffset=0;
	lastlength=0;
	memset(oldoffset,0,sizeof(oldoffset));
	oldoffsetindex=0;

	[self startNextPart];
}

-(void)startNextPart
{
	flagbits=0;
	storedblock=NO;
	numrepeatedlastmatches=0;

	off_t partlength;
	CSInputBuffer *buf=[parser inputBufferForNextPart:&part parts:parts length:&partlength];

	[self setInputBuffer:buf];
	endpos+=partlength;
}

-(void)expandFromPosition:(off_t)pos
{
	while(XADLZSSShouldKeepExpanding(self))
	{
		if(pos==endpos) [self startNextPart];

		if(storedblock)
		{
			EmitLiteral(self,&pos);
		}
		else
		{
			BOOL expectingmatch=matchweight>literalweight;
			if(GetFlagBit(self))
			{
				// The expected case.
				if(expectingmatch) EmitLongMatch(self,&pos);
				else EmitLiteral(self,&pos);
			}
			else if(GetFlagBit(self))
			{
				// The unexpected case.
				if(!expectingmatch) EmitLongMatch(self,&pos);
				else EmitLiteral(self,&pos);
			}
			else
			{
				EmitShortMatch(self,&pos);
			}
		}
	}
}

static BOOL GetFlagBit(XADRAR15Handle *self)
{
	if(self->flagbits==0)
	{
		int index=CSInputNextSymbolUsingCode(self->input,self->huffmancode2);
		if(index==256) [XADException raiseIllegalDataException];
		self->flags=LookupByte(self->flagtable,self->flagreverse,0xff,index);
		self->flagbits=8;
	}

	self->flagbits--;
	return (self->flags>>self->flagbits)&1;
}

static void EmitLiteral(XADRAR15Handle *self,off_t *posptr)
{
	int index;
	if(self->runningaverageliteral<0xe00) index=CSInputNextSymbolUsingCode(self->input,self->huffmancode0);
	else if(self->runningaverageliteral<0x3600) index=CSInputNextSymbolUsingCode(self->input,self->huffmancode1);
	else if(self->runningaverageliteral<0x5e00)  index=CSInputNextSymbolUsingCode(self->input,self->huffmancode2);
	else if(self->runningaverageliteral<0x7600) index=CSInputNextSymbolUsingCode(self->input,self->huffmancode3);
	else index=CSInputNextSymbolUsingCode(self->input,self->huffmancode4);

	if(self->storedblock)
	{
		// This differs slightly from what RAR does, but is sane.
		// (RAR masks away 0x100 before this part, and restores it clumsily).
		if(index==0)
		{
			if(CSInputNextBit(self->input))
			{
				self->storedblock=NO;
				self->numrepeatedliterals=0;
				return;
			}
			else
			{
				int length;
				if(CSInputNextBit(self->input)) length=4;
				else length=3;

				int offset=CSInputNextSymbolUsingCode(self->input,self->huffmancode2)<<5;
				offset|=CSInputNextBitString(self->input,5);

				XADLZSSMatch(self,offset,length,posptr);
				return;
			}
		}
		else index--;
	}
	else
	{
		index&=0xff;
		if(self->numrepeatedliterals++>=16&&self->flagbits==0) self->storedblock=YES;
	}

	self->runningaverageliteral+=index;
	self->runningaverageliteral-=self->runningaverageliteral>>8;

	self->literalweight+=16;
	if(self->literalweight>0xff)
	{
		self->literalweight=0x90;
		self->matchweight>>=1;
	}

	uint8_t byte=LookupByte(self->literaltable,self->literalreverse,0xa1,index);
	XADLZSSLiteral(self,byte,posptr);
}

static void EmitLongMatch(XADRAR15Handle *self,off_t *posptr)
{
	self->numrepeatedliterals=0;
	self->matchweight+=16;
	if(self->matchweight>0xff)
	{
		self->matchweight=0x90;
		self->literalweight>>=1;
	}

	int rawlength;
	if(self->runningaveragelength>=122) rawlength=CSInputNextSymbolUsingCode(self->input,self->lengthcode2);
	else if(self->runningaveragelength>=64) rawlength=CSInputNextSymbolUsingCode(self->input,self->lengthcode1);
    else
	{
		rawlength=0;
		while(rawlength<8 && CSInputNextBit(self->input)==0) rawlength++;

		if(rawlength==8) rawlength=CSInputNextBitString(self->input,8);
	}

	int offsetindex;
	if(self->runningaverageoffset<0x700) offsetindex=CSInputNextSymbolUsingCode(self->input,self->huffmancode0);
	else if(self->runningaverageoffset<0x2900) offsetindex=CSInputNextSymbolUsingCode(self->input,self->huffmancode1);
	else offsetindex=CSInputNextSymbolUsingCode(self->input,self->huffmancode2);

	if(offsetindex==0x100) [XADException raiseIllegalDataException];

	int offset=LookupByte(self->offsettable,self->offsetreverse,0xff,offsetindex)<<7;
	offset|=CSInputNextBitString(self->input,7);

	int length=rawlength+3;

	if(offset>=self->maximumoffset) length++;
	if(offset<=256) length+=8;

	if(self->runningaveragebelowmaximum>0xb0 || self->runningaverageliteral>=0x2a00
	&& self->runningaveragelength<0x40) self->maximumoffset=0x7f00;
	else self->maximumoffset=0x2001;



	self->runningaveragelength+=rawlength;
	self->runningaveragelength-=self->runningaveragelength>>5;

	self->runningaverageoffset+=offsetindex;
	self->runningaverageoffset-=self->runningaverageoffset>>8;

    if(rawlength==0 && offset<=self->maximumoffset)
    {
		self->runningaveragebelowmaximum++;
		self->runningaveragebelowmaximum-=self->runningaveragebelowmaximum>>8;
    }
    else if(rawlength!=1&&rawlength!=4)
	{
		if(self->runningaveragebelowmaximum>0) self->runningaveragebelowmaximum--;
	}



	self->lastoffset=self->oldoffset[self->oldoffsetindex++&3]=offset;
	self->lastlength=length;

	XADLZSSMatch(self,self->lastoffset,self->lastlength,posptr);
}

static void EmitShortMatch(XADRAR15Handle *self,off_t *posptr)
{
	self->numrepeatedliterals=0;

	if(self->numrepeatedlastmatches==2)
	{
		if(CSInputNextBit(self->input))
		{
			XADLZSSMatch(self,self->lastoffset,self->lastlength,posptr);
			return;
		}
		else self->numrepeatedlastmatches=0;
	}

	unsigned int selector;
	if(self->runningaverageselector<37)
	{
		if(self->bugfixflag) selector=CSInputNextSymbolUsingCode(self->input,self->shortmatchcode0);
		else selector=CSInputNextSymbolUsingCode(self->input,self->shortmatchcode1);
	}
	else
	{
		if(self->bugfixflag) selector=CSInputNextSymbolUsingCode(self->input,self->shortmatchcode2);
		else selector=CSInputNextSymbolUsingCode(self->input,self->shortmatchcode3);
	}

	if(selector<9)
	{
		self->numrepeatedlastmatches=0;

		self->runningaverageselector+=selector;
		self->runningaverageselector-=self->runningaverageselector>>4;

		int offsetindex=CSInputNextSymbolUsingCode(self->input,self->huffmancode2)&0xff;

		int offset=self->shortoffsettable[offsetindex];
		if(offsetindex!=0)
		{
			self->shortoffsettable[offsetindex]=self->shortoffsettable[offsetindex-1];
			self->shortoffsettable[offsetindex-1]=offset;
		}
		offset++;

		int length=selector+2;

		self->lastoffset=self->oldoffset[self->oldoffsetindex++&3]=offset;
		self->lastlength=length;

		XADLZSSMatch(self,offset,length,posptr);
	}
	else if(selector==9)
    {
		self->numrepeatedlastmatches++;

		XADLZSSMatch(self,self->lastoffset,self->lastlength,posptr);
    }
	else if(selector<14)
	{
		self->numrepeatedlastmatches=0;

		int offset=self->oldoffset[(self->oldoffsetindex-(selector-9))&3];

		int length=CSInputNextSymbolUsingCode(self->input,self->lengthcode1)+2;
		if(length==0x101 && selector==10)
		{
			self->bugfixflag=!self->bugfixflag;
			return;
		}

		if(offset>256) length++;
		if(offset>=self->maximumoffset) length++;

		self->lastoffset=self->oldoffset[self->oldoffsetindex++&3]=offset;
		self->lastlength=length;

		XADLZSSMatch(self,offset,length,posptr);
	}
	else //if(length==14)
	{
		self->numrepeatedlastmatches=0;

		int length=CSInputNextSymbolUsingCode(self->input,self->lengthcode2)+5;
		int offset=CSInputNextBitString(self->input,15)+0x8000;

		self->lastoffset=offset;
		self->lastlength=length;

		XADLZSSMatch(self,offset,length,posptr);
	}
}

static int LookupByte(int *table,int *reverse,int limit,int index)
{
	int val=table[index];
	int newindex=reverse[val&0xff]++;

	if((val&0xff)>=limit)
	{
		ResetTable(table,reverse);
		val=table[index];
		newindex=reverse[val&0xff]++;
	}

	table[index]=table[newindex];
	table[newindex]=val+1;

	return val>>8;
}

static void ResetTable(int *table,int *reverse)
{
	for(int i=0;i<8;i++)
	for(int j=0;j<32;j++)
	table[i*32+j]=(table[i*32+j]&~0xff)|(7-i);

	memset(reverse,0,sizeof(int)*256);
	for(int i=0;i<7;i++) reverse[i]=(7-i)*32;
}

@end

