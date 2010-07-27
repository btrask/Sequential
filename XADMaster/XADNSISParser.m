#import "XADNSISParser.h"
#import "XADNSISBzip2Handle.h"
#import "XADDeflateHandle.h"
#import "XADLZMAHandle.h"
#import "XAD7ZipBranchHandles.h"
#import "CSZlibHandle.h"
#import "NSDateXAD.h"

#define UndetectedFormat 0
#define ZlibFormat 1
#define NSISDeflateFormat 2
#define NSIS1Bzip2Format 3
#define NSIS2Bzip2Format 4
#define LZMAFormat 5
#define FilteredLZMAFormat 6

#define DollarExpansionType	1
#define OldBinaryExpansionType 2
#define NewBinaryExpansionType 4

// Beware all who venture within: This is nothing but a big pile of heuristics, hacks and
// kludges. That it works at all is nothing short of a miracle.

static int IndexOfLargestEntry(const int *entries,int num);

static BOOL IsOlderSignature(const uint8_t *ptr)
{
	static const uint8_t OlderSignature[16]={0xec,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x53,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};
	static const uint8_t OlderSignatureCRC[16]={0xed,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x53,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};
	if(memcmp(ptr,OlderSignature,16)==0) return YES;
	if(memcmp(ptr,OlderSignatureCRC,16)==0) return YES;
	return NO;
}

static BOOL IsOldSignature(const uint8_t *ptr)
{
	static const uint8_t OldSignature[16]={0xef,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x53,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};
	if(memcmp(ptr+4,OldSignature,16)!=0) return NO;
	if(CSUInt32LE(ptr)&2) return NO; // uninstaller
	return YES;
}

static BOOL IsNewSignature(const uint8_t *ptr)
{
	static const uint8_t NewSignature[16]={0xef,0xbe,0xad,0xde,0x4e,0x75,0x6c,0x6c,0x73,0x6f,0x66,0x74,0x49,0x6e,0x73,0x74};
	if(memcmp(ptr+4,NewSignature,16)!=0) return NO;
	if(CSUInt32LE(ptr)&2) return NO; // uninstaller
	return YES;
}

static BOOL LooksLikeLZMA(uint8_t *sig)
{
	return sig[0]==0x5d&&sig[1]==0x00&&sig[2]==0x00&&sig[5]==0x00;
}

static BOOL LooksLikeFilteredLZMA(uint8_t *sig)
{
	return (sig[0]==0||sig[0]==1)&&LooksLikeLZMA(sig+1);
}

static BOOL LooksLikeNSISBzip2(uint8_t *sig)
{
	return sig[0]=='1'&&((sig[1]<<16)+(sig[2]<<8)+sig[3]<900000);
}

static BOOL LooksLikeZlib(uint8_t *sig)
{
	return sig[0]==0x78&&sig[1]==0xda;
}




@implementation XADNSISParser

+(int)requiredHeaderSize { return 0x10000; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	for(int offs=0;offs<length+4+16;offs+=512)
	{
		if(IsOlderSignature(bytes+offs)) return YES;
		if(IsOldSignature(bytes+offs)) return YES;
		if(IsNewSignature(bytes+offs)) return YES;
	}
	return NO;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super initWithHandle:handle name:name])
	{
		solidhandle=nil;
		detectedformat=UndetectedFormat;
		expansiontypes=0;
		_outdir=nil;
	}
	return self;
}

-(void)dealloc
{
	[solidhandle release];
	[super dealloc];
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:512];
	for(;;)
	{
		uint8_t buf[20];
		[fh readBytes:sizeof(buf) toBuffer:buf];

		if(IsOlderSignature(buf)) { [fh skipBytes:-(int)sizeof(buf)]; [self parseOlderFormat]; return; }
		if(IsOldSignature(buf)) { [fh skipBytes:-(int)sizeof(buf)]; [self parseOldFormat]; return; }
		if(IsNewSignature(buf)) { [fh skipBytes:-(int)sizeof(buf)]; [self parseNewFormat]; return; }
		[fh skipBytes:512-(int)sizeof(buf)];
	}
}

// Versions 1.1o to 1.2g - opcode 3, stride 7
-(void)parseOlderFormat
{
	CSHandle *fh=[self handle];

	detectedformat=ZlibFormat;
	expansiontypes=DollarExpansionType;

	uint32_t signature=[fh readUInt32LE];
	[fh skipBytes:12];

	uint32_t headerlength=[fh readUInt32LE];
	uint32_t headeroffset=[fh readUInt32LE];
	uint32_t totallength=[fh readUInt32LE];

	uint32_t datalength=totallength-28;
	if(signature&1) datalength-=4;

	if(headerlength+headeroffset+4<totallength)
	{
		// Versions 1.1o to 1.1x
		//NSLog(@"path 1a");

		uint32_t complength=headerlength;
		uint32_t uncomplength=headeroffset;

		base=[fh offsetInFile]+complength;

		CSHandle *hh=[fh nonCopiedSubHandleOfLength:complength];
		if(uncomplength) hh=[CSZlibHandle zlibHandleWithHandle:hh length:uncomplength];
		NSData *header=[hh readDataOfLength:uncomplength];

		[fh seekToFileOffset:base];
		NSDictionary *blocks=[self findBlocksWithHandle:[fh nonCopiedSubHandleOfLength:datalength-complength-4]];

		int stringtable=[self findStringTableOffsetInData:header maxOffsets:7];

		int stride,phase;
		int extractopcode=[self findOpcodeWithData:header blocks:blocks
		startOffset:24 endOffset:stringtable
		stringStartOffset:stringtable stringEndOffset:uncomplength
		opcodePossibilities:(int[]){3} count:1
		stridePossibilities:(int[]){7} count:1
		foundStride:&stride foundPhase:&phase];

		[self parseOpcodesWithHeader:header blocks:blocks
		extractOpcode:extractopcode ignoreOverwrite:NO
		directoryOpcode:extractopcode-2 directoryArgument:0 assignOpcode:-1
		startOffset:(stride+phase)*4 endOffset:stringtable stride:stride
		stringStartOffset:stringtable stringEndOffset:uncomplength unicode:NO];
	}
	else
	{
		// Versions 1.1y to 1.2g
		//NSLog(@"path 1b");

		CSHandle *fh=[self handle];

		base=[fh offsetInFile];
		NSDictionary *blocks=[self findBlocksWithHandle:[fh nonCopiedSubHandleOfLength:datalength]];

		CSHandle *hh=[self handleForBlockAtOffset:headeroffset length:headerlength];
		NSData *header=[hh readDataOfLength:headerlength];

		int stringtable=[self findStringTableOffsetInData:header maxOffsets:16];

		int stride,phase;
		int extractopcode=[self findOpcodeWithData:header blocks:blocks
		startOffset:24 endOffset:stringtable 
		stringStartOffset:stringtable stringEndOffset:headerlength
		opcodePossibilities:(int[]){3} count:1
		stridePossibilities:(int[]){7} count:1
		foundStride:&stride foundPhase:&phase];

		[self parseOpcodesWithHeader:header blocks:blocks
		extractOpcode:extractopcode ignoreOverwrite:NO
		directoryOpcode:extractopcode-2 directoryArgument:0 assignOpcode:-1
		startOffset:(stride+phase)*4 endOffset:stringtable stride:stride
		stringStartOffset:stringtable stringEndOffset:headerlength unicode:NO];
	}
}

