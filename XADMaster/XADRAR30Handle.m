#import "XADRAR30Handle.h"
#import "XADRAR30Filter.h"
#import "XADException.h"

@implementation XADRAR30Handle

-(id)initWithRARParser:(XADRARParser *)parent parts:(NSArray *)partarray
{
	if(self=[super initWithName:[parent filename]])
	{
		parser=parent;
		parts=[partarray retain];

		InitializeLZSS(&lzss,0x400000);

		maincode=nil;
		offsetcode=nil;
		lowoffsetcode=nil;
		lengthcode=nil;
		alloc=NULL;
		vm=nil;
		filtercode=nil;
		stack=nil;
	}
	return self;
}

-(void)dealloc
{
	[parts release];
	CleanupLZSS(&lzss);
	[maincode release];
	[offsetcode release];
	[lowoffsetcode release];
	[lengthcode release];
	FreeSubAllocatorVariantH(alloc);
	[vm release];
	[filtercode release];
	[stack release];
	[super dealloc];
}

-(void)resetBlockStream
{
	part=0;
	lastend=0;

	RestartLZSS(&lzss);

	memset(lengthtable,0,sizeof(lengthtable));

	lastoffset=0;
	lastlength=0;
	memset(oldoffset,0,sizeof(oldoffset));

	ppmescape=2;

	[filtercode removeAllObjects];
	[stack removeAllObjects];
	filterstart=CSHandleMaxLength;
	lastfilternum=0;

	startnewpart=startnewtable=YES;
}


-(int)produceBlockAtOffset:(off_t)pos
{
	if(startnewpart)
	{
		CSInputBuffer *buf=[parser inputBufferForNextPart:&part parts:parts length:NULL];
		[self setInputBuffer:buf];

		if(startnewtable) [self allocAndParseCodes];

		startnewpart=startnewtable=NO;
	}

	if(lastend==filterstart)
	{
		XADRAR30Filter *firstfilter=[stack objectAtIndex:0];
		off_t start=filterstart;
		int length=[firstfilter length];
		off_t end=start+length;

		// Remove the filter start marker and unpack enough data to run the filter on.
		filterstart=CSHandleMaxLength;
		off_t actualend=[self expandToPosition:end];
		if(actualend!=end) [XADException raiseIllegalDataException];

		// Copy data to virtual machine memory and run the first filter.
		uint8_t *memory=[vm memory];
		CopyBytesFromLZSSWindow(&lzss,memory,start,length);

		[firstfilter executeOnVirtualMachine:vm atPosition:pos];

		uint32_t lastfilteraddress=[firstfilter filteredBlockAddress];
		uint32_t lastfilterlength=[firstfilter filteredBlockLength];

		[stack removeObjectAtIndex:0];

		// Run any furhter filters that match the exact same range of data,
		// taking into account that the length may have changed.
		for(;;)
		{
			if([stack count]==0) break;
			XADRAR30Filter *filter=[stack objectAtIndex:0];

			// Check if this filter applies.
			if([filter startPosition]!=filterstart) break;
			if([filter length]!=lastfilterlength) break;

			// Move last filtered block into place and run.
			memmove(&memory[0],&memory[lastfilteraddress],lastfilterlength);

			[filter executeOnVirtualMachine:vm atPosition:pos];

			lastfilteraddress=[filter filteredBlockAddress];
			lastfilterlength=[filter filteredBlockLength];

			[stack removeObjectAtIndex:0];
		}

		// If there are further filters on the stack, set up the filter start marker again
		// and sanity-check filter ordering.
		if([stack count])
		{
			XADRAR30Filter *filter=[stack objectAtIndex:0];
			filterstart=[filter startPosition];

			if(filterstart<end) [XADException raiseIllegalDataException];
		}

		[self setBlockPointer:&memory[lastfilteraddress]];

		lastend=end;
		return lastfilterlength;
	}
	else
	{
		off_t start=lastend;
		off_t end=start+0x40000;
		off_t windowend=NextLZSSWindowEdgeAfterPosition(&lzss,start);
		if(end>windowend) end=windowend;

		off_t actualend=[self expandToPosition:end];

		[self setBlockPointer:LZSSWindowPointerForPosition(&lzss,pos)];

		lastend=actualend;

		// Check if we immediately hit a new filter, and try again.
		if(actualend==start && actualend==filterstart) return [self produceBlockAtOffset:pos];
		else return actualend-start;
	}
}

