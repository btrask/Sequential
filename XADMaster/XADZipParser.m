#import "XADZipParser.h"
#import "XADZipImplodeHandle.h"
#import "XADZipShrinkHandle.h"
#import "XADDeflateHandle.h"
#import "XADLZMAHandle.h"
#import "XADPPMdHandles.h"
#import "XADZipCryptHandle.h"
#import "XADWinZipAESHandle.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

#import <sys/stat.h>


@implementation XADZipParser

+(int)requiredHeaderSize { return 8; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<8) return NO;

	if(bytes[0]=='P'&&bytes[1]=='K'&&bytes[2]==3&&bytes[3]==4) return YES;
	if(bytes[0]=='P'&&bytes[1]=='K'&&bytes[2]==5&&bytes[3]==6) return YES;
	if(bytes[4]=='P'&&bytes[5]=='K'&&bytes[6]==3&&bytes[7]==4) return YES;

	return NO;
}

+(XADRegex *)volumeRegexForFilename:(NSString *)filename
{
	NSArray *matches;

	if(matches=[filename substringsCapturedByPattern:@"^(.*)\\.(zip|z[0-9]{2})$" options:REG_ICASE])
	return [XADRegex regexWithPattern:[NSString stringWithFormat:
	@"^%@\\.(zip|z[0-9]{2})$",[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE];

	if(matches=[filename substringsCapturedByPattern:@"^(.*)\\.[0-9]{3}$" options:REG_ICASE])
	return [XADRegex regexWithPattern:[NSString stringWithFormat:
	@"^%@\\.[0-9]{3}$",[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE];

	return nil;
}

+(BOOL)isFirstVolume:(NSString *)filename
{
	return [filename rangeOfString:@".zip" options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	NSMutableDictionary *prevdict=nil;
	NSData *prevname=nil;

	[self findCentralDirectory];

	/*int disknumber=*/[fh readUInt16LE];
	int centraldirstartdisk=[fh readUInt16LE];
	/*int numentriesdisk=*/[fh readUInt16LE];
	int numentries=[fh readUInt16LE];
	/*int centralsize=*/[fh readUInt32LE];
	int centraloffset=[fh readUInt32LE];
	int commentlength=[fh readUInt16LE];

	// TODO: more closely check multi-archives
//	NSLog(@"disknumber:%d centraldirstartdisk:%d numentriesdisk:%d numentries:%d centralsize:%d centraloffset:%d",
//	disknumber,centraldirstartdisk,numentriesdisk,numentries,centralsize,centraloffset);

	if(commentlength)
	{
		NSData *comment=[fh readDataOfLength:commentlength];
		[self setObject:[self XADStringWithData:comment] forPropertyKey:XADCommentKey];
	}

	[fh seekToFileOffset:[self offsetForVolume:centraldirstartdisk offset:centraloffset]];

	for(int i=0;i<numentries;i++)
	{
		if(![self shouldKeepParsing]) break;

		uint32_t centralid=[fh readID];
		if(centralid!=0x504b0102) [XADException raiseIllegalDataException]; // could try recovering here

		/*int creatorversion=*/[fh readUInt8];
		int system=[fh readUInt8];
		int extractversion=[fh readUInt16LE];
		int flags=[fh readUInt16LE];
		int compressionmethod=[fh readUInt16LE];
		uint32_t date=[fh readUInt32LE];
		uint32_t crc=[fh readUInt32LE];
		uint32_t compsize=[fh readUInt32LE];
		uint32_t uncompsize=[fh readUInt32LE];
		int namelength=[fh readUInt16LE];
		int extralength=[fh readUInt16LE];
		int commentlength=[fh readUInt16LE];
		int startdisk=[fh readUInt16LE];
		/*int infileattrib=*/[fh readUInt16LE];
		uint32_t extfileattrib=[fh readUInt32LE];
		uint32_t locheaderoffset=[fh readUInt32LE];

		off_t next=[fh offsetInFile]+namelength+extralength+commentlength;

		#ifdef DEBUG
		if(compressionmethod==2||compressionmethod==3||compressionmethod==4||compressionmethod==7)
		NSLog(@"Untested ZIP compression method %d",compressionmethod);
		#endif

		[fh seekToFileOffset:[self offsetForVolume:startdisk offset:locheaderoffset]];

		uint32_t localid=[fh readID];
		if(localid==0x504b0304||localid==0x504b0506) // kludge for strange archives
		{
			//int localextractversion=[fh readUInt16LE];
			//int localflags=[fh readUInt16LE];
			//int localcompressionmethod=[fh readUInt16LE];
			[fh skipBytes:6];
			uint32_t localdate=[fh readUInt32LE];
			//uint32_t localcrc=[fh readUInt32LE];
			//uint32_t localcompsize=[fh readUInt32LE];
			//uint32_t localuncompsize=[fh readUInt32LE];
			[fh skipBytes:12];
			int localnamelength=[fh readUInt16LE];
			int localextralength=[fh readUInt16LE];

			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithInt:system],@"ZipOS",
				[NSNumber numberWithInt:extractversion],@"ZipExtractVersion",
				[NSNumber numberWithInt:flags],@"ZipFlags",
				[NSNumber numberWithInt:compressionmethod],@"ZipCompressionMethod",
				[NSDate XADDateWithMSDOSDateTime:date],XADLastModificationDateKey,
				[NSNumber numberWithUnsignedInt:crc],@"ZipCRC32",
				[NSNumber numberWithUnsignedInt:localdate],@"ZipLocalDate",
				[NSNumber numberWithUnsignedLong:compsize],XADCompressedSizeKey,
				[NSNumber numberWithUnsignedLong:uncompsize],XADFileSizeKey,
				[NSNumber numberWithLongLong:[fh offsetInFile]+localnamelength+localextralength],XADDataOffsetKey,
				[NSNumber numberWithUnsignedLong:compsize],XADDataLengthKey,
			nil];
			if(flags&0x01) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];

			NSString *systemname=nil;
			switch(system)
			{
				case 0: systemname=@"MS-DOS"; break;
				case 1: systemname=@"Amiga"; break;
				case 2: systemname=@"OpenVMS"; break;
				case 3: systemname=@"Unix"; break;
				case 4: systemname=@"VM/CMS"; break;
				case 5: systemname=@"Atari ST"; break;
				case 6: systemname=@"OS/2 H.P.F.S."; break;
				case 7: systemname=@"Macintosh"; break;
				case 8: systemname=@"Z-System"; break;
				case 9: systemname=@"CP/M"; break;
				case 10: systemname=@"Windows NTFS"; break;
				case 11: systemname=@"MVS (OS/390 - Z/OS)"; break;
				case 12: systemname=@"VSE"; break;
				case 13: systemname=@"Acorn Risc"; break;
				case 14: systemname=@"VFAT"; break;
				case 15: systemname=@"alternate MVS"; break;
				case 16: systemname=@"BeOS"; break;
				case 17: systemname=@"Tandem"; break;
				case 18: systemname=@"OS/400"; break;
				case 19: systemname=@"OS X (Darwin)"; break;
			}
			if(systemname) [dict setObject:[self XADStringWithString:systemname] forKey:@"ZipOSName"];

			NSString *compressionname=nil;
			switch(compressionmethod)
			{
				case 0: compressionname=@"None"; break;
				case 1: compressionname=@"Shrink"; break;
				case 2: compressionname=@"Reduce 1"; break;
				case 3: compressionname=@"Reduce 2"; break;
				case 4: compressionname=@"Reduce 3"; break;
				case 5: compressionname=@"Reduce 4"; break;
				case 6: compressionname=@"Implode"; break;
				case 8: compressionname=@"Deflate"; break;
				case 9: compressionname=@"Deflate64"; break;
				case 12: compressionname=@"Bzip2"; break;
				case 14: compressionname=@"LZMA"; break;
				case 98: compressionname=@"PPMd"; break;
			}
			if(compressionname) [dict setObject:[self XADStringWithString:compressionname] forKey:XADCompressionNameKey];

			NSData *namedata=nil;
			if(localnamelength)
			{
				namedata=[fh readDataOfLength:localnamelength];
				[dict setObject:[self XADPathWithData:namedata separators:XADUnixPathSeparator] forKey:XADFileNameKey];

				if(((char *)[namedata bytes])[localnamelength-1]=='/'&&uncompsize==0)
				[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

				const uint8_t *namebytes=[namedata bytes];
				int namelength=[namedata length];

				// If the previous entry was suspected of being a directory, check if the new
				// entry is a file inside it and set the directory flag for the previous one.
				if(prevdict)
				{
					const char *prevbytes=[prevname bytes];
					int prevlength=[prevname length];
					if(prevlength<namelength)
					{
						int i=0;
						while(namebytes[i]&&prevbytes[i]==namebytes[i]) i++;
						if(!prevbytes[i]&&namebytes[i]=='/')
						[prevdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
					}
				}

				// Check for possible MacBinary files
 				if(namelength>4)
				{
					if(memcmp(namebytes+namelength-4,".bin",4)==0)
					[dict setObject:[NSNumber numberWithBool:YES] forKey:XADMightBeMacBinaryKey];
				}

				// Kludge to make executables in bad Mac OS X app bundles
				// without permission information executable.
 				if(namelength>22&&system!=3)
				{
					for(int i=1;i<namelength-21;i++)
					if(memcmp(namebytes+i,".app/Contents/MacOS/",20)==0)
					{
						mode_t mask=umask(0); umask(mask);
						[dict setObject:[NSNumber numberWithUnsignedShort:0777&~mask] forKey:XADPosixPermissionsKey];
						break;
					}
				}
			}
			else
			{
				[dict setObject:[self XADPathWithUnseparatedString:[[self name] stringByDeletingPathExtension]] forKey:XADFileNameKey];
				// TODO: set no filename flag
			}

			//if(zc.System==1) fi2->xfi_Protection = ((EndGetI32(zc.ExtFileAttrib)>>16)^15)&0xFF; // amiga
			if(system==0) // ms-dos
			{
				if(extfileattrib&0x10) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
				[dict setObject:[NSNumber numberWithInt:extfileattrib] forKey:XADDOSFileAttributesKey];
			}
			else if(system==3) // unix
			{
				int perm=extfileattrib>>16;
				[dict setObject:[NSNumber numberWithInt:perm] forKey:XADPosixPermissionsKey];

				if((perm&0xf000)==0x4000) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
				else if((perm&0xf000)==0xa000) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsLinkKey];
			}

			@try {
				if(localextralength) [self parseZipExtraWithDictionary:dict length:localextralength];
			} @catch(id e) {
				[self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];
				NSLog(@"Error parsing Zip extra fields: %@",e);
			}

			if(prevdict)
			{
				[self addEntryWithDictionary:prevdict];
				prevdict=nil;
			}

			if(uncompsize==0&&i!=numentries-1&&!([dict objectForKey:XADIsDirectoryKey]
			&&[[dict objectForKey:XADIsDirectoryKey] boolValue]))
			{
				prevdict=dict; // this entry could be a directory, save it for testing against the next entry
				prevname=namedata;
			}
			else
			{
				[self addEntryWithDictionary:dict];
			}
		}
		else [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];

		[fh seekToFileOffset:next];
	}
}

static inline int imin(int a,int b) { return a<b?a:b; }

-(void)findCentralDirectory
{
	CSHandle *fh=[self handle];

	[fh seekToEndOfFile];
	off_t end=[fh offsetInFile];

	int scansize=0x10011;
	if(scansize>end) scansize=end;

	uint8_t buf[1024];

	int numbytes=imin(sizeof(buf),scansize);
	[fh skipBytes:-numbytes];
	[fh readBytes:numbytes toBuffer:buf];
	int pos=numbytes-4;
	scansize-=numbytes;

	for(;;)
	{
		if(buf[pos]=='P'&&buf[pos+1]=='K'&&buf[pos+2]==5&&buf[pos+3]==6) break;

		pos--;

		if(pos<0)
		{
			if(scansize==0) [XADException raiseIllegalDataException];

			int lastbytes=numbytes;
			numbytes=imin(sizeof(buf)-3,scansize);
			memmove(buf+numbytes,buf,3);
			[fh skipBytes:-lastbytes-numbytes];
			[fh readBytes:numbytes toBuffer:buf];
			pos=numbytes-1;
			scansize-=numbytes;
		}
	}

	[fh skipBytes:pos+4-numbytes];
}

-(void)parseZipExtraWithDictionary:(NSMutableDictionary *)dict length:(int)length
{
	CSHandle *fh=[self handle];

	off_t end=[fh offsetInFile]+length;

	while(length>9)
	{
		int extid=[fh readUInt16LE];
		int size=[fh readUInt16LE];
		length-=4;

		if(size>length) break;
		length-=size;
		off_t next=[fh offsetInFile]+size;

		if(extid==0x5455&&size>=5) // Extended Timestamp Extra Field
		{
			int flags=[fh readUInt8];
			if(flags&1) [dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
			if(flags&2) [dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastAccessDateKey];
			if(flags&4) [dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADCreationDateKey];
		}
		else if(extid==0x5855&&size>=8) // Info-ZIP Unix Extra Field (type 1)
		{
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastAccessDateKey];
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[fh readUInt32LE]] forKey:XADLastModificationDateKey];
			if(size>=10) [dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixUserKey];
			if(size>=12) [dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixGroupKey];
		}
		else if(extid==0x7855&&size>=8) // Info-ZIP Unix Extra Field (type 2)
		{
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixUserKey];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:XADPosixGroupKey];
		}
		else if(extid==0x334d&&size>=14) // Info-ZIP Macintosh Extra Field
		{
			int len=[fh readUInt32LE];
			int flags=[fh readUInt16LE];
			[dict setObject:[NSNumber numberWithUnsignedLong:[fh readID]] forKey:XADFileTypeKey];
			[dict setObject:[NSNumber numberWithUnsignedLong:[fh readID]] forKey:XADFileCreatorKey];

			CSHandle *mh=nil;
			if(flags&0x04) mh=fh; // uncompressed
			else
			{
				int ctype=[fh readUInt16LE];
				[fh skipBytes:4]; // skip CRC
				mh=[self decompressionHandleWithHandle:fh method:ctype flags:0 size:len];
			}
			if(mh&&len>=26)
			{
				[dict setObject:[NSNumber numberWithUnsignedLong:[mh readUInt16LE]] forKey:XADFinderFlagsKey];
				[mh skipBytes:24];

				off_t create,modify,backup;

				if(flags&0x08)
				{
					create=[mh readUInt64LE];
					modify=[mh readUInt64LE];
					backup=[mh readUInt64LE];
				}
				else
				{
					create=[mh readUInt32LE];
					modify=[mh readUInt32LE];
					backup=[mh readUInt32LE];
				}

				if(!(flags&0x10))
				{
					create+=[mh readInt32LE];
					modify+=[mh readInt32LE];
					backup+=[mh readInt32LE];
				}

				if(create>=86400) [dict setObject:[NSDate XADDateWithTimeIntervalSince1904:create] forKey:XADCreationDateKey];
				if(modify>=86400) [dict setObject:[NSDate XADDateWithTimeIntervalSince1904:modify] forKey:XADLastModificationDateKey];
				if(backup>=86400) [dict setObject:[NSDate XADDateWithTimeIntervalSince1904:backup] forKey:@"MacOSBackupDate"];
			}
		}
		else if(extid==0x2605&&size>=13) // ZipIt Macintosh Extra Field (long)
		{
			// ZipIt structure - the presence of it indicates the file is MacBinary encoded,
			// IF it is a file and not directory. Ignore information in this and rely on the
			// data stored in the MacBinary file instead, and mark the file.
			if(!([dict objectForKey:XADIsDirectoryKey]&&[[dict objectForKey:XADIsDirectoryKey] boolValue]))
			{
				if([fh readID]=='ZPIT') [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsMacBinaryKey];
			}
		}
		else if(extid==0x2705&&size>=12) // ZipIt Macintosh Extra Field (short, for files)
		{
			if([fh readID]=='ZPIT')
			{
				[dict setObject:[NSNumber numberWithUnsignedLong:[fh readID]] forKey:XADFileTypeKey];
				[dict setObject:[NSNumber numberWithUnsignedLong:[fh readID]] forKey:XADFileCreatorKey];
				if(size>=14) [dict setObject:[NSNumber numberWithUnsignedLong:[fh readUInt16BE]] forKey:XADFinderFlagsKey];
			}
		}
		else if(extid==0x2805&&size>=6) // ZipIt Macintosh Extra Field (short, for directories)
		{
			if([fh readID]=='ZPIT')
			{
				[dict setObject:[NSNumber numberWithUnsignedLong:[fh readUInt16BE]] forKey:XADFinderFlagsKey];
			}
		}
		else if(extid==0x9901&&size>=7)
		{
			int version;
			[dict setObject:[NSNumber numberWithInt:version=[fh readUInt16LE]] forKey:@"WinZipAESVersion"];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:@"WinZipAESVendor"];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt8]] forKey:@"WinZipAESKeySize"];
			[dict setObject:[NSNumber numberWithInt:[fh readUInt16LE]] forKey:@"WinZipAESCompressionMethod"];
			if(version==2) [dict removeObjectForKey:@"ZipCRC32"];
		}
		else
		{
			//NSLog(@"unknown extension: %x %d %@",extid,size,[fh readDataOfLength:size]);
			[fh skipBytes:size];
		}

		[fh seekToFileOffset:next];
	}

	[fh seekToFileOffset:end];
}

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *fh=[self handleAtDataOffsetForDictionary:dict];

	int compressionmethod=[[dict objectForKey:@"ZipCompressionMethod"] intValue];
	int flags=[[dict objectForKey:@"ZipFlags"] intValue];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];

	NSNumber *enc=[dict objectForKey:XADIsEncryptedKey];
	if(enc&&[enc boolValue])
	{
		off_t compsize=[[dict objectForKey:XADCompressedSizeKey] longLongValue];

		if(compressionmethod==99)
		{
			compressionmethod=[[dict objectForKey:@"WinZipAESCompressionMethod"] intValue];

			int version=[[dict objectForKey:@"WinZipAESVersion"] intValue];
			int vendor=[[dict objectForKey:@"WinZipAESVendor"] intValue];
			int keysize=[[dict objectForKey:@"WinZipAESKeySize"] intValue];
			if(version!=1&&version!=2) [XADException raiseNotSupportedException];
			if(vendor!=0x4541) [XADException raiseNotSupportedException];
			if(keysize<1||keysize>3) [XADException raiseNotSupportedException];

			int keybytes;
			switch(keysize)
			{
				case 1: keybytes=16; break;
				case 2: keybytes=24; break;
				case 3: keybytes=32; break;
			}

			// TODO: handle checksums for WinZip AES files!
			fh=[[[XADWinZipAESHandle alloc] initWithHandle:fh length:compsize
			password:[self encodedPassword] keyLength:keybytes] autorelease];
		}
		else
		{
			if(flags&0x40) [XADException raiseNotSupportedException];

			uint8_t test;
			if(flags&0x08) test=[[dict objectForKey:@"ZipLocalDate"] intValue]>>8;
			else test=[[dict objectForKey:@"ZipCRC32"] unsignedIntValue]>>24;

			fh=[[[XADZipCryptHandle alloc] initWithHandle:fh length:compsize
			password:[self encodedPassword] testByte:test] autorelease];
		}
	}

	CSHandle *handle=[self decompressionHandleWithHandle:fh method:compressionmethod flags:flags size:size];
	if(!handle) return nil;

	if(checksum)
	{
		NSNumber *crc=[dict objectForKey:@"ZipCRC32"];
		if(crc) return [XADCRCHandle IEEECRC32HandleWithHandle:handle
		length:size correctCRC:[crc unsignedIntValue] conditioned:YES];
	}

	return handle;
}