// Versions 1.30 to 1.59 - opcodes 4, 5, strides 7, 6
-(void)parseOldFormat
{
	CSHandle *fh=[self handle];

	detectedformat=ZlibFormat;
	expansiontypes=DollarExpansionType;

	uint32_t flags=[fh readUInt32LE];
	[fh skipBytes:16];

	uint32_t headerlength=[fh readUInt32LE];
	uint32_t headeroffset=[fh readUInt32LE];
	uint32_t totallength=[fh readUInt32LE];

	uint32_t datalength=totallength-32;
	if(flags&1) datalength-=4;

	base=[fh offsetInFile];
	NSDictionary *blocks=[self findBlocksWithHandle:[fh nonCopiedSubHandleOfLength:datalength]];

	CSHandle *hh=[self handleForBlockAtOffset:headeroffset length:headerlength];
	NSData *header=[hh readDataOfLength:headerlength];

	int stringtable=[self findStringTableOffsetInData:header maxOffsets:16];

	int stride,phase;
	int extractopcode=[self findOpcodeWithData:header blocks:blocks
	startOffset:24 endOffset:stringtable
	stringStartOffset:stringtable stringEndOffset:headerlength
	opcodePossibilities:(int[]){4,5} count:2
	stridePossibilities:(int[]){6,7} count:2
	foundStride:&stride foundPhase:&phase];

	if(stride==6&&extractopcode==4)
	{
		// Versions 1.54 - 1.59 - new directory opcode
		//NSLog(@"path 2b");

		[self parseOpcodesWithHeader:header blocks:blocks
		extractOpcode:4 ignoreOverwrite:NO
		directoryOpcode:3 directoryArgument:1 assignOpcode:-1
		startOffset:(stride+phase)*4 endOffset:stringtable stride:stride
		stringStartOffset:stringtable stringEndOffset:headerlength unicode:NO];
	}
	else
	{
		// Versions 1.30 - 1.53 - old directory opcode
		//NSLog(@"path 2a");

		[self parseOpcodesWithHeader:header blocks:blocks
		extractOpcode:extractopcode ignoreOverwrite:NO
		directoryOpcode:extractopcode-2 directoryArgument:0 assignOpcode:-1
		startOffset:(stride+phase)*4 endOffset:stringtable stride:stride
		stringStartOffset:stringtable stringEndOffset:headerlength unicode:NO];
	}
}

