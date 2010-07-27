#import "XADMSLZXHandle.h"
#import "XADException.h"

@implementation XADMSLZXHandle

-(id)initWithBlockReader:(XADCABBlockReader *)blockreader windowBits:(int)windowbits
{
	if(self=[super initWithBlockReader:blockreader])
	{
		[self setInputBuffer:CSInputBufferAllocEmpty()];

		InitializeLZSS(&lzss,1<<windowbits);

		if(windowbits==21) numslots=50;
		else if(windowbits==20) numslots=42;
		else numslots=windowbits*2;

		maincode=lengthcode=offsetcode=nil;
		ispreprocessed=NO;
	}
	return self;
}

-(void)dealloc
{
	CleanupLZSS(&lzss);

	[maincode release];
	[lengthcode release];
	[offsetcode release];
	[super dealloc];
}

-(void)resetCABBlockHandle
{
	headerhasbeenread=NO;
	inputpos=0;
	r0=r1=r2=1;
	blocktype=0;
	blockend=0;
	memset(mainlengths,0,sizeof(mainlengths));
	memset(lengthlengths,0,sizeof(lengthlengths));

	RestartLZSS(&lzss);
}

-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)complength atOffset:(off_t)pos length:(int)uncomplength
{
	static const unsigned char AdditionalBitsTable[50]=
	{
		0,0,0,0,1,1,2,2,3,3,4,4,5,5,6,6,7,7,8,8,9,9,10,10,11,11,12,12,13,13,14,14,
		15,15,16,16,17,17,17,17,17,17,17,17,17,17,17,17,17,17
	};

	static const unsigned int BaseTable[50]=
	{
		0,1,2,3,4,6,8,12,16,24,32,48,64,96,128,192,256,384,512,768,1024,
		1536,2048,3072,4096,6144,8192,12288,16384,24576,32768,49152,
		65536,98304,131072,196608,262144,393216,524288,655360,786432,917504,
		1048576,1179648,1310720,1441792,1572864,1703936,1835008,1966080
	};

	// Flip all input 16-bit words, because LZX is insane.
	// Make sure to align correctly, and leave single bytes at the start and end alone,
	// and handle these by hand for unpacked blocks (which is the only place they can exist).
	for(int i=inputpos&1;i<complength-1;i+=2)
	{
		int byte=buffer[i];
		buffer[i]=buffer[i+1];
		buffer[i+1]=byte;
	}

	CSInputSetMemoryBuffer(input,buffer,complength,inputpos);

	// Read header if needed.
	if(!headerhasbeenread)
	{
		ispreprocessed=CSInputNextBit(input);
		if(ispreprocessed) preprocesssize=CSInputNextLongBitString(input,32);
		headerhasbeenread=YES;
	}

	// Unpack data to dictionary using LZX.
	off_t unpackend=pos+uncomplength;
	while(LZSSPosition(&lzss)<unpackend)
	{
		if(LZSSPosition(&lzss)>=blockend) [self readBlockHeaderAtPosition:LZSSPosition(&lzss)];

		if(blocktype==3)
		{
			if(LZSSPosition(&lzss)==pos && (inputpos&1)==1) EmitLZSSLiteral(&lzss,CSInputNextByte(input)); // single first byte in buffer
			else if(CSInputFileOffset(input)==complength-1) EmitLZSSLiteral(&lzss,CSInputNextByte(input)); // single last byte in buffer
			else if(LZSSPosition(&lzss)+1==blockend) // single last byte in block
			{
				CSInputNextByte(input); // skip padding
				EmitLZSSLiteral(&lzss,CSInputNextByte(input));
			}
			else
			{
				uint8_t byte=CSInputNextByte(input);
				EmitLZSSLiteral(&lzss,CSInputNextByte(input));
				EmitLZSSLiteral(&lzss,byte);
			}
		}
		else
		{
			int symbol=CSInputNextSymbolUsingCode(input,maincode);
			if(symbol<256)
			{
				EmitLZSSLiteral(&lzss,symbol);
				continue;
			}

			int length=(symbol&7)+2;
			if(length==9) length=CSInputNextSymbolUsingCode(input,lengthcode)+9;

			int offsclass=(symbol-256)>>3;
			int offset=BaseTable[offsclass];
			int offsbits=AdditionalBitsTable[offsclass];

			if(offset==0)
			{
				offset=r0;
			}
			else if(offset==1)
			{
				offset=r1;
				r1=r0;
				r0=offset;
			}
			else if(offset==2)
			{
				offset=r2;
				r2=r0;
				r0=offset;
			}
			else
			{
				if(blocktype==2 && offsbits>=3)
				{
					offset+=CSInputNextBitString(input,offsbits-3)<<3;
					offset+=CSInputNextSymbolUsingCode(input,offsetcode);
				}
				else
				{
					offset+=CSInputNextBitString(input,offsbits);
				}

				offset-=2;
				r2=r1;
				r1=r0;
				r0=offset;
			}

			EmitLZSSMatch(&lzss,offset,length);
		}
	}

	// Undo e8-encoding if needed
	if(ispreprocessed && pos<32768*32768)
	{
		CopyBytesFromLZSSWindow(&lzss,outbuffer,pos,uncomplength);

		for(int i=0;i<uncomplength-10;i++)
		{
			if(outbuffer[i]==0xe8)
			{
				int32_t currpos=pos+i;
				int32_t absoffs=CSInt32LE(&outbuffer[i+1]);
				if(absoffs>=-currpos && absoffs<preprocesssize)
				{
					if(absoffs>=0) CSSetInt32LE(&outbuffer[i+1],absoffs-currpos);
					else CSSetInt32LE(&outbuffer[i+1],absoffs+preprocesssize);
				}
				i+=4;
			}
		}
		[self setBlockPointer:outbuffer];
	}
	else
	{
		[self setBlockPointer:LZSSWindowPointerForPosition(&lzss,pos)];
	}

	inputpos+=complength;

	return uncomplength;
}

