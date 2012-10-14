#import "XADRARParser.h"
#import "XADRARInputHandle.h"
#import "XADRAR15Handle.h"
#import "XADRAR20Handle.h"
#import "XADRAR30Handle.h"
#import "XADRAR13CryptHandle.h"
#import "XADRAR15CryptHandle.h"
#import "XADRAR20CryptHandle.h"
#import "XADRARAESHandle.h"
#import "XADCRCHandle.h"
#import "CSFileHandle.h"
#import "CSMemoryHandle.h"
#import "CSMultiHandle.h"
#import "XADException.h"
#import "NSDateXAD.h"
#import "Scanning.h"

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



static RARBlock ZeroBlock={0};

static inline BOOL IsZeroBlock(RARBlock block) { return block.start==0; }

static BOOL IsRARSignature(const uint8_t *ptr)
{
	return ptr[0]==0x52 && ptr[1]==0x61 && ptr[2]==0x72 && ptr[3]==0x21 &&
	ptr[4]==0x1a && ptr[5]==0x07 && ptr[6]==0x00;
}

static BOOL IsAncientRARSignature(const uint8_t *ptr)
{
	return ptr[0]==0x52 && ptr[1]==0x45 && ptr[2]==0x7e && ptr[3]==0x5e;
}

static const uint8_t *FindSignature(const uint8_t *ptr,int length)
{
	if(length<7) return NULL;

	for(int i=0;i<=length-7;i++) if(IsRARSignature(&ptr[i])) return &ptr[i];

	return NULL;
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

	if(IsRARSignature(bytes)) return YES;
	if(IsAncientRARSignature(bytes)) return YES;

	return NO;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	if([data length]<12) return nil;
	const uint8_t *header=[data bytes];
	uint16_t flags=CSUInt16LE(&header[10]);

	// Don't bother looking for volumes if it the volume bit is not set.
	if(!(flags&1)) return nil;

	// Check the old/new naming bit.
	if(flags&0x10)
	{
		// New naming scheme. Find the last number in the name, and look for other files
		// with the same number of digits in the same location.
		NSArray *matches;
		if((matches=[name substringsCapturedByPattern:@"^(.*[^0-9])([0-9]+)(.*)\\.rar$" options:REG_ICASE]))
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@[0-9]{%ld}%@.rar$",
			[[matches objectAtIndex:1] escapedPattern],
			(long)[(NSString *)[matches objectAtIndex:2] length],
			[[matches objectAtIndex:3] escapedPattern]] options:REG_ICASE]
		firstFileExtension:@"rar"];
	}

	// Old naming scheme. Just look for rar/r01/s01 files.
	NSArray *matches;
	if((matches=[name substringsCapturedByPattern:@"^(.*)\\.(rar|r[0-9]{2}|s[0-9]{2})$" options:REG_ICASE]))
	{
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.(rar|r[0-9]{2}|s[0-9]{2})$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:@"rar"];
	}

	return nil;
}



-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if((self=[super initWithHandle:handle name:name]))
	{
		keys=nil;
	}
	return self;
}

-(void)dealloc
{
	[keys release];
	[super dealloc];
}

-(void)setPassword:(NSString *)newpassword
{
	// Make sure to clear key cache if password changes.
	[keys release];
	keys=nil;
	[super setPassword:newpassword];
}