// Versions 1.60 and newer
-(void)parseNewFormat
{
	CSHandle *fh=[self handle];

	uint32_t flags=[fh readUInt32LE];
	[fh skipBytes:16];

	uint32_t headerlength=[fh readUInt32LE];
	uint32_t totallength=[fh readUInt32LE];

	uint32_t datalength=totallength-32;
	if(flags&1) datalength-=4;

	uint8_t sig[7];
	[fh readBytes:sizeof(sig) toBuffer:sig];
	[fh skipBytes:-(int)sizeof(sig)];
	off_t pos=[fh offsetInFile];

	if(LooksLikeLZMA(sig)) [self attemptSolidHandleAtPosition:pos format:LZMAFormat headerLength:headerlength];
	if(!solidhandle && LooksLikeFilteredLZMA(sig)) [self attemptSolidHandleAtPosition:pos format:FilteredLZMAFormat headerLength:headerlength];
	if(!solidhandle && LooksLikeNSISBzip2(sig))
	{
		[self attemptSolidHandleAtPosition:pos format:NSIS2Bzip2Format headerLength:headerlength];
		if(!solidhandle) [self attemptSolidHandleAtPosition:pos format:NSIS1Bzip2Format headerLength:headerlength];
	}
	if(!solidhandle) [self attemptSolidHandleAtPosition:pos format:NSISDeflateFormat headerLength:headerlength];

	NSData *header;
	NSDictionary *blocks;

	if(solidhandle)
	{
		// Versions 1.80 and newer - solid
		//NSLog(@"path 3b");

		header=[solidhandle readDataOfLength:headerlength];

		base=headerlength+4;
		blocks=[self findBlocksWithHandle:solidhandle];
	}
	else
	{
		// Not solid
		//NSLog(@"path 3a");

		[fh seekToFileOffset:pos];

		uint32_t headerblocklen=[fh readUInt32LE];
		uint32_t headercompsize=headerblocklen&0x7fffffff;
		base=pos+4+headercompsize;

		//blocks=[self findBlocksWithTotalSize:datalength];
		CSHandle *hh=[self handleForBlockAtOffset:-(int)headercompsize-4 length:headerlength];
		header=[hh readDataOfLength:headerlength];

		[fh seekToFileOffset:base];
		blocks=[self findBlocksWithHandle:[fh nonCopiedSubHandleOfLength:datalength-headercompsize]];
	}

	if([self isSectionedHeader:header])
	{
		// Versions 2.0 and newer - header data is in sections
		//NSLog(@"subpath 2");

		const uint8_t *bytes=[header bytes];

		uint32_t entryoffs=CSUInt32LE(&bytes[20]);
		uint32_t entrynum=CSUInt32LE(&bytes[24]);
		uint32_t stringoffs=CSUInt32LE(&bytes[28]);
		uint32_t nextoffs=CSUInt32LE(&bytes[36]);

		expansiontypes=NewBinaryExpansionType;

		BOOL unicode=[self isUnicodeHeader:header stringStartOffset:stringoffs stringEndOffset:nextoffs];

		[self parseOpcodesWithHeader:header blocks:blocks
		extractOpcode:20 ignoreOverwrite:YES
		directoryOpcode:11 directoryArgument:1 assignOpcode:25
		startOffset:entryoffs endOffset:entryoffs+entrynum*4*7 stride:7
		stringStartOffset:stringoffs stringEndOffset:nextoffs unicode:unicode];
	}
	else
	{
		// Versions 1.60 - 1.98 - old-style header
		//NSLog(@"subpath 1");

		int stringtable=[self findStringTableOffsetInData:header maxOffsets:6];
		int stride,phase;
		int extractopcode=[self findOpcodeWithData:header blocks:blocks
		startOffset:24 endOffset:stringtable 
		stringStartOffset:stringtable stringEndOffset:headerlength
		opcodePossibilities:(int[]){15,17,18,20,21} count:5
		stridePossibilities:(int[]){6} count:1
		foundStride:&stride foundPhase:&phase];

		int diropcode;
		if(extractopcode==21) diropcode=14;
		else if(extractopcode==20) diropcode=13;
		else if(extractopcode==18) diropcode=12;
		else diropcode=11;

		expansiontypes=DollarExpansionType|OldBinaryExpansionType;

		[self parseOpcodesWithHeader:header blocks:blocks
		extractOpcode:extractopcode ignoreOverwrite:NO
		directoryOpcode:diropcode directoryArgument:1 assignOpcode:-1
		startOffset:(stride+phase)*4 endOffset:stringtable stride:stride
		stringStartOffset:stringtable stringEndOffset:headerlength unicode:NO];
	}
}



static NSInteger CompareEntryDataOffsets(id first,id second,void *context)
{
	return [[first objectForKey:@"NSISDataOffset"] compare:[second objectForKey:@"NSISDataOffset"]];
}

-(void)parseOpcodesWithHeader:(NSData *)header blocks:(NSDictionary *)blocks
extractOpcode:(int)extractopcode ignoreOverwrite:(BOOL)ignoreoverwrite
directoryOpcode:(int)diropcode directoryArgument:(int)dirarg assignOpcode:(int)assignopcode
startOffset:(int)startoffs endOffset:(int)endoffs stride:(int)stride
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs unicode:(BOOL)unicode
{
	const uint8_t *bytes=[header bytes];
	int length=[header length];
	XADPath *dir=[self XADPath];
	NSMutableArray *array=[NSMutableArray array];

	for(int i=startoffs;i<endoffs&&i+24<=length;i+=4*stride)
	{
		int opcode=CSUInt32LE(bytes+i);
		uint32_t args[6];
		for(int j=1;j<stride;j++) args[j-1]=CSUInt32LE(bytes+i+j*4);

		if(opcode==extractopcode)
		{
			uint32_t overwrite=args[0];
			uint32_t filename=args[1];
			NSNumber *offs=[NSNumber numberWithUnsignedInt:args[2]];
			NSNumber *block=[blocks objectForKey:offs];
			uint32_t datetimehigh=args[3];
			uint32_t datetimelow=args[4];

			if(ignoreoverwrite || overwrite<4)
			if(filename<stringendoffs-stringoffs)
			if(block)
			{
				uint32_t len=[block unsignedIntValue];

				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					[dir pathByAppendingPath:[self expandAnyPathWithOffset:filename
					unicode:unicode header:header stringStartOffset:stringoffs
					stringEndOffset:stringendoffs currentPath:dir]],XADFileNameKey,
					[NSNumber numberWithUnsignedInt:len&0x7fffffff],XADCompressedSizeKey,
					[NSDate XADDateWithWindowsFileTimeLow:datetimelow high:datetimehigh],XADLastModificationDateKey,
					offs,@"NSISDataOffset",
				nil];

				if((len&0x80000000) || solidhandle)
				{
					[dict setObject:[self compressionName] forKey:XADCompressionNameKey];
				}
				else
				{
					[dict setObject:[self XADStringWithString:@"None"] forKey:XADCompressionNameKey];
					[dict setObject:[NSNumber numberWithUnsignedInt:len&0x7fffffff] forKey:XADFileSizeKey];
				}

				[array addObject:dict];

				continue;
			}
		}
		if(opcode==diropcode)
		{
			if(args[1]==dirarg&&args[2]==0&&args[3]==0&&args[4]==0)
			{
				dir=[self expandAnyPathWithOffset:args[0] unicode:unicode header:header
				stringStartOffset:stringoffs stringEndOffset:stringendoffs currentPath:dir];

				continue;
			}
		}
		if(opcode==assignopcode)
		{
			if(args[0]==31||args[0]==29)
			{
				_outdir=[self expandAnyPathWithOffset:args[1] unicode:(BOOL)unicode header:header
				stringStartOffset:stringoffs stringEndOffset:stringendoffs currentPath:dir];
				continue;
			}
		}
	}

	if([array count]==0) return;

	[array sortUsingFunction:CompareEntryDataOffsets context:NULL];

	// Filter out duplicate entries
	NSMutableDictionary *last=[array objectAtIndex:0];
	for(int i=1;i<[array count];i++)
	{
		NSMutableDictionary *dict=[array objectAtIndex:i];

		if([[dict objectForKey:@"NSISDataOffset"] isEqual:[last objectForKey:@"NSISDataOffset"]]
		&&[[dict objectForKey:XADFileNameKey] isEqual:[last objectForKey:XADFileNameKey]])
		{
			[array removeObjectAtIndex:i];
			i--;
		}
		else last=dict;
	}

	// Re-arrange items to make extracting duplicate entries from solid archives
	// a little bit less slow, and put in solidness markers.
	[self makeEntryArrayStrictlyIncreasing:array];

	NSEnumerator *enumerator=[array objectEnumerator];
	NSMutableDictionary *dict;
	while(dict=[enumerator nextObject]) [self addEntryWithDictionary:dict];
}