-(off_t)expandToPosition:(off_t)end
{
	static const int lengthbases[28]={0,1,2,3,4,5,6,7,8,10,12,14,16,20,24,28,32,
	40,48,56,64,80,96,112,128,160,192,224};
	static const int lengthbits[28]={0,0,0,0,0,0,0,0,1,1,1,1,2,2,2,2,3,3,3,3,4,4,4,4,5,5,5,5};
	static const int offsetbases[60]={0,1,2,3,4,6,8,12,16,24,32,48,64,96,128,192,256,384,512,
	768,1024,1536,2048,3072,4096,6144,8192,12288,16384,24576,32768,49152,65536,98304,
	131072,196608,262144,327680,393216,458752,524288,589824,655360,720896,786432,
	851968,917504,983040,1048576,1310720,1572864,1835008,2097152,2359296,2621440,
	2883584,3145728,3407872,3670016,3932160};
	static const unsigned char offsetbits[60]={0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,
	11,11,12,12,13,13,14,14,15,15,16,16,16,16,16,16,16,16,16,16,16,16,16,16,
	18,18,18,18,18,18,18,18,18,18,18,18};
	static const unsigned int shortbases[8]={0,4,8,16,32,64,128,192};
	static const unsigned int shortbits[8]={2,2,3,4,5,6,6,6};

	if(filterstart<end) end=filterstart; // Make sure we stop when we reach a filter.

	for(;;)
	{
		if(LZSSPosition(&lzss)>=end) return end;

		if(ppmblock)
		{
			int byte=NextPPMdVariantHByte(&ppmd);
			if(byte<0) [XADException raiseInputException]; // TODO: better error;

			if(byte!=ppmescape)
			{
				EmitLZSSLiteral(&lzss,byte);
			}
			else
			{
				int code=NextPPMdVariantHByte(&ppmd);

				switch(code)
				{
					case 0:
						[self allocAndParseCodes];
					break;

					case 2:
						return LZSSPosition(&lzss);
					break;

					case 3:
						[self readFilterFromPPMd];
						if(filterstart<end) end=filterstart; // Make sure we stop when we reach a filter.
					break;

					case 4:
					{
						// TODO: check for error
						int offs=NextPPMdVariantHByte(&ppmd)<<16;
						offs|=NextPPMdVariantHByte(&ppmd)<<8;
						offs|=NextPPMdVariantHByte(&ppmd);

						int len=NextPPMdVariantHByte(&ppmd);

						EmitLZSSMatch(&lzss,offs+2,len+32);
					}
					break;

					case 5:
					{
						int len=NextPPMdVariantHByte(&ppmd);
						EmitLZSSMatch(&lzss,1,len+4);
					}
					break;

					case -1:
						[XADException raiseInputException]; // TODO: better error;
					break;

					default:
						EmitLZSSLiteral(&lzss,byte);
					break;
				}
			}
		}
		else
		{
			int symbol=CSInputNextSymbolUsingCode(input,maincode);
			int offs,len;

			if(symbol<256)
			{
				EmitLZSSLiteral(&lzss,symbol);
				continue;
			}
			else if(symbol==256)
			{
				BOOL newfile=!CSInputNextBit(input);

				if(newfile)
				{
					startnewpart=YES;
					startnewtable=CSInputNextBit(input);
					return LZSSPosition(&lzss);
				}
				else
				{
					[self allocAndParseCodes];
					continue;
				}
			}
			else if(symbol==257)
			{
				[self readFilterFromInput];
				if(filterstart<end) end=filterstart; // Make sure we stop when we reach a filter.
				continue;
			}
			else if(symbol==258)
			{
				if(lastlength==0) continue;

	  			offs=lastoffset;
				len=lastlength;
			}
			else if(symbol<=262)
			{
				int offsindex=symbol-259;
				offs=oldoffset[offsindex];

				int lensymbol=CSInputNextSymbolUsingCode(input,lengthcode);
				len=lengthbases[lensymbol]+2;
				if(lengthbits[lensymbol]>0) len+=CSInputNextBitString(input,lengthbits[lensymbol]);

				for(int i=offsindex;i>0;i--) oldoffset[i]=oldoffset[i-1];
				oldoffset[0]=offs;
			}
			else if(symbol<=270)
			{
				offs=shortbases[symbol-263]+1;
				if(shortbits[symbol-263]>0) offs+=CSInputNextBitString(input,shortbits[symbol-263]);

				len=2;

				for(int i=3;i>0;i--) oldoffset[i]=oldoffset[i-1];
				oldoffset[0]=offs;
			}
			else //if(code>=271)
			{
				len=lengthbases[symbol-271]+3;
				if(lengthbits[symbol-271]>0) len+=CSInputNextBitString(input,lengthbits[symbol-271]);

				int offssymbol=CSInputNextSymbolUsingCode(input,offsetcode);
				offs=offsetbases[offssymbol]+1;
				if(offsetbits[offssymbol]>0)
				{
					if(offssymbol>9)
					{
						if(offsetbits[offssymbol]>4)
						offs+=CSInputNextBitString(input,offsetbits[offssymbol]-4)<<4;

						if(numlowoffsetrepeats>0)
						{
							numlowoffsetrepeats--;
							offs+=lastlowoffset;
						}
						else
						{
							int lowoffsetsymbol=CSInputNextSymbolUsingCode(input,lowoffsetcode);
							if(lowoffsetsymbol==16)
							{
								numlowoffsetrepeats=15;
								offs+=lastlowoffset;
							}
							else
							{
								offs+=lowoffsetsymbol;
								lastlowoffset=lowoffsetsymbol;
							}
						}
					}
					else
					{
						offs+=CSInputNextBitString(input,offsetbits[offssymbol]);
					}
				}

				if(offs>=0x40000) len++;
				if(offs>=0x2000) len++;

				for(int i=3;i>0;i--) oldoffset[i]=oldoffset[i-1];
				oldoffset[0]=offs;
			}

			lastoffset=offs;
			lastlength=len;

			EmitLZSSMatch(&lzss,offs,len);
		}
	}
}

