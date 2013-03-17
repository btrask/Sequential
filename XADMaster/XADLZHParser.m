#import "XADLZHParser.h"
#import "XADLZHStaticHandle.h"
#import "XADLZHDynamicHandle.h"
#import "XADLArcHandles.h"
#import "XADLZHOldHandles.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

@implementation XADLZHParser

+(int)requiredHeaderSize { return 7; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<7) return NO;

	if(bytes[2]=='-'&&bytes[3]=='l'&&bytes[4]=='h'&&bytes[6]=='-') // lzh files
	{
		if(bytes[5]=='0'||bytes[5]=='1') return YES; // uncompressed and old
		if(bytes[5]=='2'||bytes[5]=='3') return YES; // old experimental
		if(bytes[5]=='4'||bytes[5]=='5'||bytes[5]=='6'||bytes[5]=='7') return YES; // new
		if(bytes[5]=='d') return YES; // directory
	}

	if(bytes[2]=='-'&&bytes[3]=='l'&&bytes[4]=='z'&&bytes[6]=='-') // larc files
	{
		if(bytes[5]=='0'||bytes[5]=='4'||bytes[5]=='5') return YES;
	}

	if(bytes[2]=='-'&&bytes[3]=='p'&&bytes[4]=='m'&&bytes[6]=='-') // pmarc files
	{
		if(bytes[5]=='0'||bytes[5]=='1'||bytes[5]=='2') return YES;
	}

	return NO;
}