-(void)makeEntryArrayStrictlyIncreasing:(NSMutableArray *)array
{
	if([array count]<2) return;

	NSMutableArray *rest=[NSMutableArray array];
	NSMutableDictionary *last=[array objectAtIndex:0];
	NSValue *first=[NSValue valueWithNonretainedObject:last];
	for(int i=1;i<[array count];i++)
	{
		NSMutableDictionary *dict=[array objectAtIndex:i];

		if([[dict objectForKey:@"NSISDataOffset"] isEqual:[last objectForKey:@"NSISDataOffset"]])
		{
			[rest addObject:dict];
			[array removeObjectAtIndex:i];
			i--;
		}
		else
		{
			[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsSolidKey];
			[dict setObject:first forKey:XADFirstSolidEntryKey];
			[last setObject:[NSValue valueWithNonretainedObject:dict] forKey:XADNextSolidEntryKey];
			last=dict;
		}
	}

	[self makeEntryArrayStrictlyIncreasing:rest]; // NOTE: Recursive, let's hope we have enough stack!

	[array addObjectsFromArray:rest];
}



-(NSDictionary *)findBlocksWithHandle:(CSHandle *)fh
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];

	@try
	{
		uint32_t size=0;
		while(![fh atEndOfFile])
		{
			uint32_t blocklen=[fh readUInt32LE];
			if([fh atEndOfFile]) break; // hit the CRC in a solid file
			uint32_t reallen=blocklen&0x7fffffff;
			[dict setObject:[NSNumber numberWithUnsignedInt:blocklen] forKey:[NSNumber numberWithInt:size]];
			[fh skipBytes:reallen];
			size+=reallen+4;
		}
	}
	@catch(id e) { NSLog(@"Warning: block scan interrupted"); }

	return dict;
}

-(int)findStringTableOffsetInData:(NSData *)data maxOffsets:(int)maxnumoffsets
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	// Find last location with two zero bytes in a row. The string table shouldn't be anywhere
	// before this. This should be within 4*6 bytes of the string table, as the last opcode
	// should have two zero bytes at its end, and that leaves only a maximum 6 arguments until
	// the start of the string table. In practice, the last argument will proably be zero and
	// we will be at the string table already.
	int lastdouble=0;
	for(int i=0;i+2<=length;i++)
	{
		if(bytes[i]==0&&bytes[i+1]==0) lastdouble=i;
	}

	// Scan the start of the header for things that look like string table offsets.
	uint32_t stringoffset[maxnumoffsets];
	int numoffsets=0;
	int maxoffset=0;
	for(int i=0;i+4<=length && i<maxnumoffsets*4;i+=4)
	{
		uint32_t val=CSUInt32LE(bytes+i);
		if(val!=0 && val+lastdouble+2<length)
		{
			stringoffset[numoffsets]=val;
			numoffsets++;
			if(val>maxoffset) maxoffset=val;
		}
	}

	// Then test 4*6 offsets trying to find the one that has null bytes just before the highest
	// number of possible string starts (some might be pointers into the middle of strings and
	// won't count).
	int maxcount=0,startoffs=lastdouble+2;
	for(int i=lastdouble+2;i<lastdouble+2+4*6;i++)
	{
		int count=0;
		for(int j=0;j<numoffsets;j++)
		{
			if(i+stringoffset[j]<length && bytes[i+stringoffset[j]-1]==0) count++;
		}
		if(count>maxcount)
		{
			startoffs=i;
			maxcount=count;
		}
	}

	return startoffs;
}

