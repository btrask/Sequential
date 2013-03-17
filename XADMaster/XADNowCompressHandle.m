#import "XADNowCompressHandle.h"
#import "XADException.h"
#import "XADPrefixCode.h"

static int UnpackHuffman(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationstart,uint8_t *destinationend,int numvalues);
static int UnpackLZSS(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationstart,uint8_t *destinationend);
static int UnpackNewLZSS(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationbase,uint8_t *destinationstart,uint8_t *destinationend);

static XADPrefixCode *AllocAndReadCode(uint8_t *source,uint8_t *sourceend,int numentries,uint8_t **newsource);
static void WordAlign(uint8_t *start,uint8_t **curr);
static void CopyBytesWithRepeat(uint8_t *dest,uint8_t *src,int length);

@implementation XADNowCompressHandle

-(id)initWithHandle:(CSHandle *)handle files:(NSMutableArray *)filesarray
{
	if((self=[super initWithName:[handle name]]))
	{
		parent=[handle retain];

		files=[filesarray retain];

		blocks=NULL;
		maxblocks=0;
	}
	return self;
}

-(void)dealloc
{
	free(blocks);
	[parent release];
	[super dealloc];
}

-(void)resetBlockStream
{
	memset(dictionarycache,0,sizeof(dictionarycache));

	nextfile=0;
	numblocks=0;
	nextblock=0;
}

static inline int CheckSum32(uint32_t val) { return (val>>24)+((val>>16)&0xff)+((val>>8)&0xff)+(val&0xff); }
static inline int CheckSum16(uint16_t val) { return (val>>8)+(val&0xff); }

-(BOOL)parseAndCheckFileHeaderWithHeaderOffset:(uint32_t)headeroffset
firstOffset:(uint32_t)firstoffset delta:(int32_t)delta
{
	int numentries=(firstoffset+delta-headeroffset-4)/8-1;

	if(maxblocks<numentries)
	{
		free(blocks);
		blocks=malloc(numentries*sizeof(blocks[0]));
		maxblocks=numentries;
	}

	numblocks=0;

	uint32_t lastoffset=firstoffset;
	uint32_t checksum=CheckSum32(firstoffset);
	BOOL nextisstart=YES;

	for(int i=0;i<numentries;i++)
	{
		int flags=[parent readUInt16BE];
		int padding=[parent readUInt16BE];
		uint32_t nextoffset=[parent readUInt32BE];

		checksum+=CheckSum16(flags);
		checksum+=CheckSum16(padding);
		checksum+=CheckSum32(nextoffset);

		if(nextoffset==lastoffset)
		{
			nextisstart=YES;
			continue;
		}

		blocks[numblocks].offset=lastoffset+delta;
		blocks[numblocks].length=nextoffset-lastoffset-padding-4;
		blocks[numblocks].flags=flags|(nextisstart?0x10000:0); // Mark block as the first in a stream if it is.
		numblocks++;

		lastoffset=nextoffset;
		nextisstart=NO;
	}

	for(int i=0;i<4;i++) checksum+=[parent readUInt8];

	uint32_t correctchecksum=[parent readUInt32BE];

	return checksum==correctchecksum;
}

-(int)findFileHeaderDeltaWithHeaderOffset:(uint32_t)headeroffset firstOffset:(uint32_t)firstoffset
{
	[parent seekToFileOffset:headeroffset];

	uint32_t checksum=0;
	for(int i=0;i<16;i++) checksum+=[parent readUInt8];

	for(int n=2;n<0x2000;n++)
	{
		uint8_t buf[4];
		[parent readBytes:4 toBuffer:buf];

		if(CSUInt32BE(buf)==checksum) return headeroffset+n*8+4-firstoffset;

		for(int i=0;i<4;i++) checksum+=buf[i];
		for(int i=0;i<4;i++) checksum+=[parent readUInt8];
	}

	return 0;
}