-(void)parseWithSeparateMacForks
{
	CSHandle *fh=[self handle];

	int guessedos=0;

	while([self shouldKeepParsing] && ![fh atEndOfFile])
	{
		off_t start=[fh offsetInFile];

		uint8_t b1=[fh readUInt8];
		if(b1==0) break;

		uint8_t b2=[fh readUInt8];

		int firstword=b1|(b2<<8);

		uint8_t method[5];
		[fh readBytes:5 toBuffer:method];

		uint32_t compsize=[fh readUInt32LE];
		uint32_t size=[fh readUInt32LE];
		uint32_t time=[fh readUInt32LE];

		int attrs=[fh readUInt8];
		int level=[fh readUInt8];

		NSString *compname=[[[NSString alloc] initWithBytes:method length:5 encoding:NSISOLatin1StringEncoding] autorelease];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithUnsignedInt:size],XADFileSizeKey,
			[self XADStringWithString:compname],XADCompressionNameKey,
			[NSNumber numberWithInt:level],@"LHAHeaderLevel",
		nil];

		uint32_t headersize;
		int os;

		if(level==0||level==1)
		{
			headersize=(firstword&0xff)+2;

			[dict setObject:[NSDate XADDateWithMSDOSDateTime:time] forKey:XADLastModificationDateKey];

			int namelen=[fh readUInt8];
			[dict setObject:[fh readDataOfLength:namelen] forKey:@"LHAHeaderFileNameData"];

			int crc=[fh readUInt16LE];
			[dict setObject:[NSNumber numberWithInt:crc] forKey:@"LHACRC16"];

			if(level==1)
			{
				os=[fh readUInt8];
				[dict setObject:[NSNumber numberWithInt:os] forKey:@"LHAOS"];

				for(;;)
				{
					int extsize=[fh readUInt16LE];
					if(extsize==0) break;
					headersize+=extsize;
					compsize-=extsize;

					[self parseExtendedForDictionary:dict size:extsize-2];
				}
			}
		}
		else if(level==2)
		{
			[self reportInterestingFileWithReason:@"LZH level 2 file"];

			headersize=firstword;

			[dict setObject:[NSDate dateWithTimeIntervalSince1970:time] forKey:XADLastModificationDateKey];

			int crc=[fh readUInt16LE];
			[dict setObject:[NSNumber numberWithInt:crc] forKey:@"LHACRC16"];

			os=[fh readUInt8];

			for(;;)
			{
				int extsize=[fh readUInt16LE];
				if(extsize==0) break;
				[self parseExtendedForDictionary:dict size:extsize-2];
			}
		}
		else if(level==3)
		{
			[self reportInterestingFileWithReason:@"LZH level 3 file"];

			if(firstword!=4) [XADException raiseNotSupportedException];

			[dict setObject:[NSDate dateWithTimeIntervalSince1970:time] forKey:XADLastModificationDateKey];

			int crc=[fh readUInt16LE];
			[dict setObject:[NSNumber numberWithInt:crc] forKey:@"LHACRC16"];

			os=[fh readUInt8];

			headersize=[fh readUInt32LE];

			for(;;)
			{
				int extsize=[fh readUInt32LE];
				if(extsize==0) break;
				[self parseExtendedForDictionary:dict size:extsize-4];
			}
		}
		else [XADException raiseIllegalDataException];

		if(level==0)
		{
			if(!guessedos)
			{
				NSString *name=[self filename];

				if([name matchedByPattern:@"\\.(lha|run)$"
				options:REG_ICASE]) guessedos='A';
				else guessedos='M';
			}

			if(guessedos=='M')
			{
				[dict setObject:[self XADStringWithString:@"MS-DOS"] forKey:@"LHAGuessedOSName"];
				[dict setObject:[NSNumber numberWithInt:attrs] forKey:XADDOSFileAttributesKey];
			}
			else
			{
				[dict setObject:[self XADStringWithString:@"Amiga"] forKey:@"LHAGuessedOSName"];
				[dict setObject:[NSNumber numberWithInt:attrs] forKey:XADAmigaProtectionBitsKey];
			}
		}
		else
		{
			[dict setObject:[NSNumber numberWithInt:os] forKey:@"LHAOS"];

			NSString *osname=nil;
			switch(os)
			{
				case 'M': osname=@"MS-DOS"; break;
				case '2': osname=@"OS/2"; break;
				case '9': osname=@"OS9"; break;
				case 'K': osname=@"OS/68K"; break;
				case '3': osname=@"OS/386"; break;
				case 'H': osname=@"HUMAN"; break;
				case 'U': osname=@"Unix"; break;
				case 'C': osname=@"CP/M"; break;
				case 'F': osname=@"FLEX"; break;
				case 'm': osname=@"Mac OS"; break;
				case 'w': osname=@"Windows 95, 98"; break;
				case 'W': osname=@"Windows NT"; break;
				case 'R': osname=@"Runser"; break;
				case 'T': osname=@"TownsOS"; break;
				case 'X': osname=@"XOSK"; break;
				//case '': methodname=@""; break;
			}
			if(osname) [dict setObject:[self XADStringWithString:osname] forKey:@"LHAOSName"];

			[dict setObject:[NSNumber numberWithInt:attrs] forKey:XADDOSFileAttributesKey];

			if(os=='m')
			{
				[self setIsMacArchive:YES];
				[dict setObject:[NSNumber numberWithBool:YES] forKey:XADMightBeMacBinaryKey];
			}
		}

		[dict setValue:[NSNumber numberWithUnsignedInt:compsize] forKey:XADCompressedSizeKey];
		[dict setValue:[NSNumber numberWithUnsignedInt:compsize] forKey:XADDataLengthKey];
		[dict setValue:[NSNumber numberWithLongLong:start+headersize] forKey:XADDataOffsetKey];

		if(memcmp(method,"-lhd-",5)==0) [dict setValue:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

		NSData *filenamedata=[dict objectForKey:@"LHAExtFileNameData"];
		if(!filenamedata) filenamedata=[dict objectForKey:@"LHAHeaderFileNameData"];
		NSData *directorydata=[dict objectForKey:@"LHAExtDirectoryData"];
		XADPath *path=nil;
		if(directorydata)
		{
			path=[self XADPathWithData:directorydata separators:"\xff"];
			if(filenamedata&&[filenamedata length])
			path=[path pathByAppendingXADStringComponent:[self XADStringWithData:filenamedata]];
		}
		else if(filenamedata) path=[self XADPathWithData:filenamedata separators:"\xff\\/"];

		if(path) [dict setObject:path forKey:XADFileNameKey];

		[self addEntryWithDictionary:dict];

		[fh seekToFileOffset:start+headersize+compsize];
	}
}

