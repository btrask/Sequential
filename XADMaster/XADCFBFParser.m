#import "XADCFBFParser.h"
#import "XADBlockHandle.h"
#import "NSDateXAD.h"

@implementation XADCFBFParser

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if((self=[super initWithHandle:handle name:name]))
	{
		sectable=NULL;
	}
	return self;
}

-(void)dealloc
{
	free(sectable);
	[super dealloc];
}

+(int)requiredHeaderSize { return 512; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=512&&bytes[0]==0xd0&&bytes[1]==0xcf&&bytes[2]==0x11&&bytes[3]==0xe0&&
	bytes[4]==0xa1&&bytes[5]==0xb1&&bytes[6]==0x1a&&bytes[7]==0xe1&&bytes[28]==0xfe&&bytes[29]==0xff;
}

-(void)parse
{
	CSHandle *fh=[self handle];


	// Read header

	[fh skipBytes:30];
	int secshift=[fh readUInt16LE];
	int minisecshift=[fh readUInt16LE];
	[fh skipBytes:10];
	uint32_t numtablesecs=[fh readUInt32LE];
	uint32_t firstdirsec=[fh readUInt32LE];
	[fh skipBytes:4];
	minsize=[fh readUInt32LE];
	uint32_t firstminitablesec=[fh readUInt32LE];
	uint32_t numminitablesecs=[fh readUInt32LE];
	uint32_t firstmastersec=[fh readUInt32LE];
	/*uint32_t nummastersecs=*/[fh readUInt32LE];

	secsize=1<<secshift;
	minisecsize=1<<minisecshift;



	// Read allocation table through the master allocation table

	int idspersec=secsize/4;

	numsectors=numtablesecs*idspersec;
	sectable=malloc(numsectors*sizeof(uint32_t));

	for(int i=0;i<numtablesecs;i++)
	{
		if(i==109)
		{
			[self seekToSector:firstmastersec];
		}
		else if(i>109 && (i-109)%(idspersec-1)==0)
		{
			uint32_t nextsec=[fh readUInt32LE];
			[self seekToSector:nextsec];
		}

		int sector=[fh readUInt32LE];
		off_t currpos=[fh offsetInFile];

		[self seekToSector:sector];
		for(int j=0;j<idspersec;j++) sectable[i*idspersec+j]=[fh readUInt32LE];
		[fh seekToFileOffset:currpos];
	}



	// Read short-sector allocation table

	numminisectors=numminitablesecs*idspersec;
	minisectable=malloc(numminisectors*sizeof(uint32_t));

	uint32_t minitablesec=firstminitablesec;
	for(int i=0;i<numminitablesecs;i++)
	{
		[self seekToSector:minitablesec];
		for(int j=0;j<idspersec;j++) minisectable[i*idspersec+j]=[fh readUInt32LE];
		minitablesec=[self nextSectorAfter:minitablesec];
	}



	// Read directory entries

	NSMutableArray *entries=[NSMutableArray array];

	BOOL firstentry=YES;
	uint32_t dirsec=firstdirsec;
	while(dirsec!=0xfffffffe)
	{
		[self seekToSector:dirsec];
		for(int i=0;i<secsize;i+=128)
		{
			uint8_t name[64];
			[fh readBytes:64 toBuffer:name];
			int numnamebytes=[fh readUInt16LE];
			int type=[fh readUInt8];
			int black=[fh readUInt8];
			uint32_t leftchild=[fh readUInt32LE];
			uint32_t rightchild=[fh readUInt32LE];
			uint32_t rootnode=[fh readUInt32LE];
			[fh skipBytes:16];
			uint32_t flags=[fh readUInt32LE];
			uint64_t created=[fh readUInt64LE];
			uint64_t modified=[fh readUInt64LE];
			uint32_t firstsec=[fh readUInt32LE];

			off_t size;
			if(secshift>=12)
			{
				size=[fh readUInt64LE];
			}
			else
			{
				size=[fh readUInt32LE];
				[fh skipBytes:4];
			}

			if(firstentry != (type==5)) [XADException raiseIllegalDataException];
			firstentry=NO;

			if(type==0) // empty entry
			{
				[entries addObject:[NSNull null]];
			}
			else if(type==5) // root entry
			{
				rootdirectorynode=rootnode;
				firstminisector=firstsec;

				[entries addObject:[NSNull null]];
			}
			else
			{
				NSMutableDictionary *entry=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					[self decodeFileNameWithBytes:name length:numnamebytes],@"CFBFFileName",
					[NSNumber numberWithInt:type],@"CFBFType",
					[NSNumber numberWithInt:black],@"CFBFRedOrBlack",
					[NSNumber numberWithUnsignedInt:leftchild],@"CFBFLeftChild",
					[NSNumber numberWithUnsignedInt:rightchild],@"CFBFRightChild",
					[NSNumber numberWithUnsignedInt:flags],@"CFBFFlags",
				nil];

				if(type==1)
				{
					[entry setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
					[entry setObject:[NSNumber numberWithUnsignedInt:rootnode] forKey:@"CFBFRootNode"];
				}
				else if(type==2)
				{
					[entry setObject:[NSNumber numberWithLongLong:size] forKey:XADFileSizeKey];
					[entry setObject:[NSNumber numberWithLongLong:size] forKey:XADCompressedSizeKey];
					[entry setObject:[NSNumber numberWithUnsignedLongLong:firstsec] forKey:@"CFBFFirstSector"];
				}

				if(created) [entry setObject:[NSDate XADDateWithWindowsFileTime:created] forKey:XADCreationDateKey];
				if(modified) [entry setObject:[NSDate XADDateWithWindowsFileTime:modified] forKey:XADLastModificationDateKey];

				[entries addObject:entry];
			}
		}
		dirsec=[self nextSectorAfter:dirsec];
	}



	// Resolve directory structure

	[self processEntry:rootdirectorynode atPath:[self XADPath] entries:entries];
}