-(BOOL)readNextFileHeader
{
	if(nextfile>=[files count]) return NO;

	uint32_t headeroffset=[[files objectAtIndex:nextfile] unsignedIntValue];
	[parent seekToFileOffset:headeroffset];

	uint32_t firstoffset=[parent readUInt32BE];

	// Sometimes, the offsets in the stream header are off. How to figure
	// out the proper delta is unknown, so we just use a heuristic to detect
	// the end of the header and use that if the offsets look suspicious,
	// or if the checksum fails when trying with zero offset.
	if(firstoffset<headeroffset+20)
	{
		// Offsets are obviously wrong, so don't even try, just estimate.
		int32_t delta=[self findFileHeaderDeltaWithHeaderOffset:headeroffset
		firstOffset:firstoffset];

		[parent seekToFileOffset:headeroffset+4];
		if(![self parseAndCheckFileHeaderWithHeaderOffset:headeroffset
		firstOffset:firstoffset delta:delta])
		[XADException raiseIllegalDataException];
	}
	else
	{
		// Try the easy way. Calculate the number of entries that fit in the
		// header, and try parsing. If the checksum does not match or an 
		// exception is thrown, try estimating instead.
		BOOL success;
		@try {
			success=[self parseAndCheckFileHeaderWithHeaderOffset:headeroffset
			firstOffset:firstoffset delta:0];
		} @catch(id e) {
			success=NO;
		}

		if(!success)
		{
			int32_t delta=[self findFileHeaderDeltaWithHeaderOffset:headeroffset
			firstOffset:firstoffset];

			[parent seekToFileOffset:headeroffset+4];
			if(![self parseAndCheckFileHeaderWithHeaderOffset:headeroffset
			firstOffset:firstoffset delta:delta])
			[XADException raiseIllegalDataException];
		}
	}

	nextfile++;
	nextblock=0;

	return YES;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	if(nextblock>=numblocks)
	{
		if(![self readNextFileHeader]) return 0;
	}

	uint32_t offset=blocks[nextblock].offset;
	int flags=blocks[nextblock].flags;
	uint32_t length=blocks[nextblock].length;
	nextblock++;

	// This is kind of absurd. Can this really be how it is supposed to work?
	if(flags&0x10000) memcpy(outblock,dictionarycache,0x8000);

	if(length>sizeof(inblock)) [XADException raiseDecrunchException];

	[parent seekToFileOffset:offset];

	uint8_t *outstart=outblock+0x8000;
	int outlength;

	if(flags&0x20)
	{
		if(flags&0x1f) // LZSS and Huffman.
		{
			[parent readBytes:length toBuffer:outstart];

			int outlength1=UnpackHuffman(outstart,outstart+length,inblock,inblock+sizeof(inblock),0x100);
			if(!outlength1) [XADException raiseDecrunchException];

			outlength=UnpackLZSS(inblock,inblock+outlength1,outstart,outblock+sizeof(outblock));
			if(!outlength) [XADException raiseDecrunchException];
		}
		else // Huffman only.
		{
			[parent readBytes:length toBuffer:inblock];

			outlength=UnpackHuffman(inblock,inblock+length,outstart,outblock+sizeof(outblock),0x100);
			if(!outlength) [XADException raiseDecrunchException];
		}
	}
	else if(flags&0x40) // New LZSS.
	{
		[parent readBytes:length toBuffer:inblock];

		outlength=UnpackNewLZSS(inblock,inblock+length,outblock,outstart,outblock+sizeof(outblock));
		if(!outlength) [XADException raiseDecrunchException];
	}
	else
	{
		if(flags&0x1f) // LZSS only.
		{
			[parent readBytes:length toBuffer:inblock];

			outlength=UnpackLZSS(inblock,inblock+length,outstart,outblock+sizeof(outblock));
			if(!outlength) [XADException raiseDecrunchException];
		}
		else // No compression.
		{
			[parent readBytes:length toBuffer:outstart];
			outlength=length;
		}
	}

	memmove(outblock,outblock+outlength,0x8000);
	// Absurdity, part 2.
	if(flags&0x10000) memcpy(dictionarycache,outblock,0x8000);
	[self setBlockPointer:outstart-outlength];

	return outlength;
}

@end