-(int)findOpcodeWithData:(NSData *)data blocks:(NSDictionary *)blocks
startOffset:(int)startoffs endOffset:(int)endoffs
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs
opcodePossibilities:(int *)possibleopcodes count:(int)numpossibleopcodes
stridePossibilities:(int *)possiblestrides count:(int)numpossiblestrides
foundStride:(int *)strideptr foundPhase:(int *)phaseptr
{
	// Heuristic to find the size of entries, and the opcode for extract file entries.
	// Find candidates for extract opcodes, and measure the distances between them and
	// which opcodes they have.
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	int maxpossiblestride=possiblestrides[IndexOfLargestEntry(possiblestrides,numpossiblestrides)];
	int strideopcodecounts[numpossiblestrides][numpossibleopcodes];
	int stridephasecounts[numpossiblestrides][maxpossiblestride];
	memset(strideopcodecounts,0,sizeof(strideopcodecounts));
	memset(stridephasecounts,0,sizeof(stridephasecounts));

	int lastpos=0;
	for(int i=startoffs;i<endoffs&&i+24<=length;i+=4)
	{
		int opcode=CSUInt32LE(bytes+i);

		for(int j=0;j<numpossibleopcodes;j++)
		if(opcode==possibleopcodes[j]) // possible ExtractFile
		{
			uint32_t overwrite=CSUInt32LE(bytes+i+4);
			uint32_t filenameoffs=CSUInt32LE(bytes+i+8);
			uint32_t dataoffs=CSUInt32LE(bytes+i+12);

			if(overwrite<4)
			if(filenameoffs<stringendoffs-stringoffs)
			if([blocks objectForKey:[NSNumber numberWithInt:dataoffs]])
			{
				int pos=i/4;
				for(int k=0;k<numpossiblestrides;k++)
				if((pos-lastpos)%possiblestrides[k]==0)
				{
					strideopcodecounts[k][j]++;
					stridephasecounts[k][pos%possiblestrides[k]]++;
				}
				lastpos=pos;
			}
			break;
		}
	}

	int totalstrideopcodes[numpossiblestrides];
	memset(totalstrideopcodes,0,sizeof(totalstrideopcodes));
	for(int i=0;i<numpossiblestrides;i++)
	{
		for(int j=0;j<numpossibleopcodes;j++)
		totalstrideopcodes[i]+=strideopcodecounts[i][j];
	}

	int strideindex=IndexOfLargestEntry(totalstrideopcodes,numpossiblestrides);
	int opcodeindex=IndexOfLargestEntry(strideopcodecounts[strideindex],numpossibleopcodes);
	int phase=IndexOfLargestEntry(stridephasecounts[strideindex],possiblestrides[strideindex]);

	//NSLog(@"stride %d, opcode %d, phase %d",possiblestrides[strideindex],possibleopcodes[opcodeindex],phase);

	if(strideptr) *strideptr=possiblestrides[strideindex];
	if(phaseptr) *phaseptr=phase;
	return possibleopcodes[opcodeindex];
}

-(BOOL)isSectionedHeader:(NSData *)header
{
	// Old-style headers have the string table last, and it should not contain double zero
	// bytes. New-style headers have other data after the string table that should contain
	// plenty of zeroes. Check for double zero bytes at the end of the header to recognize
	// new-style sectioned headers.

	const uint8_t *bytes=[header bytes];
	int length=[header length];

	if(length<32) return NO;

	for(int i=length-32;i+2<=length;i++)
	{
		if(bytes[i]==0&&bytes[i+1]==0) return YES;
	}
	return NO;
}

-(BOOL)isUnicodeHeader:(NSData *)header stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs
{
	const uint8_t *bytes=[header bytes];
	int length=[header length];

	for(int i=stringoffs;i+2<=stringendoffs && i+2<=length;i+=2)
	{
		if(bytes[i]==0&&bytes[i+1]==0) return YES;
	}
	return NO;
}


-(XADPath *)expandAnyPathWithOffset:(int)offset unicode:(BOOL)unicode header:(NSData *)header
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs currentPath:(XADPath *)path
{
	if(unicode) return [self expandUnicodePathWithOffset:offset header:header
	stringStartOffset:stringoffs stringEndOffset:stringendoffs currentPath:path];
	else return [self expandPathWithOffset:offset header:header
	stringStartOffset:stringoffs stringEndOffset:stringendoffs currentPath:path];
}

-(XADPath *)expandPathWithOffset:(int)offset header:(NSData *)header
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs currentPath:(XADPath *)path
{
	const uint8_t *headerbytes=[header bytes];
	int headerlength=[header length];

	const uint8_t *bytes=&headerbytes[stringoffs+offset];
	int length=0;
	while(stringoffs+length<headerlength && stringoffs+length<stringendoffs && bytes[length]!=0) length++;

	if(expansiontypes&DollarExpansionType)
	{
		XADPath *result=[self expandDollarVariablesWithBytes:bytes length:length currentPath:path];
		if(result) return result;
	}

	if(expansiontypes&OldBinaryExpansionType)
	{
		XADPath *result=[self expandOldVariablesWithBytes:bytes length:length currentPath:path];
		if(result) return result;
	}

	if(expansiontypes&NewBinaryExpansionType)
	{
		XADPath *result=[self expandNewVariablesWithBytes:bytes length:length currentPath:path];
		if(result) return result;
	}

	return [self XADPathWithBytes:bytes length:length separators:XADWindowsPathSeparator];
}


-(XADPath *)expandDollarVariablesWithBytes:(const uint8_t *)bytes length:(int)length currentPath:(XADPath *)path
{
	NSISVariableExpansion DollarExpansions[]=
	{
		{ "$0","Register 0" },
		{ "$1","Register 1" },
		{ "$2","Register 2" },
		{ "$3","Register 3" },
		{ "$4","Register 4" },
		{ "$5","Register 5" },
		{ "$6","Register 6" },
		{ "$7","Register 7" },
		{ "$8","Register 8" },
		{ "$9","Register 9" },
		{ "$INSTDIR","" },
		{ "$OUTDIR",NULL },
		{ "$EXEDIR","Installer Executable Directory" },
		{ "$PROGRAMFILES","Windows Program Files" },
		{ "$SMPROGRAMS","Windows Start Menu Programs" },
		{ "$SMSTARTUP","Windows Start Menu Startup" },
		{ "$DESKTOP","Windows Desktop" },
		{ "$STARTMENU","Windows Start Menu" },
		{ "$QUICKLAUNCH","Windows Quick Launch" },
		{ "$TEMP","Windows Temporary Directory" },
		{ "$WINDIR","Windows Directory" },
		{ "$SYSDIR","Windows System Directory" },
		{ "$HWNDPARENT","Windows HWNDPARENT" },
	};
	return [self expandVariables:DollarExpansions count:23 bytes:bytes length:length currentPath:path];
}