-(void)readBlockHeaderAtPosition:(off_t)pos
{
	[maincode release];
	[lengthcode release];
	[offsetcode release];
	maincode=lengthcode=offsetcode=nil;

	if(blocktype==3) CSInputSkipTo16BitBoundary(input);

	blocktype=CSInputNextBitString(input,3);
	if(blocktype<1||blocktype>3) [XADException raiseIllegalDataException];

	int blocksize=CSInputNextBitString(input,24);
	blockend=pos+blocksize;

	switch(blocktype)
	{
		case 2: // aligned offset
		{
			int codelengths[8];
			for(int i=0;i<8;i++) codelengths[i]=CSInputNextBitString(input,3);

			offsetcode=[[XADPrefixCode alloc] initWithLengths:codelengths
			numberOfSymbols:8 maximumLength:7 shortestCodeIsZeros:YES];
		} // fall through

		case 1: // verbatim
		{
			[self readDeltaLengths:&mainlengths[0] count:256 alternateMode:NO];
			[self readDeltaLengths:&mainlengths[256] count:numslots*8 alternateMode:NO];

			maincode=[[XADPrefixCode alloc] initWithLengths:mainlengths
			numberOfSymbols:256+numslots*8 maximumLength:16 shortestCodeIsZeros:YES];

			[self readDeltaLengths:lengthlengths count:249 alternateMode:NO];
			lengthcode=[[XADPrefixCode alloc] initWithLengths:lengthlengths
			numberOfSymbols:249 maximumLength:16 shortestCodeIsZeros:YES];
		}
		break;

		case 3: // uncompressed
		{
			CSInputSkipTo16BitBoundary(input);
			// Untangle the stored r0-r2 values (the byte swapping earlier messed them up)
			r0=CSInputNextUInt16BE(input);
			r0|=CSInputNextUInt16BE(input)<<16;
			r1=CSInputNextUInt16BE(input);
			r1|=CSInputNextUInt16BE(input)<<16;
			r2=CSInputNextUInt16BE(input);
			r2|=CSInputNextUInt16BE(input)<<16;
		}
		break;
	}
}

-(void)readDeltaLengths:(int *)lengths count:(int)count alternateMode:(BOOL)altmode;
{
	XADPrefixCode *precode=nil;
	int fix=altmode?1:0;

	@try
	{
		int prelengths[20];
		for(int i=0;i<20;i++) prelengths[i]=CSInputNextBitString(input,4);

		precode=[[XADPrefixCode alloc] initWithLengths:prelengths
		numberOfSymbols:20 maximumLength:15 shortestCodeIsZeros:YES];

		int i=0;
		while(i<count)
		{
			int val=CSInputNextSymbolUsingCode(input,precode);
			int n,length;

			if(val<=16)
			{
				n=1;
				length=(lengths[i]+17-val)%17;
			}
			else if(val==17)
			{
				n=CSInputNextBitString(input,4)+4-fix;
				length=0;
			}
			else if(val==18)
			{
				n=CSInputNextBitString(input,5+fix)+20-fix;
				length=0;
			}
			else if(val==19)
			{
				n=CSInputNextBitString(input,1)+4-fix;
				int newval=CSInputNextSymbolUsingCode(input,precode);
				length=(lengths[i]+17-newval)%17;
			}

			for(int j=0;j<n;j++) lengths[i+j]=length;
			i+=n;
		}

		[precode release];
	}
	@catch(id e)
	{
		[precode release];
		@throw;
	}
}


@end