static int UnpackHuffman(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationstart,uint8_t *destinationend,int numvalues)
{
	uint8_t *source=sourcestart;
	uint8_t *destination=destinationstart;

	if(source>=sourceend) [XADException raiseDecrunchException];
	int endbits=*source++;

	XADPrefixCode *code=nil;
	CSInputBuffer *buf=NULL;

	@try
	{
		code=AllocAndReadCode(source,sourceend,numvalues,&source);

		WordAlign(sourcestart,&source);

		buf=CSInputBufferAllocWithBuffer(source,sourceend-source,0);

		int numbits=(sourceend-source)*8;
		if(endbits) numbits-=16-endbits;

		while(CSInputBufferBitOffset(buf)<numbits)
		{
			if(destination>=destinationend) [XADException raiseDecrunchException];
			*destination++=CSInputNextSymbolUsingCode(buf,code);
		}

		if(CSInputBufferBitOffset(buf)!=numbits) [XADException raiseDecrunchException];
	}
	@catch(id e)
	{
		[code release];
		CSInputBufferFree(buf);
		@throw;
	}

	[code release];
	CSInputBufferFree(buf);

	return destination-destinationstart;
}

static int UnpackLZSS(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationstart,uint8_t *destinationend)
{
	uint8_t *source=sourcestart+2;
	uint8_t *destination=destinationstart;

	int bits,numbits=0;
	while(source<sourceend)
	{
		if(!numbits)
		{
			bits=*source++;
			numbits=8;

			if(source>=sourceend) [XADException raiseDecrunchException];
		}

		if(bits&0x80)
		{
			if(destination>=destinationend) [XADException raiseDecrunchException];
			*destination++=*source++;
		}
		else
		{
			int b1=*source++;
			if(source>=sourceend) [XADException raiseDecrunchException];
			int b2=*source++;

			int offset=((b1&0xf8)<<5)|b2;

			int length=b1&0x07;
			if(!length)
			{
				if(source>=sourceend) [XADException raiseDecrunchException];
				length=*source++;
			}
			length+=2;

			if(destination-offset<destinationstart) [XADException raiseDecrunchException];

			for(int i=0;i<length;i++)
			{
				if(destination>=destinationend) [XADException raiseDecrunchException];
				destination[0]=destination[-offset];
				destination++;
			}
		}

		bits<<=1;
		numbits--;
	}

	return destination-destinationstart;
}

