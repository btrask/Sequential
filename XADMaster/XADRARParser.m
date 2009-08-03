#import "XADRARParser.h"
#import "XADRARHandle.h"
#import "XADRARAESHandle.h"
#import "XADRARCrypt20Handle.h"
#import "XADCRCHandle.h"
#import "CSMemoryHandle.h"
#import "CSMultiHandle.h"
#import "XADException.h"
#import "NSDateXAD.h"

#define RARFLAG_SKIP_IF_UNKNOWN 0x4000
#define RARFLAG_LONG_BLOCK    0x8000

#define MHD_VOLUME         0x0001
#define MHD_COMMENT        0x0002
#define MHD_LOCK           0x0004
#define MHD_SOLID          0x0008
#define MHD_PACK_COMMENT   0x0010
#define MHD_NEWNUMBERING   0x0010
#define MHD_AV             0x0020
#define MHD_PROTECT        0x0040
#define MHD_PASSWORD       0x0080
#define MHD_FIRSTVOLUME    0x0100
#define MHD_ENCRYPTVER     0x0200

#define LHD_SPLIT_BEFORE   0x0001
#define LHD_SPLIT_AFTER    0x0002
#define LHD_PASSWORD       0x0004
#define LHD_COMMENT        0x0008
#define LHD_SOLID          0x0010

#define LHD_WINDOWMASK     0x00e0
#define LHD_WINDOW64       0x0000
#define LHD_WINDOW128      0x0020
#define LHD_WINDOW256      0x0040
#define LHD_WINDOW512      0x0060
#define LHD_WINDOW1024     0x0080
#define LHD_WINDOW2048     0x00a0
#define LHD_WINDOW4096     0x00c0
#define LHD_DIRECTORY      0x00e0

#define LHD_LARGE          0x0100
#define LHD_UNICODE        0x0200
#define LHD_SALT           0x0400
#define LHD_VERSION        0x0800
#define LHD_EXTTIME        0x1000
#define LHD_EXTFLAGS       0x2000

#define RARMETHOD_STORE 0x30
#define RARMETHOD_FASTEST 0x31
#define RARMETHOD_FAST 0x32
#define RARMETHOD_NORMAL 0x33
#define RARMETHOD_GOOD 0x34
#define RARMETHOD_BEST 0x35

#define RAR_NOSIGNATURE 0
#define RAR_OLDSIGNATURE 1
#define RAR_SIGNATURE 2

static RARBlock ZeroBlock={0};

static inline BOOL IsZeroBlock(RARBlock block) { return block.start==0; }

static int TestSignature(const uint8_t *ptr)
{
	if(ptr[0]==0x52)
	if(ptr[1]==0x45&&ptr[2]==0x7e&&ptr[3]==0x5e) return RAR_OLDSIGNATURE;
	else if(ptr[1]==0x61&&ptr[2]==0x72&&ptr[3]==0x21&&ptr[4]==0x1a&&ptr[5]==0x07&&ptr[6]==0x00) return RAR_SIGNATURE;

	return RAR_NOSIGNATURE;
}

@implementation XADRARParser

+(int)requiredHeaderSize
{
	return 7;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<7) return NO; // TODO: fix to use correct min size

	if(TestSignature(bytes)) return YES;

	return NO;
}