-(void)parse
{
	CSHandle *handle=[self handle];

	uint8_t buf[7];
	[handle readBytes:7 toBuffer:buf];	

	if(IsAncientRARSignature(buf))
	{
		[self reportInterestingFileWithReason:@"Very old RAR file"];
		[XADException raiseNotSupportedException];
		// [fh skipBytes:-3];
		// TODO: handle old RARs.
	}

	archiveflags=0;

	NSMutableArray *currfiles=nil;
	NSMutableArray *currparts=nil;
	RARBlock previousblock;
	RARFileHeader previousheader;

	BOOL firstfileheader=YES;

	off_t totalfilesize=0;
	off_t totalsolidsize=0;

	RARBlock block;
	while([self shouldKeepParsing])
	{
		block=[self readBlockHeader];
		if(IsZeroBlock(block))
		{
			// We hit the end of the file. If we have parts that have no been
			// emitted yet, do so now, and mark as corrupted as we are missing the
			// last part.

			if(currparts)
			{
				// Add current file to solid file list, creating it if necessary.
				if(!currfiles) currfiles=[NSMutableArray array];

				[currfiles addObject:[NSDictionary dictionaryWithObjectsAndKeys:
					currparts,@"Parts",
					[NSNumber numberWithLongLong:previousheader.size],@"OutputLength",
					[NSNumber numberWithInt:previousheader.version],@"Version",
					[NSNumber numberWithBool:(block.flags&LHD_PASSWORD)?YES:NO],@"Encrypted",
					previousheader.salt,@"Salt", // Ends the list if nil.
				nil]];

				[self addEntryWithBlock:&previousblock header:&previousheader
				compressedSize:totalfilesize files:currfiles solidOffset:totalsolidsize
				isCorrupted:YES];
			}

			break;
		}

		CSHandle *fh=block.fh;

		switch(block.type)
		{
			case 0x72: // File marker header (magic number).
				[self skipBlock:block];
			break;

			case 0x73: // Archive header.
				archiveflags=block.flags;

				[fh skipBytes:6]; // Skip signature stuff.

				if(block.flags&MHD_ENCRYPTVER)
				{
					encryptversion=[fh readUInt8];
				}
				else encryptversion=0; // ?

				if(block.flags&MHD_COMMENT) // 2.0-style comment.
				{
					NSData *comment=[self readComment];
					[self setObject:[self XADStringWithData:comment] forPropertyKey:XADCommentKey];
				}

				[self skipBlock:block];
			break;

			case 0x74: // File header.
			{
				RARFileHeader header=[self readFileHeaderWithBlock:&block];

				BOOL first=(block.flags&LHD_SPLIT_BEFORE)?NO:YES;
				BOOL last=(block.flags&LHD_SPLIT_AFTER)?NO:YES;
				BOOL mismatch=NO;

				if(currparts)
				{
					// We are currently collecting more parts for a file. If the new
					// part is marked as the first part, or if the name doesn't match
					// the last part, something is wrong.
					if(first || ![header.namedata isEqual:previousheader.namedata])
					{
						// Emit as much as we have of the previous file.
						[self addEntryWithBlock:&previousblock header:&previousheader
						compressedSize:totalfilesize files:currfiles solidOffset:totalsolidsize
						isCorrupted:YES];

						// Start new part and solid file lists.
						currparts=nil;
						currfiles=nil;
						mismatch=YES;
					}
				}
				else
				{
					// We are starting a new file.
					// Make sure we are getting the start part of the file.
					if(!first)
					{
						// If this is not the start of a new file, something is wrong.
						// Start new solid file list.
						currfiles=nil;
						mismatch=YES;
					}
				}

				// Add current part to part list, creating it if necessary.
				if(!currparts)
				{
					currparts=[NSMutableArray array];
					totalfilesize=0;
				}

				[currparts addObject:[NSDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithLongLong:block.datastart],@"Offset",
					[NSNumber numberWithLongLong:block.datasize],@"InputLength",
					[NSNumber numberWithUnsignedInt:header.crc],@"CRC32",
				nil]];

				totalfilesize+=block.datasize;

				if(last)
				{
					// Figure out if this file is solid.
					BOOL solid;
					if(header.version<20) solid=(archiveflags&MHD_SOLID)&&!firstfileheader; // TODO: Should this be < or <=?
					else solid=(block.flags&LHD_SOLID)!=0;

					// If it is not solid, restart the solid file list.
					if(!solid) currfiles=nil;

					// Add current file to solid file list, creating it if necessary.
					if(!currfiles)
					{
						currfiles=[NSMutableArray array];
						totalsolidsize=0;
					}

					[currfiles addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						currparts,@"Parts",
						[NSNumber numberWithLongLong:header.size],@"OutputLength",
						[NSNumber numberWithInt:header.version],@"Version",
						[NSNumber numberWithBool:(block.flags&LHD_PASSWORD)?YES:NO],@"Encrypted",
						header.salt,@"Salt", // Ends the list if nil.
					nil]];

					// Emit this file.
					[self addEntryWithBlock:&block header:&header
					compressedSize:totalfilesize files:currfiles solidOffset:totalsolidsize
					isCorrupted:mismatch];

					totalsolidsize+=header.size;

					// If this file was corrupted, restart the solid file list.
					if(mismatch) currfiles=nil;

					// Restart part list.
					currparts=nil;
				}
				else
				{
					previousblock=block;
					previousheader=header;
				}

				firstfileheader=NO;

				[self skipBlock:block];
			}
			break;

			case 0x7a: // Newsub header.
				[self skipBlock:block];
			break;

			case 0x7b: // End header
			{
				archiveflags=0;

				[self skipBlock:block];

				CSHandle *handle=[self handle];
				if([handle respondsToSelector:@selector(currentHandle)]) handle=[(id)handle currentHandle];
				if([handle offsetInFile]!=0) [handle seekToEndOfFile];
			}
			break;

			default:
				[self skipBlock:block];
			break;
		}
	}
}