-(XADPath *)expandOldVariablesWithBytes:(const uint8_t *)bytes length:(int)length currentPath:(XADPath *)path
{
	NSISVariableExpansion OldBinaryExpansions1_6[]=
	{
		{ (char []){ 0xe0,0 },"Register 0" },
		{ (char []){ 0xe1,0 },"Register 1" },
		{ (char []){ 0xe2,0 },"Register 2" },
		{ (char []){ 0xe3,0 },"Register 3" },
		{ (char []){ 0xe4,0 },"Register 4" },
		{ (char []){ 0xe5,0 },"Register 5" },
		{ (char []){ 0xe6,0 },"Register 6" },
		{ (char []){ 0xe7,0 },"Register 7" },
		{ (char []){ 0xe8,0 },"Register 8" },
		{ (char []){ 0xe9,0 },"Register 9" },
		{ (char []){ 0xea,0 },"" },
		{ (char []){ 0xeb,0 },NULL },
		{ (char []){ 0xec,0 },"Installer Executable Directory" },
		{ (char []){ 0xed,0 },"Windows Program Files" },
		{ (char []){ 0xee,0 },"Windows Start Menu Programs" },
		{ (char []){ 0xef,0 },"Windows Start Menu Startup" },
		{ (char []){ 0xf0,0 },"Windows Desktop" },
		{ (char []){ 0xf1,0 },"Windows Start Menu" },
		{ (char []){ 0xf2,0 },"Windows Quick Launch" },
		{ (char []){ 0xf3,0 },"Windows Temporary Directory" },
		{ (char []){ 0xf4,0 },"Windows Directory" },
		{ (char []){ 0xf5,0 },"Windows System Directory" },
		{ (char []){ 0xf6,0 },"HWNDPARENT" },
	};

	NSISVariableExpansion OldBinaryExpansions[]=
	{
		{ (char []){ 0xdc,0 },"CMDLINE, HWNDPARENT" },
		{ (char []){ 0xdd,0 },"HWNDPARENT, Register 0" },
		{ (char []){ 0xde,0 },"Register 0, 1" },
		{ (char []){ 0xdf,0 },"Register 1, 2" },
		{ (char []){ 0xe1,0 },"Register 2, 3" },
		{ (char []){ 0xe2,0 },"Register 3, 4" },
		{ (char []){ 0xe3,0 },"Register 4, 5" },
		{ (char []){ 0xe4,0 },"Register 5, 6" },
		{ (char []){ 0xe5,0 },"Register 6, 7" },
		{ (char []){ 0xe6,0 },"Register 7, 8" },
		{ (char []){ 0xe7,0 },"Register 8, 9" },
		{ (char []){ 0xe8,0 },"Register 9, R0" },
		{ (char []){ 0xe9,0 },"Register R0, R1" },
		{ (char []){ 0xea,0 },"Register R1, R2" },
		{ (char []){ 0xeb,0 },"Register R2, R3" },
		{ (char []){ 0xec,0 },"Register R3, R4" },
		{ (char []){ 0xed,0 },"Register R4, R5" },
		{ (char []){ 0xee,0 },"Register R5, R6" },
		{ (char []){ 0xef,0 },"Register R6, R7" },
		{ (char []){ 0xf0,0 },"Register R7, R8" },
		{ (char []){ 0xf1,0 },"Register R8, R9" },
		{ (char []){ 0xf2,0 },"Register R9, CMDLINE" },
		{ (char []){ 0xf3,0 },"" },
		{ (char []){ 0xf4,0 },NULL },
		{ (char []){ 0xf5,0 },"Installer Executable Directory" },
		{ (char []){ 0xf6,0 },"Windows Program Files" },
		{ (char []){ 0xf7,0 },"Windows Start Menu Programs" },
		{ (char []){ 0xf8,0 },"Windows Start Menu Startup" },
		{ (char []){ 0xf9,0 },"Windows Desktop" },
		{ (char []){ 0xfa,0 },"Windows Start Menu" },
		{ (char []){ 0xfb,0 },"Windows Quick Launch" },
		{ (char []){ 0xfc,0 },"Windows Temporary Directory" },
		{ (char []){ 0xfd,0 },"Windows Directory" },
		{ (char []){ 0xfe,0 },"Windows System Directory" },
	};

	if(detectedformat==ZlibFormat)
	return [self expandVariables:OldBinaryExpansions1_6 count:23 bytes:bytes length:length currentPath:path];
	else
	return [self expandVariables:OldBinaryExpansions count:34 bytes:bytes length:length currentPath:path];
}