-(CSHandle *)decompressionHandleWithHandle:(CSHandle *)parent method:(int)method flags:(int)flags size:(off_t)size
{
	switch(method)
	{
		case 0: return parent;
		case 1: return [[[XADZipShrinkHandle alloc] initWithHandle:parent length:size] autorelease];
		case 6: return [[[XADZipImplodeHandle alloc] initWithHandle:parent length:size
						largeDictionary:flags&0x02 hasLiterals:flags&0x04] autorelease];
		case 8: return [CSZlibHandle deflateHandleWithHandle:parent length:size];
		//case 8: return [[[XADDeflateHandle alloc] initWithHandle:parent length:size] autorelease];
		case 9: return [[[XADDeflateHandle alloc] initWithHandle:parent length:size variant:XADDeflate64DeflateVariant] autorelease];
		case 12: return [CSBzip2Handle bzip2HandleWithHandle:parent length:size];
		case 14:
		{
			[parent skipBytes:2];
			int len=[parent readUInt16LE];
			NSData *props=[parent readDataOfLength:len];
			return [[[XADLZMAHandle alloc] initWithHandle:parent length:size propertyData:props] autorelease];
		}
		break;
		case 98:
		{
			uint16_t info=[parent readUInt16LE];
			int maxorder=(info&0x0f)+1;
			int suballocsize=(((info>>4)&0xff)+1)<<20;
			int modelrestoration=info>>12;
			return [[[XADPPMdVariantIHandle alloc] initWithHandle:parent length:size
			maxOrder:maxorder subAllocSize:suballocsize modelRestorationMethod:modelrestoration] autorelease];
		}
		break;
		default: return nil;
	}
}

-(NSString *)formatName { return @"Zip"; }

@end