-(RARFileHeader)readFileHeaderWithBlock:(RARBlock *)block
{
	CSHandle *fh=block->fh;

	RARFileHeader header;

	header.size=[fh readUInt32LE];
	header.os=[fh readUInt8];
	header.crc=[fh readUInt32LE];
	header.dostime=[fh readUInt32LE];
	header.version=[fh readUInt8];
	header.method=[fh readUInt8];
	header.namelength=[fh readUInt16LE];
	header.attrs=[fh readUInt32LE];

	if(block->flags&LHD_LARGE)
	{
		block->datasize+=(off_t)[fh readUInt32LE]<<32;
		header.size+=(off_t)[fh readUInt32LE]<<32;
	}

	header.namedata=[fh readDataOfLength:header.namelength];

	if(block->flags&LHD_SALT) header.salt=[fh readDataOfLength:8];
	else header.salt=nil;

	return header;
}

-(NSData *)readComment
{
	// Read 2.0-style comment block.

	RARBlock block=[self readBlockHeader];

	CSHandle *fh=block.fh;

	int commentsize=[fh readUInt16LE];
	int version=[fh readUInt8];
	/*int method=*/[fh readUInt8];
	/*int crc=*/[fh readUInt16LE];

	// TODO: should this be [self handle] or block.fh?
	NSArray *parts=[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithLongLong:[[self handle] offsetInFile]],@"Offset",
			[NSNumber numberWithLongLong:block.headersize-13],@"InputLength",
			//[NSNumber numberWithUnsignedInt:header.crc],@"CRC32",
		nil]],@"Parts",
		[NSNumber numberWithLongLong:commentsize],@"OutputLength",
		[NSNumber numberWithInt:version],@"Version",
		[NSNumber numberWithBool:NO],@"Encrypted",
	nil]];

	CSHandle *handle=[self handleForSolidStreamWithObject:parts wantChecksum:NO];

	return [handle readDataOfLength:commentsize];
}