+(XADRegex *)volumeRegexForFilename:(NSString *)filename
{
	NSArray *matches;

	if(matches=[filename substringsCapturedByPattern:@"^(.*)\\.part[0-9]+\\.rar$" options:REG_ICASE])
	return [XADRegex regexWithPattern:[NSString stringWithFormat:
	@"^%@\\.part[0-9]+\\.rar$",[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE];

	if(matches=[filename substringsCapturedByPattern:@"^(.*)\\.(rar|r[0-9]{2}|s[0-9]{2})$" options:REG_ICASE])
	return [XADRegex regexWithPattern:[NSString stringWithFormat:
	@"^%@\\.(rar|r[0-9]{2}|s[0-9]{2})$",[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE];

	return nil;
}

+(BOOL)isFirstVolume:(NSString *)filename
{
	return [filename rangeOfString:@".rar" options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound;
}



-(void)parse
{
	CSHandle *handle=[self handle];

	uint8_t buf[7];
	[handle readBytes:7 toBuffer:buf];	

	if(TestSignature(buf)==RAR_OLDSIGNATURE)
	{
		[XADException raiseNotSupportedException];
		// [fh skipBytes:-3];
		// TODO: handle old RARs.
	}

	archiveflags=0;
	lastcompressed=nil;

	RARBlock block;
	for(;;)
	{
		block=[self readBlockHeaderLevel2];
		if(IsZeroBlock(block)) [XADException raiseIllegalDataException];
		if(block.type==0x74) break;
		[self skipBlock:block];
	}

	while(!IsZeroBlock(block)&&[self shouldKeepParsing])
	{
		//NSAutoreleasePool *pool=[NSAutoreleasePool new];
		block=[self readFileHeaderWithBlock:block];
		//[pool release];
	}
}

-(RARBlock)readFileHeaderWithBlock:(RARBlock)block
{
	if(block.flags&LHD_SPLIT_BEFORE) return [self findNextFileHeaderAfterBlock:block];

	CSHandle *fh=block.fh;
	XADSkipHandle *skip=[self skipHandle];

	int flags=block.flags;
	off_t skipstart=[skip skipOffsetForActualOffset:block.datastart];

	off_t size=[fh readUInt32LE];
	int os=[fh readUInt8];
	uint32_t crc=[fh readUInt32LE];
	uint32_t dostime=[fh readUInt32LE];
	int version=[fh readUInt8];
	int method=[fh readUInt8];
	int namelength=[fh readUInt16LE];
	uint32_t attrs=[fh readUInt32LE];

	if(block.flags&LHD_LARGE)
	{
		block.datasize+=(off_t)[fh readUInt32LE]<<32;
		size+=(off_t)[fh readUInt32LE]<<32;
	}

	NSData *namedata=[fh readDataOfLength:namelength];

	NSData *salt=nil;
	if(block.flags&LHD_SALT) salt=[fh readDataOfLength:8];

	off_t datasize=block.datasize;

	off_t lastpos=block.datastart+block.datasize;
	BOOL last=(block.flags&LHD_SPLIT_AFTER)?NO:YES;
	BOOL partial=NO;

	for(;;)
	{
		[self skipBlock:block];

		block=[self readBlockHeaderLevel2];
		if(IsZeroBlock(block)) break;

		fh=block.fh;

		if(block.type==0x74) // file header
		{
			if(last) break;
			else if(!(block.flags&LHD_SPLIT_BEFORE)) { partial=YES; break; }

			[fh skipBytes:5];
			crc=[fh readUInt32LE];
			[fh skipBytes:6];
			int namelength=[fh readUInt16LE];
			[fh skipBytes:4];

			if(block.flags&LHD_LARGE)
			{
				block.datasize+=(off_t)[fh readUInt32LE]<<32;
				[fh skipBytes:4];
			}

			NSData *currnamedata=[fh readDataOfLength:namelength];

			if(![namedata isEqual:currnamedata])
			{ // Name doesn't match, skip back to header and give up.
				[fh seekToFileOffset:block.start];
				block=[self readBlockHeaderLevel2];
				partial=YES;
				break;
			}

			datasize+=block.datasize;

			[skip addSkipFrom:lastpos to:block.datastart];
			lastpos=block.datastart+block.datasize;

			if(!(block.flags&LHD_SPLIT_AFTER)) last=YES;
		}
		else if(block.type==0x7a) // newsub header
		{
			// TODO: parse new comments
			NSLog(@"newsub");
		}
	}

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self parseNameData:namedata flags:flags],XADFileNameKey,
		[NSNumber numberWithLongLong:size],XADFileSizeKey,
		[NSNumber numberWithLongLong:datasize],XADCompressedSizeKey,
		[NSDate XADDateWithMSDOSDateTime:dostime],XADLastModificationDateKey,

		[NSNumber numberWithInt:flags],@"RARFlags",
		[NSNumber numberWithInt:version],@"RARCompressionVersion",
		[NSNumber numberWithInt:method],@"RARCompressionMethod",
		[NSNumber numberWithUnsignedInt:crc],@"RARCRC32",
		[NSNumber numberWithInt:os],@"RAROS",
		[NSNumber numberWithUnsignedInt:attrs],@"RARAttributes",
	nil];

	if(salt) [dict setObject:salt forKey:@"RARSalt"];

	if(partial) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsCorruptedKey];

	if(flags&LHD_PASSWORD) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];
	if((flags&LHD_WINDOWMASK)==LHD_DIRECTORY) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	NSString *osname=nil;
	switch(os)
	{
		case 0: osname=@"MS-DOS"; break;
		case 1: osname=@"OS/2"; break;
		case 2: osname=@"Win32"; break;
		case 3: osname=@"Unix"; break;
	}
	if(osname) [dict setObject:[self XADStringWithString:osname] forKey:@"RAROSName"];

	switch(os)
	{
		case 0: [dict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADDOSFileAttributesKey]; break;
		case 2: [dict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADWindowsFileAttributesKey]; break;
		case 3: [dict setObject:[NSNumber numberWithUnsignedInt:attrs] forKey:XADPosixPermissionsKey]; break;
	}

	NSString *methodname=nil;
	switch(method)
	{
		case 0x30: methodname=@"None"; break;
		case 0x31: methodname=[NSString stringWithFormat:@"Fastest v%d.%d",version/10,version%10]; break;
		case 0x32: methodname=[NSString stringWithFormat:@"Fast v%d.%d",version/10,version%10]; break;
		case 0x33: methodname=[NSString stringWithFormat:@"Normal v%d.%d",version/10,version%10]; break;
		case 0x34: methodname=[NSString stringWithFormat:@"Good v%d.%d",version/10,version%10]; break;
		case 0x35: methodname=[NSString stringWithFormat:@"Best v%d.%d",version/10,version%10]; break;
	}
	if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

	if(method==0x30)
	{
		[dict setObject:[NSNumber numberWithLongLong:skipstart] forKey:XADSkipOffsetKey];
		[dict setObject:[NSNumber numberWithLongLong:datasize] forKey:XADSkipLengthKey];
	}
	else
	{
		BOOL solid;
		if(version<20) solid=(archiveflags&MHD_SOLID)&&lastcompressed;
		else solid=(flags&LHD_SOLID)!=0;

		if(solid&&!lastcompressed)
		{
			[self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];
			return block;
		}

		NSDictionary *solidobj;

		if(solid)
		{
			solidobj=[lastcompressed objectForKey:XADSolidObjectKey];
			NSNumber *lastoffs=[lastcompressed objectForKey:XADSolidOffsetKey];
			NSNumber *lastlen=[lastcompressed objectForKey:XADSolidLengthKey];
			off_t newoffs=[lastoffs longLongValue]+[lastlen longLongValue];
			[dict setObject:[NSNumber numberWithLongLong:newoffs] forKey:XADSolidOffsetKey];
		}
		else
		{
			solidobj=[NSDictionary dictionaryWithObjectsAndKeys:
				[NSMutableArray array],@"Parts",
				[NSNumber numberWithInt:version],@"Version",
			nil];
			[dict setObject:[NSNumber numberWithLongLong:0] forKey:XADSolidOffsetKey];
		}
 
		[[solidobj objectForKey:@"Parts"] addObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithLongLong:skipstart],@"SkipOffset",
			[NSNumber numberWithLongLong:datasize],@"InputLength",
			[NSNumber numberWithLongLong:size],@"OutputLength",
			[NSNumber numberWithBool:(flags&LHD_PASSWORD)?YES:NO],@"Encrypted",
			salt,@"Salt", // ends the list if nil
		nil]];
		[dict setObject:solidobj forKey:XADSolidObjectKey];
		[dict setObject:[NSNumber numberWithLongLong:size] forKey:XADSolidLengthKey];

		lastcompressed=dict;
	}

	[self addEntryWithDictionary:dict retainPosition:YES];

	return block;
}