-(void)allocAndParseCodes
{
	[maincode release]; maincode=nil;
	[offsetcode release]; offsetcode=nil;
	[lowoffsetcode release]; lowoffsetcode=nil;
	[lengthcode release]; lengthcode=nil;

	CSInputSkipToByteBoundary(input);

	ppmblock=CSInputNextBit(input);

	if(ppmblock)
	{
		int flags=CSInputNextBitString(input,7);

		int maxalloc;
		if(flags&0x20) maxalloc=CSInputNextByte(input);
		//else check if memory allocated at all else die

		if(flags&0x40) ppmescape=CSInputNextByte(input);

		if(flags&0x20)
		{
			int maxorder=(flags&0x1f)+1;
			if(maxorder>16) maxorder=16+(maxorder-16)*3;

			// Check for end of file marker. TODO: better error
			if(maxorder==1) [XADException raiseInputException];

			FreeSubAllocatorVariantH(alloc);
			alloc=CreateSubAllocatorVariantH((maxalloc+1)<<20);

			StartPPMdModelVariantH(&ppmd,input,alloc,maxorder,NO);
		}
		else RestartPPMdVariantHRangeCoder(&ppmd,input,NO);

		return;
	}

	lastlowoffset=0;
	numlowoffsetrepeats=0;

	if(CSInputNextBit(input)==0) memset(lengthtable,0,sizeof(lengthtable));

	XADPrefixCode *precode=nil;
	@try
	{
		int prelengths[20];
		for(int i=0;i<20;)
		{
			int length=CSInputNextBitString(input,4);
			if(length==15)
			{
				int count=CSInputNextBitString(input,4)+2;

				if(count==2) prelengths[i++]=15;
				else for(int j=0;j<count && i<20;j++) prelengths[i++]=0;
			}
			else prelengths[i++]=length;
		}

		precode=[[XADPrefixCode alloc] initWithLengths:prelengths
		numberOfSymbols:20 maximumLength:15 shortestCodeIsZeros:YES];

		for(int i=0;i<299+60+17+28;)
		{
			int val=CSInputNextSymbolUsingCode(input,precode);
			if(val<16)
			{
				lengthtable[i]=(lengthtable[i]+val)&0x0f;
				i++;
			}
			else if(val<18)
			{
				if(i==0) [XADException raiseDecrunchException];

				int n;
				if(val==16) n=CSInputNextBitString(input,3)+3;
				else n=CSInputNextBitString(input,7)+11;

				for(int j=0;j<n && i<299+60+17+28;j++)
				{
					lengthtable[i]=lengthtable[i-1];
					i++;
				}
			}
			else //if(val<20)
			{
				int n;
				if(val==18) n=CSInputNextBitString(input,3)+3;
				else n=CSInputNextBitString(input,7)+11;

				for(int j=0;j<n && i<299+60+17+28;j++) lengthtable[i++]=0;
			}
		}

		[precode release];
	}
	@catch(id e)
	{
		[precode release];
		@throw;
	}

	maincode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[0]
	numberOfSymbols:299 maximumLength:15 shortestCodeIsZeros:YES];

	offsetcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[299]
	numberOfSymbols:60 maximumLength:15 shortestCodeIsZeros:YES];

	lowoffsetcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[299+60]
	numberOfSymbols:17 maximumLength:15 shortestCodeIsZeros:YES];

	lengthcode=[[XADPrefixCode alloc] initWithLengths:&lengthtable[299+60+17]
	numberOfSymbols:28 maximumLength:15 shortestCodeIsZeros:YES];
}



-(void)readFilterFromInput
{
	int flags=CSInputNextBitString(input,8);

	int length=(flags&7)+1;
	if(length==7) length=CSInputNextBitString(input,8)+7;
	else if(length==8) length=CSInputNextBitString(input,16);

	uint8_t code[length];
	for(int i=0;i<length;i++) code[i]=CSInputNextBitString(input,8);

	[self parseFilter:code length:length flags:flags];
}