-(RARBlock)readBlockHeader
{
	CSHandle *fh=[self handle];
	if([fh atEndOfFile]) return ZeroBlock;

	RARBlock block;
	block.start=[[self handle] offsetInFile];

	if(archiveflags&MHD_PASSWORD)
	{
		NSData *salt=[fh readDataOfLength:8];
		fh=[[[XADRARAESHandle alloc] initWithHandle:fh key:[self keyForSalt:salt]] autorelease];
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

	if(block.headersize<7) [XADException raiseIllegalDataException];

	// Removed CRC checking because RAR uses it completely inconsitently
/*	if(block.crc!=0x6152||block.type!=0x72||block.flags!=0x1a21||block.headersize!=7)
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
			for(int i=7;i<block.headersize;i++)
			{
NSLog(@"%04x %04x %s",~crc&0xffff,block.crc,(~crc&0xffff)==block.crc?"<-------":"");
				crc=XADCRC(crc,[fh readUInt8],XADCRCTable_edb88320);
			}
		}
		@catch(id e) {}

		if((~crc&0xffff)!=block.crc)
		{
			if(archiveflags&MHD_PASSWORD) [XADException raisePasswordException];
			else [XADException raiseIllegalDataException];
		}

		[fh seekToFileOffset:pos];
	}*/

	// RAR ignores the LONG_BLOCK flag for most chunks. FILE_HEAD, NEWSUB_HEAD,
	// PROTECT_HEAD, and SUB_HEAD are always treated as long, while most others
	// are always treated as short. The flag is only used for unknown blocks.
	// To work around broken archives, we add an exception for FILE_HEAD, at least.
	if((block.flags&RARFLAG_LONG_BLOCK)||block.type==0x74) block.datasize=[fh readUInt32LE];
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




-(void)addEntryWithBlock:(const RARBlock *)block header:(const RARFileHeader *)header
compressedSize:(off_t)compsize files:(NSArray *)files solidOffset:(off_t)solidoffs
isCorrupted:(BOOL)iscorrupted
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self parseNameData:header->namedata flags:block->flags],XADFileNameKey,
		[NSNumber numberWithLongLong:solidoffs],XADSolidOffsetKey,
		[NSNumber numberWithLongLong:header->size],XADSolidLengthKey,
		[NSNumber numberWithLongLong:header->size],XADFileSizeKey, // TODO: this right?
		[NSNumber numberWithLongLong:compsize],XADCompressedSizeKey,
		[NSDate XADDateWithMSDOSDateTime:header->dostime],XADLastModificationDateKey,
		files,XADSolidObjectKey,

		[NSNumber numberWithInt:block->flags],@"RARFlags",
		[NSNumber numberWithInt:header->version],@"RARCompressionVersion",
		[NSNumber numberWithInt:header->method],@"RARCompressionMethod",
		[NSNumber numberWithUnsignedInt:header->crc],@"RARCRC32",
		[NSNumber numberWithInt:header->os],@"RAROS",
		[NSNumber numberWithUnsignedInt:header->attrs],@"RARAttributes",
		[NSNumber numberWithInt:[files count]-1],@"RARSolidIndex",
	nil];

	if(iscorrupted) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsCorruptedKey];

	if(block->flags&LHD_PASSWORD) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];
	if((block->flags&LHD_WINDOWMASK)==LHD_DIRECTORY) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
	if(header->version==15 && header->os==0 && (header->attrs&0x10)) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	NSString *osname=nil;
	switch(header->os)
	{
		case 0: osname=@"MS-DOS"; break;
		case 1: osname=@"OS/2"; break;
		case 2: osname=@"Win32"; break;
		case 3: osname=@"Unix"; break;
	}
	if(osname) [dict setObject:[self XADStringWithString:osname] forKey:@"RAROSName"];

	switch(header->os)
	{
		case 0: [dict setObject:[NSNumber numberWithUnsignedInt:header->attrs] forKey:XADDOSFileAttributesKey]; break;
		case 2: [dict setObject:[NSNumber numberWithUnsignedInt:header->attrs] forKey:XADWindowsFileAttributesKey]; break;
		case 3: [dict setObject:[NSNumber numberWithUnsignedInt:header->attrs] forKey:XADPosixPermissionsKey]; break;
	}

	NSString *methodname=nil;
	switch(header->method)
	{
		case 0x30: methodname=@"None"; break;
		case 0x31: methodname=[NSString stringWithFormat:@"Fastest v%d.%d",header->version/10,header->version%10]; break;
		case 0x32: methodname=[NSString stringWithFormat:@"Fast v%d.%d",header->version/10,header->version%10]; break;
		case 0x33: methodname=[NSString stringWithFormat:@"Normal v%d.%d",header->version/10,header->version%10]; break;
		case 0x34: methodname=[NSString stringWithFormat:@"Good v%d.%d",header->version/10,header->version%10]; break;
		case 0x35: methodname=[NSString stringWithFormat:@"Best v%d.%d",header->version/10,header->version%10]; break;
	}
	if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

	[self addEntryWithDictionary:dict];
}