-(RARBlock)findNextFileHeaderAfterBlock:(RARBlock)block
{
	for(;;)
	{
		[self skipBlock:block];
		block=[self readBlockHeaderLevel2];
		if(IsZeroBlock(block)) return ZeroBlock;

		if(block.type==0x74) return block;
	}
}



-(RARBlock)readBlockHeaderLevel2
{
	for(;;)
	{
		RARBlock block=[self readBlockHeaderLevel1];

		if(block.type==0x72) // file marker header
		{
		}
		else if(block.type==0x73) // archive header
		{
			CSHandle *fh=block.fh;

			archiveflags=block.flags;

			[fh skipBytes:6]; // Skip signature stuff

			if(block.flags&MHD_ENCRYPTVER)
			{
				encryptversion=[fh readUInt8];
			}
			else encryptversion=0; // ?

			if(block.flags&MHD_COMMENT)
			{
				RARBlock commentblock=[self readBlockHeaderLevel1];
				[self readCommentBlock:commentblock];
			}
		}
		//else if(block.type==0x7a) // newsub header
		//{
		//}
		else if(block.type==0x7b) // end header
		{
			archiveflags=0;
		}
		else
		{
			return block;
		}

		[self skipBlock:block];
	}
}



-(RARBlock)readBlockHeaderLevel1
{
	CSHandle *fh=[self handle];

	RARBlock block;
	block.start=[[self handle] offsetInFile];

	if(archiveflags&MHD_PASSWORD)
	{
		NSData *salt=[fh readDataOfLength:8];
		fh=[[[XADRARAESHandle alloc] initWithHandle:fh
		password:[self password] salt:salt brokenHash:encryptversion<36] autorelease];
	}

	block.fh=fh;

	@try
	{
		block.crc=[fh readUInt16LE];
		block.type=[fh readUInt8];
		block.flags=[fh readUInt16LE];
		block.headersize=[fh readUInt16LE];
	}
	@catch(id e) { return ZeroBlock; }

	if(block.crc!=0x6152||block.type!=0x72||block.flags!=0x1a21||block.headersize!=7)
	{
		off_t pos=[fh offsetInFile];
		uint32_t crc=0xffffffff;
		@try
		{
			crc=XADCRC(crc,block.type,XADCRCTable_edb88320);
			crc=XADCRC(crc,(block.flags&0xff),XADCRCTable_edb88320);
			crc=XADCRC(crc,((block.flags>>8)&0xff),XADCRCTable_edb88320);
			crc=XADCRC(crc,(block.headersize&0xff),XADCRCTable_edb88320);
			crc=XADCRC(crc,((block.headersize>>8)&0xff),XADCRCTable_edb88320);
			for(int i=7;i<block.headersize;i++) crc=XADCRC(crc,[fh readUInt8],XADCRCTable_edb88320);
		}
		@catch(id e) {}

		if((~crc&0xffff)!=block.crc)
		{
			if(archiveflags&MHD_PASSWORD) [XADException raisePasswordException];
			else [XADException raiseIllegalDataException];
		}

		[fh seekToFileOffset:pos];
	}

	if(block.flags&RARFLAG_LONG_BLOCK) block.datasize=[fh readUInt32LE];
	else block.datasize=0;

	if(archiveflags&MHD_PASSWORD) block.datastart=block.start+((block.headersize+15)&~15)+8;
	else block.datastart=block.start+block.headersize;

	//NSLog(@"block:%x flags:%x headsize:%d datasize:%qu ",block.type,block.flags,block.headersize,block.datasize);

	return block;
}