-(void)readFilterFromPPMd
{
	// TODO: handle errors from NextPPMdVariantHByte()?
	int flags=NextPPMdVariantHByte(&ppmd);

	int length=(flags&7)+1;
	if(length==7) length=NextPPMdVariantHByte(&ppmd)+7;
	else if(length==8)
	{
		length=NextPPMdVariantHByte(&ppmd)<<8;
		length|=NextPPMdVariantHByte(&ppmd);
	}

	uint8_t code[length];
	for(int i=0;i<length;i++) code[i]=NextPPMdVariantHByte(&ppmd);

	[self parseFilter:code length:length flags:flags];
}

-(void)parseFilter:(const uint8_t *)bytes length:(int)length flags:(int)flags
{
	// TODO: deal with memory leaks from exceptions

	if(!vm) vm=[XADRARVirtualMachine new];
	if(!filtercode) filtercode=[NSMutableArray new];
	if(!stack) stack=[NSMutableArray new];

	CSInputBuffer *filterinput=CSInputBufferAllocWithBuffer(bytes,length,0);
	int numcodes=[filtercode count];

	int num;
	BOOL isnew=NO;

	// Read filter number
	if(flags&0x80)
	{
		num=CSInputNextRARVMNumber(filterinput)-1;

		if(num==-1)
		{
			num=0;
			[filtercode removeAllObjects];
			[stack removeAllObjects];
		}

		if(num>numcodes||num<0||num>1024) [XADException raiseIllegalDataException];
		if(num==numcodes)
		{
			isnew=YES;
			oldfilterlength[num]=0;
			usagecount[num]=-1;
		}

		lastfilternum=num;
	}
	else num=lastfilternum;

	usagecount[num]++;

	// Read filter range
	off_t blockstartpos=CSInputNextRARVMNumber(filterinput)+LZSSPosition(&lzss);
	if(flags&0x40) blockstartpos+=258;

	uint32_t blocklength;
	if(flags&0x20) blocklength=oldfilterlength[num]=CSInputNextRARVMNumber(filterinput);
	else blocklength=oldfilterlength[num];

	uint32_t registers[8]={
		[3]=RARProgramGlobalAddress,[4]=blocklength,
		[5]=usagecount[num],[7]=RARProgramMemorySize
	};

	// Read register override values
	if(flags&0x10)
	{
		int mask=CSInputNextBitString(filterinput,7);
		for(int i=0;i<7;i++) if(mask&(1<<i)) registers[i]=CSInputNextRARVMNumber(filterinput);
	}

	// Read bytecode or look up old version.
	XADRARProgramCode *code;
	if(isnew)
	{
		int length=CSInputNextRARVMNumber(filterinput);
		if(length==0||length>0x10000) [XADException raiseIllegalDataException];

		uint8_t bytecode[length];
		for(int i=0;i<length;i++) bytecode[i]=CSInputNextBitString(filterinput,8);

		code=[[[XADRARProgramCode alloc] initWithByteCode:bytecode length:length] autorelease];
		if(!code) [XADException raiseIllegalDataException];

		[filtercode addObject:code];

		//NSLog(@"%08x\n%@",[code CRC],[code disassemble]);
	}
	else
	{
		code=[filtercode objectAtIndex:num];
	}
  
	// Read data section.
	NSMutableData *data=nil;
	if(flags&8)
	{
		int length=CSInputNextRARVMNumber(filterinput);

		if(length>RARProgramUserGlobalSize) [XADException raiseIllegalDataException];

		data=[NSMutableData dataWithLength:length+RARProgramSystemGlobalSize];
		uint8_t *databytes=[data mutableBytes];

		for(int i=0;i<length;i++) databytes[i+RARProgramSystemGlobalSize]=CSInputNextBitString(filterinput,8);
	}

	// Create an invocation and set register and memory parameters.
	XADRARProgramInvocation *invocation=[[[XADRARProgramInvocation alloc]
	initWithProgramCode:code globalData:data registers:registers] autorelease];

	for(int i=0;i<7;i++) [invocation setGlobalValueAtOffset:i*4 toValue:registers[i]];
	[invocation setGlobalValueAtOffset:0x1c toValue:blocklength];
	[invocation setGlobalValueAtOffset:0x20 toValue:0];
	[invocation setGlobalValueAtOffset:0x2c toValue:usagecount[num]];

	// Create a filter object and add it to the stack.
	XADRAR30Filter *filter=[XADRAR30Filter filterForProgramInvocation:invocation
	startPosition:blockstartpos length:blocklength];
	[stack addObject:filter];

	// If this is the first filter added to an empty stack, set the filter start marker.
	if([stack count]==1) filterstart=blockstartpos;

	CSInputBufferFree(filterinput);
}


@end