-(XADPath *)parseNameData:(NSData *)data flags:(int)flags
{
	if(flags&LHD_UNICODE)
	{
		int length=[data length];
		const uint8_t *bytes=[data bytes];

		int n=0;
		while(n<length&&bytes[n]) n++;

		if(n==length) return [self XADPathWithData:data encodingName:XADUTF8StringEncodingName separators:XADWindowsPathSeparator];

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
					case 0: [str appendFormat:@"%C",(unichar)[fh readUInt8]]; break;
					case 1: [str appendFormat:@"%C",(unichar)(highbyte+[fh readUInt8])]; break;
					case 2: [str appendFormat:@"%C",[fh readUInt16LE]]; break;
					case 3:
					{
						int len=[fh readUInt8];
						if(len&0x80)
						{
							int correction=[fh readUInt8];
							for(int i=0;i<(len&0x7f)+2;i++)
							[str appendFormat:@"%C",(unichar)(highbyte+(bytes[[str length]]+correction&0xff))];
						}
						else for(int i=0;i<(len&0x7f)+2;i++)
						[str appendFormat:@"%C",(unichar)(bytes[[str length]])];
					}
					break;
				}
			}
		}
		@catch(id e) {}

		// TODO: avoid re-encoding
		return [self XADPathWithData:[str dataUsingEncoding:NSUTF8StringEncoding]
		encodingName:XADUTF8StringEncodingName separators:XADWindowsPathSeparator];
	}
	else return [self XADPathWithData:data separators:XADWindowsPathSeparator];
}





-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	// Give the caller some ahead notice if we will be using a password.
	NSNumber *encryptnum=[dict objectForKey:XADIsEncryptedKey];
	if(encryptnum && [encryptnum boolValue])
	{
		if([[dict objectForKey:@"RARCompressionVersion"] intValue]<=20) caresaboutpasswordencoding=YES;
		[self password];
		if(![self hasPassword]) return nil;
	}

	CSHandle *handle;
	if([[dict objectForKey:@"RARCompressionMethod"] intValue]==0x30)
	{
		NSArray *files=[dict objectForKey:XADSolidObjectKey];
		int index=[[dict objectForKey:@"RARSolidIndex"] intValue];

		handle=[self inputHandleForFileWithIndex:index files:files];

		off_t length=[[dict objectForKey:XADSolidLengthKey] longLongValue];
		if(length!=[handle fileSize]) handle=[handle nonCopiedSubHandleOfLength:length];
	}
	else
	{
		off_t length=[[dict objectForKey:XADSolidLengthKey] longLongValue];

		// Avoid 0-length files because they make trouble in solid streams.
		if(length==0) handle=[self zeroLengthHandleWithChecksum:YES];
		else handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];
	}

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:[handle fileSize]
	correctCRC:[[dict objectForKey:@"RARCRC32"] unsignedIntValue] conditioned:YES];

	return handle;
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	int version=[[[obj objectAtIndex:0] objectForKey:@"Version"] intValue];

	switch(version)
	{
		case 15:
			return [[[XADRAR15Handle alloc] initWithRARParser:self files:obj] autorelease];

		case 20:
		case 26:
			return [[[XADRAR20Handle alloc] initWithRARParser:self files:obj] autorelease];

		case 29:
		case 36:
			return [[[XADRAR30Handle alloc] initWithRARParser:self files:obj] autorelease];

		default:
			return nil;
	}
}




-(CSInputBuffer *)inputBufferForFileWithIndex:(int)file files:(NSArray *)files
{
	return CSInputBufferAlloc([self inputHandleForFileWithIndex:file files:files],16384);
}