-(void)skipBlock:(RARBlock)block
{
	[[self handle] seekToFileOffset:block.datastart+block.datasize];
}

-(CSHandle *)dataHandleFromSkipOffset:(off_t)offs length:(off_t)length
encrypted:(BOOL)encrypted cryptoVersion:(int)version salt:(NSData *)salt
{
	CSHandle *fh=[[self skipHandle] nonCopiedSubHandleFrom:offs length:length];

	if(encrypted)
	{
		if(version<20)
		{
			[XADException raiseNotSupportedException];
			return nil;
		}
		else if(version==20)
		{
			return [[[XADRARCrypt20Handle alloc] initWithHandle:fh
			password:[self encodedPassword]] autorelease];
		}
		else
		{
			return [[[XADRARAESHandle alloc] initWithHandle:fh
			password:[self password] salt:salt brokenHash:encryptversion<36] autorelease];
		}
	}
	else return fh;
}



-(void)readCommentBlock:(RARBlock)block
{
	CSHandle *fh=block.fh;

	int commentsize=[fh readUInt16LE];
	int version=[fh readUInt8];
	/*int method=*/[fh readUInt8];
	/*int crc=*/[fh readUInt16LE];

	XADRARHandle *handle=[[[XADRARHandle alloc] initWithRARParser:self version:version
	skipOffset:[[self skipHandle] offsetInFile] inputLength:block.headersize-13
	outputLength:commentsize encrypted:NO salt:nil] autorelease];

	NSData *comment=[handle readDataOfLength:commentsize];
	[self setObject:[self XADStringWithData:comment] forPropertyKey:XADCommentKey];
}