-(void)parseExtendedForDictionary:(NSMutableDictionary *)dict size:(int)size
{
	CSHandle *fh=[self handle];
	off_t nextpos=[fh offsetInFile]+size;

	switch([fh readUInt8])
	{
		case 0x01:
			[dict setObject:[fh readDataOfLength:size-1] forKey:@"LHAExtFileNameData"];
		break;

		case 0x02:
			[dict setObject:[fh readDataOfLength:size-1] forKey:@"LHAExtDirectoryData"];
		break;

		case 0x3f:
		case 0x71:
			[dict setObject:[self XADStringWithData:[fh readDataOfLength:size-1]] forKey:XADCommentKey];
		break;

		case 0x40:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADDOSFileAttributesKey];
		break;

		case 0x41:
			[dict setObject:[NSDate XADDateWithWindowsFileTimeLow:[fh readUInt32LE]
			high:[fh readUInt32LE]] forKey:XADCreationDateKey];
			[dict setObject:[NSDate XADDateWithWindowsFileTimeLow:[fh readUInt32LE]
			high:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
			[dict setObject:[NSDate XADDateWithWindowsFileTimeLow:[fh readUInt32LE]
			high:[fh readUInt32LE]] forKey:XADLastAccessDateKey];
		break;

		case 0x42:
			// 64-bit file sizes
			[self reportInterestingFileWithReason:@"64-bit file"];
			[XADException raiseNotSupportedException];
		break;

		case 0x50:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixPermissionsKey];
		break;

		case 0x51:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixGroupKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixUserKey];
		break;

		case 0x52:
			[dict setObject:[self XADStringWithData:[fh readDataOfLength:size-1]] forKey:XADPosixGroupNameKey];
		break;

		case 0x53:
			[dict setObject:[self XADStringWithData:[fh readDataOfLength:size-1]] forKey:XADPosixUserNameKey];
		break;

		case 0x54:
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
		break;

		case 0x7f:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADDOSFileAttributesKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixPermissionsKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixGroupKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixUserKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADCreationDateKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
		break;

		// case 0xc4: // compressed comment, -lh5- 4096
		// case 0xc5: // compressed comment, -lh5- 8192
		// case 0xc6: // compressed comment, -lh5- 16384
		// case 0xc7: // compressed comment, -lh5- 32768
		// case 0xc8: // compressed comment, -lh5- 65536

		case 0xff:
			[dict setObject:[NSNumber numberWithInt:[fh readUInt32LE]] forKey:XADPosixPermissionsKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt32LE]] forKey:XADPosixGroupKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt32LE]] forKey:XADPosixUserKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADCreationDateKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
		break;
	}

	[fh seekToFileOffset:nextpos];
}


-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];
	NSString *method=[[dict objectForKey:XADCompressionNameKey] string];
	int crc=[[dict objectForKey:@"LHACRC16"] intValue];

	if([method isEqual:@"-lh0-"])
	{
		// no compression, do nothing
	}
	else if([method isEqual:@"-lh1-"])
	{
		handle=[[[XADLZHDynamicHandle alloc] initWithHandle:handle length:size] autorelease];
	}
	else if([method isEqual:@"-lh2-"])
	{
		[self reportInterestingFileWithReason:@"-lh2- compression"];
		handle=[[[XADLZH2Handle alloc] initWithHandle:handle length:size] autorelease];
	}
	else if([method isEqual:@"-lh3-"])
	{
		[self reportInterestingFileWithReason:@"-lh3- compression"];
		handle=[[[XADLZH3Handle alloc] initWithHandle:handle length:size] autorelease];
	}
	else if([method isEqual:@"-lh4-"])
	{
		handle=[[[XADLZHStaticHandle alloc] initWithHandle:handle length:size windowBits:12] autorelease];
	}
	else if([method isEqual:@"-lh5-"])
	{
		handle=[[[XADLZHStaticHandle alloc] initWithHandle:handle length:size windowBits:13] autorelease];
	}
	else if([method isEqual:@"-lh6-"])
	{
		handle=[[[XADLZHStaticHandle alloc] initWithHandle:handle length:size windowBits:15] autorelease];
	}
	else if([method isEqual:@"-lh7-"])
	{
		handle=[[[XADLZHStaticHandle alloc] initWithHandle:handle length:size windowBits:16] autorelease];
	}
	else if([method isEqual:@"-lzs-"])
	{
		handle=[[[XADLArcLZSHandle alloc] initWithHandle:handle length:size] autorelease];
	}
	else if([method isEqual:@"-lz4-"])
	{
		// no compression, do nothing
	}
	else if([method isEqual:@"-lz5-"])
	{
		handle=[[[XADLArcLZ5Handle alloc] initWithHandle:handle length:size] autorelease];
	}
	else if([method isEqual:@"-pm0-"])
	{
		// no compression, do nothing
	}
	else if([method isEqual:@"-pm2-"])
	{
		[self reportInterestingFileWithReason:@"-pm2- compression"];
		handle=[[[XADPMArc2Handle alloc] initWithHandle:handle length:size] autorelease];
	}
	else // not supported
	{
		[self reportInterestingFileWithReason:@"Unsupported compression method %@",method];
		return nil; 
	}

	if(checksum) handle=[XADCRCHandle IBMCRC16HandleWithHandle:handle length:size correctCRC:crc conditioned:NO];

	return handle;
}

-(NSString *)formatName { return @"LZH"; }

@end