-(CSHandle *)inputHandleForFileWithIndex:(int)file files:(NSArray *)files
{
	if(file>=[files count]) [XADException raiseExceptionWithXADError:XADInputError]; // TODO: better error
	NSDictionary *dict=[files objectAtIndex:file];

	CSHandle *handle=[self inputHandleWithParts:[dict objectForKey:@"Parts"]
	encrypted:[[dict objectForKey:@"Encrypted"] longLongValue]
	cryptoVersion:[[dict objectForKey:@"Version"] intValue]
	salt:[dict objectForKey:@"Salt"]];

	return handle;
}

-(CSHandle *)inputHandleWithParts:(NSArray *)parts encrypted:(BOOL)encrypted
cryptoVersion:(int)version salt:(NSData *)salt
{
	CSHandle *handle=[[[XADRARInputHandle alloc] initWithRARParser:self parts:parts] autorelease];

	if(encrypted)
	{
		switch(version)
		{
			case 13: return [[[XADRAR13CryptHandle alloc] initWithHandle:handle
			length:[handle fileSize] password:[self encodedPassword]] autorelease];

			case 15: return [[[XADRAR15CryptHandle alloc] initWithHandle:handle
			length:[handle fileSize] password:[self encodedPassword]] autorelease];

			case 20: return [[[XADRAR20CryptHandle alloc] initWithHandle:handle
			length:[handle fileSize] password:[self encodedPassword]] autorelease];

			default:
			return [[[XADRARAESHandle alloc] initWithHandle:handle
			length:[handle fileSize] key:[self keyForSalt:salt]] autorelease];
		}
	}
	else return handle;
}

-(NSData *)keyForSalt:(NSData *)salt
{
	if(!keys) keys=[NSMutableDictionary new];

	NSData *key=[keys objectForKey:salt];
	if(key) return key;

	key=[XADRARAESHandle keyForPassword:[self password] salt:salt brokenHash:encryptversion<36];
	[keys setObject:key forKey:salt];
	return key;
}




-(off_t)outputLengthOfFileWithIndex:(int)file files:(NSArray *)files
{
	if(file>=[files count]) [XADException raiseExceptionWithXADError:XADInputError]; // TODO: better error
	NSDictionary *dict=[files objectAtIndex:file];

	return [[dict objectForKey:@"OutputLength"] longLongValue];
}




-(NSString *)formatName
{
	return @"RAR";
}

@end





@implementation XADEmbeddedRARParser

+(int)requiredHeaderSize
{
	return 0x80000;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	const uint8_t *header=FindSignature(bytes,length);
	if(header)
	{
		[props setObject:[NSNumber numberWithLongLong:header-bytes] forKey:@"RAREmbedOffset"];
		return YES;
	}

	return NO;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	const uint8_t *header=FindSignature(bytes,length);
	if(!header) return nil; // Shouldn't happen

	uint16_t flags=CSUInt16LE(&header[10]);

	// Don't bother looking for volumes if it the volume bit is not set.
	if(!(flags&0x01)) return nil;

	// Don't bother looking for volumes if it the new naming bit is not set.
	if(!(flags&0x10)) return nil;

	// New naming scheme. Find the last number in the name, and look for other files
	// with the same number of digits in the same location.
	NSArray *matches;
	if((matches=[name substringsCapturedByPattern:@"^(.*[^0-9])([0-9]+)(.*)\\.exe$" options:REG_ICASE]))
	return [self scanForVolumesWithFilename:name
	regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@[0-9]{%ld}%@.(rar|exe)$",
		[[matches objectAtIndex:1] escapedPattern],
		(long)[(NSString *)[matches objectAtIndex:2] length],
		[[matches objectAtIndex:3] escapedPattern]] options:REG_ICASE]
	firstFileExtension:@"exe"];

	return nil;
}

-(void)parse
{
	off_t offs=[[[self properties] objectForKey:@"RAREmbedOffset"] longLongValue];
	[[self handle] seekToFileOffset:offs];

	[super parse];
}

-(NSString *)formatName
{
	return @"Embedded RAR";
}

@end