-(XADPath *)expandNewVariablesWithBytes:(const uint8_t *)bytes length:(int)length currentPath:(XADPath *)path
{
	NSISVariableExpansion NewBinaryExpansions[]=
	{
		{ (char []){ 0xfd,0x80,0x80,0 },"Register 0" },
		{ (char []){ 0xfd,0x81,0x80,0 },"Register 1" },
		{ (char []){ 0xfd,0x82,0x80,0 },"Register 2" },
		{ (char []){ 0xfd,0x83,0x80,0 },"Register 3" },
		{ (char []){ 0xfd,0x84,0x80,0 },"Register 4" },
		{ (char []){ 0xfd,0x85,0x80,0 },"Register 5" },
		{ (char []){ 0xfd,0x86,0x80,0 },"Register 6" },
		{ (char []){ 0xfd,0x87,0x80,0 },"Register 7" },
		{ (char []){ 0xfd,0x88,0x80,0 },"Register 8" },
		{ (char []){ 0xfd,0x89,0x80,0 },"Register 9" },
		{ (char []){ 0xfd,0x8a,0x80,0 },"Register R0" },
		{ (char []){ 0xfd,0x8b,0x80,0 },"Register R1" },
		{ (char []){ 0xfd,0x8c,0x80,0 },"Register R2" },
		{ (char []){ 0xfd,0x8d,0x80,0 },"Register R3" },
		{ (char []){ 0xfd,0x8e,0x80,0 },"Register R4" },
		{ (char []){ 0xfd,0x8f,0x80,0 },"Register R5" },
		{ (char []){ 0xfd,0x90,0x80,0 },"Register R6" },
		{ (char []){ 0xfd,0x91,0x80,0 },"Register R7" },
		{ (char []){ 0xfd,0x92,0x80,0 },"Register R8" },
		{ (char []){ 0xfd,0x93,0x80,0 },"Register R9" },
		{ (char []){ 0xfd,0x94,0x80,0 },"CMDLINE" },
		{ (char []){ 0xfd,0x95,0x80,0 },"" }, // OUTDIR
		{ (char []){ 0xfd,0x96,0x80,0 },NULL },
		{ (char []){ 0xfd,0x97,0x80,0 },"Installer Executable Directory" },
		{ (char []){ 0xfd,0x98,0x80,0 },"Language" },
		{ (char []){ 0xfd,0x99,0x80,0 },"Windows Temporary Directory" },
		{ (char []){ 0xfd,0x9a,0x80,0 },"NSIS Plugins Directory" },
		{ (char []){ 0xfd,0x9b,0x80,0 },"Installer Executable Path" },
		{ (char []){ 0xfd,0x9c,0x80,0 },"Installer Executable Name" },
		{ (char []){ 0xfd,0x9d,0x80,0 },NULL }, // HWNDPARENT, apparently this was _OUTDIR in some version?
		{ (char []){ 0xfd,0x9e,0x80,0 },"_CLICK" },
		{ (char []){ 0xfd,0x9f,0x80,0 },NULL }, // _OUTDIR
		// TODO: work out the right constants for these and more
/*		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Directory" },
		{ (char []){ 0xfe,0x81,0x80,0 },"Windows System Directory" },
		{ (char []){ 0xfe,0x95,0x80,0 },"Windows Start Menu Programs" },
		{ (char []){ 0xfe,0x95,0x80,0 },"Windows Start Menu Startup" },
		{ (char []){ 0xfe,0x95,0x80,0 },"Windows Desktop" },
		{ (char []){ 0xfe,0x95,0x80,0 },"Windows Start Menu" },
		{ (char []){ 0xfe,0x95,0x80,0 },"Windows Quick Launch" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Documents" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Send To" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Recent" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Favourites" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Music" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Pictures" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Videos" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Network Places" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Fonts" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Templates" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Application Data" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Local Application Data" },
		{ (char []){ 0xfe,0x80,0x80,0 },"Windows Program Files" },*/
	};

	return [self expandVariables:NewBinaryExpansions count:32 bytes:bytes length:length currentPath:path];
}

-(XADPath *)expandVariables:(NSISVariableExpansion *)expansions count:(int)count
bytes:(const uint8_t *)bytes length:(int)length currentPath:(XADPath *)dir
{
	NSMutableData *data=nil;
	XADPath *prependdir=nil;

	for(int i=0;i<length;i++)
	{
		BOOL found=NO;
		for(int j=0;j<count && !found;j++)
		{
			int varlen=strlen(expansions[j].variable);
			if(i+varlen<=length && strncmp((const char *)&bytes[i],expansions[j].variable,varlen)==0)
			{
				if(!data) data=[NSMutableData dataWithBytes:bytes length:i];

				const char *exp=expansions[j].expansion;
				if(!exp)
				{
					if(i==0)
					{
						if(j<=23) prependdir=dir;
						else prependdir=_outdir;
					}
					exp="";
				}

				int explen=strlen(exp);
				if(!explen)
				{
					if(i==0&&bytes[varlen]=='\\') i++; // Skip leading slashes for empty expansions
				}
				else
				{
					[data appendBytes:exp length:explen];
				}

				i+=varlen-1;
				found=YES;
			}
		}

		if(!found) [data appendBytes:&bytes[i] length:1];
	}

	if(data)
	{
		XADPath *path=[self XADPathWithData:data separators:XADWindowsPathSeparator];
		if(prependdir) return [prependdir pathByAppendingPath:path];
		else return path;
	}
	else return nil;
}

-(XADPath *)expandUnicodePathWithOffset:(int)offset header:(NSData *)header
stringStartOffset:(int)stringoffs stringEndOffset:(int)stringendoffs currentPath:(XADPath *)dir
{
	static NSString *strings[]=
	{
		@"Register 0",@"Register 1",@"Register 2",@"Register 3",@"Register 4",
		@"Register 5",@"Register 6",@"Register 7",@"Register 8",@"Register 9",
		@"Register R0",@"Register R1",@"Register R2",@"Register R3",@"Register R4",
		@"Register R5",@"Register R6",@"Register R7",@"Register R8",@"Register R9",
		@"CMDLINE",
		@"", // INSTDIR
		nil,
		@"Installer Executable Directory",
		@"Language",
		@"Windows Temporary Directory",
		@"NSIS Plugins Directory",
		@"Installer Executable Path",
		@"Installer Executable Name",
		nil,// apparently this was _OUTDIR in some version?
		@"_CLICK",
		nil, // _OUTDIR
	};

	const uint8_t *headerbytes=[header bytes];
	int headerlength=[header length];

	const uint8_t *bytes=&headerbytes[stringoffs+offset*2];
	int length=0;
	while(stringoffs+length*2<headerlength && stringoffs+length*2<stringendoffs
	&& !(bytes[2*length]==0 && bytes[2*length+1]==0)) length++;

	NSMutableString *string=[NSMutableString string];
	XADPath *prependdir=nil;

	for(int i=0;i<length;i++)
	{
		uint16_t c=CSUInt16LE(&bytes[i*2]);
		if(c==0xe001 && i+1<length)
		{
			uint16_t val=CSUInt16LE(&bytes[i*2+2])&0x7fff;
			if(val<32) 
			{
				NSString *exp=strings[val];

				if(!exp) // handle OUTDIR and _OUTDIR (only at string head, though)
				{
					if(i==0)
					{
						if(val==22) prependdir=dir;
						else prependdir=_outdir;
					}
					exp=@"";
				}

				[string appendString:exp];

				// Skip leading slashes for empty expansions
				if(i==0&&length>=3&&[exp length]==0&&CSUInt16LE(&bytes[i*2+4])=='\\') i++;
			}
			else [string appendFormat:@"User variable 0x%x",CSUInt16LE(&bytes[i*2+2])];

			i++;
		}
		else if(c==0xe002 && i+1<length)
		{
			[string appendFormat:@"Shell variable 0x%x",CSUInt16LE(&bytes[i*2+2])];
			i++;
		}
		else [string appendFormat:@"%C",c];
	}

	NSArray *parts;
	if([string length]==0) parts=[NSArray array];
	else parts=[string componentsSeparatedByString:@"\\"];
	NSMutableArray *array=[NSMutableArray arrayWithCapacity:[parts count]];
	NSEnumerator *enumerator=[parts objectEnumerator];
	NSString *part;
	while(part=[enumerator nextObject]) [array addObject:[self XADStringWithString:part]];

	XADPath *path=[[[XADPath alloc] initWithComponents:array] autorelease];

	if(prependdir) return [prependdir pathByAppendingPath:path];
	else return path;
}