static int UnpackNewLZSS(uint8_t *sourcestart,uint8_t *sourceend,
uint8_t *destinationbase,uint8_t *destinationstart,uint8_t *destinationend)
{
	const static int lengthextrabits[0x22]={
		0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
		0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
		0x01,0x01,0x02,0x02,0x02,0x02,0x02,0x03,
		0x03,0x03,0x04,0x04,0x04,0x04,0x05,0x05,
		0x05,0x05,
	};
	const static int lengthbases[0x22]={
		0x0000,0x0001,0x0002,0x0003,0x0004,0x0005,0x0006,0x0007,
		0x0008,0x0009,0x000a,0x000b,0x000c,0x000d,0x000e,0x000f,
		0x0010,0x0012,0x0014,0x0018,0x001c,0x0020,0x0024,0x0028,
		0x0030,0x0038,0x0040,0x0050,0x0060,0x0070,0x0080,0x00a0,
		0x00c0,0x00e0,
	};

	const static int offsetextrabits[0x38]={
		0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,
		0x01,0x01,0x01,0x01,0x02,0x02,0x02,0x02,
		0x03,0x03,0x03,0x03,0x04,0x04,0x04,0x04,
		0x05,0x05,0x05,0x05,0x08,0x08,0x08,0x08,
		0x08,0x08,0x08,0x08,0x09,0x09,0x09,0x09,
		0x0A,0x0A,0x0A,0x0A,0x0B,0x0B,0x0B,0x0B,
		0x0C,0x0C,0x0C,0x0C,0x0D,0x0D,0x0D,0x0D,
	};
	const static int offsetbases[0x38]={
		0x0000,0x0001,0x0002,0x0003,0x0004,0x0005,0x0006,0x0007,
		0x0008,0x000a,0x000c,0x000e,0x0010,0x0014,0x0018,0x001c,
		0x0020,0x0028,0x0030,0x0038,0x0040,0x0050,0x0060,0x0070,
		0x0080,0x00a0,0x00c0,0x00e0,0x0100,0x0200,0x0300,0x0400,
		0x0500,0x0600,0x0700,0x0800,0x0900,0x0b00,0x0d00,0x0f00,
		0x1100,0x1500,0x1900,0x1d00,0x2100,0x2900,0x3100,0x3900,
		0x4100,0x5100,0x6100,0x7100,0x8100,0xa100,0xc100,0xe100,
	};

	uint8_t *source=sourcestart;
	uint8_t *destination=destinationstart;

	if(source+4>sourceend) [XADException raiseDecrunchException];
	int headersize=CSUInt16BE(source)-0x2f59;
	int endbits=source[3];
	source+=4;

	if(source+headersize>sourceend) [XADException raiseDecrunchException];
	uint8_t header[0x15a];
	int length=UnpackHuffman(source,source+headersize,header,header+sizeof(header),20);
	if(length!=sizeof(header)) [XADException raiseDecrunchException];

	source+=headersize;
	WordAlign(sourcestart,&source);

	XADPrefixCode *maincode=nil,*offsetcode=nil;
	CSInputBuffer *buf=NULL;

	@try
	{
		int lengths[0x122];

		for(int i=0;i<0x122;i++) lengths[i]=header[i];
		maincode=[[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:0x122
		maximumLength:20 shortestCodeIsZeros:YES];

		for(int i=0;i<0x38;i++) lengths[i]=header[i+0x122]?header[i+0x122]-2:0;
		offsetcode=[[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:0x38
		maximumLength:20 shortestCodeIsZeros:YES];

		buf=CSInputBufferAllocWithBuffer(source,sourceend-source,0);

		int numbits=(sourceend-source)*8;
		if(endbits) numbits-=16-endbits;

		while(CSInputBufferBitOffset(buf)<numbits)
		{
			int symbol=CSInputNextSymbolUsingCode(buf,maincode);
			if(symbol<0x100)
			{
				if(destination>=destinationend) [XADException raiseDecrunchException];
				*destination++=symbol;
			}
			else
			{
				int lengthselector=symbol-0x100;
				int length=lengthbases[lengthselector];
				if(lengthextrabits[lengthselector]) length+=CSInputNextBitString(buf,lengthextrabits[lengthselector]);
				length+=2;

				int offsetselector=CSInputNextSymbolUsingCode(buf,offsetcode);
				int offset=offsetbases[offsetselector];
				if(offsetextrabits[offsetselector]) offset+=CSInputNextBitString(buf,offsetextrabits[offsetselector]);

				if(destination+length>destinationend) [XADException raiseDecrunchException];
				if(destination-offset<destinationbase) [XADException raiseDecrunchException];

				for(int i=0;i<length;i++)
				{
					destination[0]=destination[-offset];
					destination++;
				}
			}
		}
	}
	@catch(id e)
	{
		CSInputBufferFree(buf);
		[maincode release];
		[offsetcode release];
		@throw;
	}

	CSInputBufferFree(buf);
	[maincode release];
	[offsetcode release];

	return destination-destinationstart;
}

static XADPrefixCode *AllocAndReadCode(uint8_t *sourcestart,uint8_t *sourceend,int numentries,uint8_t **newsource)
{
	uint8_t *source=sourcestart;

	int lengths[numentries];
	for(int i=0;i<numentries/2;i++)
	{
		if(source>=sourceend) [XADException raiseDecrunchException];
		uint8_t val=*source++;

		lengths[2*i]=val>>4;
		lengths[2*i+1]=val&0x0f;
	}

	if(source>=sourceend) [XADException raiseDecrunchException];
	int extralengths=*source++;

	for(int i=0;i<extralengths;i++)
	{
		if(source>=sourceend) [XADException raiseDecrunchException];
		lengths[*source++]+=16;
	}

	if(newsource) *newsource=source;

	return [[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:numentries
	maximumLength:31 shortestCodeIsZeros:YES];
}

static void WordAlign(uint8_t *start,uint8_t **curr)
{
	if(*curr-start&1) (*curr)++;
}