-(XADPath *)parseNameData:(NSData *)data flags:(int)flags
{
	if(flags&LHD_UNICODE)
	{
		int length=[data length];
		const uint8_t *bytes=[data bytes];

		int n=0;
		while(n<length&&bytes[n]) n++;

		if(n==length) return [self XADPathWithData:data encoding:NSUTF8StringEncoding separators:XADWindowsPathSeparator];

		int num=length-n-1;
		if(num<=1) return [self XADPathWithCString:(const char *)bytes separators:XADWindowsPathSeparator];

		CSMemoryHandle *fh=[CSMemoryHandle memoryHandleForReadingBuffer:bytes+n+1 length:num];
		NSMutableString *str=[NSMutableString string];

		@try
		{
			int highbyte=[fh readUInt8]<<8;
			int flagbyte,flagbits=0;

			while(![fh atEndOfFile])
			{
				if(flagbits==0)
				{
					flagbyte=[fh readUInt8];
					flagbits=8;
				}

				flagbits-=2;
				switch((flagbyte>>flagbits)&3)
				{
					case 0: [str appendFormat:@"%C",[fh readUInt8]]; break;
					case 1: [str appendFormat:@"%C",highbyte+[fh readUInt8]]; break;
					case 2: [str appendFormat:@"%C",[fh readUInt16LE]]; break;
					case 3:
					{
						int len=[fh readUInt8];
						if(len&0x80)
						{
							int correction=[fh readUInt8];
							for(int i=0;i<(len&0x7f)+2;i++)
							[str appendFormat:@"%C",highbyte+(bytes[[str length]]+correction&0xff)];
						}
						else for(int i=0;i<(len&0x7f)+2;i++)
						[str appendFormat:@"%C",bytes[[str length]]];
					}
					break;
				}
			}
		}
		@catch(id e) {}

		// TODO: avoid re-encoding
		return [self XADPathWithData:[str dataUsingEncoding:NSUTF8StringEncoding]
		encoding:NSUTF8StringEncoding separators:XADWindowsPathSeparator];
	}
	else return [self XADPathWithData:data separators:XADWindowsPathSeparator];
}





-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle;
	if([[dict objectForKey:@"RARCompressionMethod"] intValue]==0x30)
	{
		handle=[self dataHandleFromSkipOffset:[[dict objectForKey:XADSkipOffsetKey] longLongValue]
		length:[[dict objectForKey:XADSkipLengthKey] longLongValue]
		encrypted:[[dict objectForKey:XADIsEncryptedKey] boolValue]
		cryptoVersion:[[dict objectForKey:@"RARCompressionVersion"] intValue]
		salt:[dict objectForKey:@"RARSalt"]];
	}
	else
	{
		handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];
	}

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:[handle fileSize]
	correctCRC:[[dict objectForKey:@"RARCRC32"] unsignedIntValue] conditioned:YES];

	return handle;
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum;
{
	NSArray *parts=[obj objectForKey:@"Parts"];
	int version=[[obj objectForKey:@"Version"] intValue];
	return [[[XADRARHandle alloc] initWithRARParser:self version:version parts:parts] autorelease];
}

-(NSString *)formatName
{
	return @"RAR";
}

@end


@implementation XADEmbeddedRARParser

+(int)requiredHeaderSize
{
	return 0x40000;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<7) return NO; // TODO: fix to use correct min size

	for(int i=0;i<=length-7;i++) if(TestSignature(bytes+i)) return YES;

	return NO;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	uint8_t buf[7];
	[fh readBytes:sizeof(buf) toBuffer:buf];	

	int sigtype;
	while(!(sigtype=TestSignature(buf)))
	{
		memmove(buf,buf+1,sizeof(buf)-1);
		buf[sizeof(buf)-1]=[fh readUInt8];
	}

	[fh skipBytes:-sizeof(buf)];
	[super parse];
}

-(NSString *)formatName
{
	return @"Embedded RAR";
}

@end