-(CSHandle *)handleForBlockAtOffset:(off_t)offs
{
	return [self handleForBlockAtOffset:offs length:CSHandleMaxLength];
}

-(CSHandle *)handleForBlockAtOffset:(off_t)offs length:(off_t)length
{
	CSHandle *fh;
	if(solidhandle) fh=solidhandle;
	else fh=[self handle];
	[fh seekToFileOffset:offs+base];

	uint32_t blocklen=[fh readUInt32LE];
	CSHandle *sub=[fh nonCopiedSubHandleOfLength:blocklen&0x7fffffff];
	if((blocklen&0x80000000))
	{
		if(detectedformat==UndetectedFormat)
		{
			uint8_t sig[7];
			[fh readBytes:sizeof(sig) toBuffer:sig];
			[fh skipBytes:-(int)sizeof(sig)];

			if(LooksLikeLZMA(sig)) detectedformat=LZMAFormat;
			else if(LooksLikeFilteredLZMA(sig)) detectedformat=FilteredLZMAFormat;
			else if(LooksLikeNSISBzip2(sig)) detectedformat=NSIS2Bzip2Format; // NOTE: Autodetection only detects v2.0+ files!
			else if(LooksLikeZlib(sig)) detectedformat=ZlibFormat;
			else detectedformat=NSISDeflateFormat;
		}

		return [self handleWithHandle:sub length:length format:detectedformat];
	}
	else return sub;
}

-(CSHandle *)handleWithHandle:(CSHandle *)fh length:(off_t)length format:(int)format
{
	switch(format)
	{
		case ZlibFormat:
		{
			CSZlibHandle *handle=[CSZlibHandle zlibHandleWithHandle:fh length:length];
			[handle setEndStreamAtInputEOF:YES];
			return handle;
		}
		break;

		case NSISDeflateFormat:
			return [[[XADDeflateHandle alloc] initWithHandle:fh length:length variant:XADNSISDeflateVariant] autorelease];

		case NSIS1Bzip2Format:
			return [[[XADNSISBzip2Handle alloc] initWithHandle:fh length:length hasRandomizationBit:YES] autorelease];

		case NSIS2Bzip2Format:
			return [[[XADNSISBzip2Handle alloc] initWithHandle:fh length:length hasRandomizationBit:NO] autorelease];

		case LZMAFormat:
		{
			NSData *propdata=[fh readDataOfLength:5];
			return [[[XADLZMAHandle alloc] initWithHandle:fh propertyData:propdata] autorelease];
		}

		case FilteredLZMAFormat:
		{
			uint8_t filter=[fh readUInt8];
			NSData *propdata=[fh readDataOfLength:5];
			CSHandle *handle=[[[XADLZMAHandle alloc] initWithHandle:fh propertyData:propdata] autorelease];

			switch(filter)
			{
				case 0: return handle;
				case 1: return [[[XAD7ZipBCJHandle alloc] initWithHandle:handle length:length] autorelease];
				default: [XADException raiseNotSupportedException]; return nil;
			}
		}
	}
	return nil;
}

-(void)attemptSolidHandleAtPosition:(off_t)pos format:(int)format headerLength:(uint32_t)headerlength;
{
	CSHandle *fh=[self handle];
	[fh seekToFileOffset:pos];
	@try
	{
		CSHandle *handle=[self handleWithHandle:fh length:CSHandleMaxLength format:format];
		uint32_t blocklen=[handle readUInt32LE];
		if(blocklen==headerlength)
		{
			solidhandle=[handle retain];
			detectedformat=format;
		}
	}
	@catch(id e) {}
}

-(XADString *)compressionName
{
	NSString *name=@"Unknown";
	switch(detectedformat)
	{
		case ZlibFormat: name=@"Deflate"; break;
		case NSISDeflateFormat: name=@"NSIS Deflate"; break;
		case NSIS1Bzip2Format: name=@"NSIS 1.9 Bzip2"; break;
		case NSIS2Bzip2Format: name=@"NSIS Bzip2"; break;
		case LZMAFormat: name=@"LZMA"; break;
		case FilteredLZMAFormat: name=@"BCJ+LZMA"; break;
	}
	return [self XADStringWithString:name];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self handleForBlockAtOffset:[[dict objectForKey:@"NSISDataOffset"] unsignedIntValue]];
}

-(NSString *)formatName { return @"NSIS"; }

@end


static int IndexOfLargestEntry(const int *entries,int num)
{
	int max=INT_MIN,index=0;
	for(int i=0;i<num;i++)
	{
		if(entries[i]>max)
		{
			max=entries[i];
			index=i;
		}
	}
	return index;
}