-(XADString *)decodeFileNameWithBytes:(uint8_t *)bytes length:(int)length
{
	static const int LowChar=0x3800;
	static const int HighChar=0x3800+64*65;
	static const char Chars[64]="0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz._";

	for(int i=0;i<length-2;i+=2)
	{
		uint16_t c=CSUInt16LE(&bytes[i]);
		if(c<LowChar||c>HighChar)
		{
			NSMutableString *filename=[NSMutableString stringWithCapacity:length/2-2];
			for(int i=0;i<length-2;i+=2) [filename appendFormat:@"%C",CSUInt16LE(&bytes[i])];
			return [self XADStringWithString:filename];
		}
	}

	NSMutableString *filename=[NSMutableString stringWithCapacity:length];

	for(int i=0;i<length-2;i+=2)
	{
		uint16_t code=CSUInt16LE(&bytes[i])-LowChar;

		if(code==HighChar) [filename appendString:@"!"];
		else
		{
			int c1=code&0x3f;
			int c2=code>>6;

			[filename appendFormat:@"%c",Chars[c1]];
			if(c2<64) [filename appendFormat:@"%c",Chars[c2]];
		}
	}

	return [self XADStringWithString:filename];
}

-(void)processEntry:(uint32_t)n atPath:(XADPath *)path entries:(NSArray *)entries
{
	NSMutableDictionary *entry=[entries objectAtIndex:n];

	uint32_t left=[[entry objectForKey:@"CFBFLeftChild"] unsignedIntValue];
	if(left!=0xffffffff) [self processEntry:left atPath:path entries:entries];

	XADPath *filename=[path pathByAppendingXADStringComponent:[entry objectForKey:@"CFBFFileName"]];
	[entry setObject:filename forKey:XADFileNameKey];
	[self addEntryWithDictionary:entry];

	int type=[[entry objectForKey:@"CFBFType"] intValue];
	if(type==1)
	{
		uint32_t root=[[entry objectForKey:@"CFBFRootNode"] unsignedIntValue];
		if(root!=0xffffffff) [self processEntry:root atPath:filename entries:entries];
	}

	uint32_t right=[[entry objectForKey:@"CFBFRightChild"] unsignedIntValue];
	if(right!=0xffffffff) [self processEntry:right atPath:path entries:entries];
}

-(void)seekToSector:(uint32_t)sector
{
	if(sector>=numsectors) [XADException raiseIllegalDataException];
	[[self handle] seekToFileOffset:512+sector*secsize];
}

-(uint32_t)nextSectorAfter:(uint32_t)sector
{
	if(sector>=numsectors) [XADException raiseIllegalDataException];
	return sectable[sector];
}



-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];
	uint32_t first=[[dict objectForKey:@"CFBFFirstSector"] unsignedIntValue];

	if(size>=minsize)
	{
		XADBlockHandle *bh=[[[XADBlockHandle alloc] initWithHandle:handle length:size blockSize:secsize] autorelease];
		[bh setBlockChain:sectable numberOfBlocks:numsectors firstBlock:first headerSize:512];

		return bh;
	}
	else
	{
		XADBlockHandle *bh=[[[XADBlockHandle alloc] initWithHandle:handle blockSize:secsize] autorelease];
		[bh setBlockChain:sectable numberOfBlocks:numsectors firstBlock:firstminisector headerSize:512];

		XADBlockHandle *mbh=[[[XADBlockHandle alloc] initWithHandle:bh length:size blockSize:minisecsize] autorelease];
		[mbh setBlockChain:minisectable numberOfBlocks:numminisectors firstBlock:first headerSize:0];

		return mbh;
	}
}

-(NSString *)formatName
{
	return @"CFBF";
}

@end
