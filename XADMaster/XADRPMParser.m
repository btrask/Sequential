#import "XADRPMParser.h"

@implementation XADRPMParser

+(int)requiredHeaderSize { return 96; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<6) return NO;
	if(bytes[0]==0xed&&bytes[1]==0xab&&bytes[2]==0xee&&bytes[3]==0xdb)
	{
		return YES;
	}
	return NO;
}

static int FindStringLength(const uint8_t *buffer,int size,int offset)
{
	int len=0;
	while(offset+len<size&&buffer[offset+len]) len++;
	return len;
}

static uint64_t ParseInt(const uint8_t *buffer,int size,int type,int offset)
{
	if(type<2||type>5) return 0;

	if(offset+(1<<type-2)>size) return 0;

	if(type==2) return buffer[offset];
	else if(type==3) return CSUInt16BE(&buffer[offset]);
	else if(type==4) return CSUInt32BE(&buffer[offset]);
	else if(type==5) return CSUInt64BE(&buffer[offset]);
	else return 0; // Can't happen
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:4];
	int major=[fh readUInt8];
	/*int minor=*/[fh readUInt8];
	/*int type=*/[fh readUInt16BE];
	/*int archnum=*/[fh readUInt16BE];

	uint8_t name[66];
	[fh readBytes:66 toBuffer:name];
	int namelen=FindStringLength(name,66,0);
	NSMutableData *namedata=[NSMutableData dataWithBytes:name length:namelen];

	/*int osnum=*/[fh readUInt16BE];
	int sigtype=[fh readUInt16BE];
	[fh skipBytes:16];

	switch(sigtype)
	{
		case 0: break;

		case 1:
			[fh skipBytes:256];
		break;

		case 5:
		{
			if([fh readID]!=0x8eade801) [XADException raiseIllegalDataException];
			[fh skipBytes:4];
			int sigentries=[fh readUInt32BE];
			int sigbytes=[fh readUInt32BE];
			[fh skipBytes:sigentries*16+(sigbytes+7&~7)];
		}
		break;

		default:
			[self reportInterestingFileWithReason:@"Unsupported signature type %d",sigtype];
			[XADException raiseNotSupportedException];
	}

	const char *archiveext="cpio";
	const char *compressionext="gz";

	if(major>1)
	{
		if(major>2)
		{
			if([fh readID]!=0x8eade801) [XADException raiseIllegalDataException];
			[fh skipBytes:4];
		}

		int headentries=[fh readUInt32BE];
		int headbytes=[fh readUInt32BE];

		NSData *entrydata=[fh readDataOfLength:headentries*16];
		NSData *storagedata=[fh readDataOfLength:headbytes];

		const uint8_t *entries=[entrydata bytes];
		const uint8_t *storage=[storagedata bytes];


		for(int i=0;i<headentries;i++)
		{
			uint32_t tag=CSUInt32BE(entries+i*16+0);
			//uint32_t type=CSUInt32BE(entries+i*16+4);
			uint32_t offset=CSUInt32BE(entries+i*16+8);
			//uint32_t count=CSUInt32BE(entries+i*16+12);

			switch(tag)
			{
				case 1000:
				{
					int len=FindStringLength(storage,headbytes,offset);
					namedata=[NSMutableData dataWithBytes:storage+offset length:len];
				}
				break;

				/*case 1046:
				{
					int somelength=ParseInt(storage,headbytes,type,offset);
				}
				break;*/

				case 1124:
				{
					int len=FindStringLength(storage,headbytes,offset);
					if(len==4&&memcmp(storage+offset,"cpio",4)==0) archiveext="cpio";
					else archiveext=NULL;
				}
				break;

				case 1125:
				{
					int len=FindStringLength(storage,headbytes,offset);
					if(len==4&&memcmp(storage+offset,"gzip",4)==0) compressionext="gz";
					else if(len==5&&memcmp(storage+offset,"bzip2",5)==0) compressionext="bz2";
					else if(len==4&&memcmp(storage+offset,"lzma",4)==0) compressionext="lzma";
					else if(len==2&&memcmp(storage+offset,"xz",2)==0) compressionext="xz";
					else compressionext=NULL;
				}
				break;
			}
		}
	}

	if(archiveext)
	{
		[namedata appendBytes:"." length:1];
		[namedata appendBytes:archiveext length:strlen(archiveext)];
	}

	if(compressionext)
	{
		[namedata appendBytes:"." length:1];
		[namedata appendBytes:compressionext length:strlen(compressionext)];
	}

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithData:namedata separators:XADUnixPathSeparator],XADFileNameKey,
		[NSNumber numberWithLongLong:[fh offsetInFile]],XADDataOffsetKey,
		[NSNumber numberWithBool:YES],XADIsArchiveKey,
	nil];

	off_t filesize=[fh fileSize];
	if(filesize!=CSHandleMaxLength)
	{
		off_t length=filesize-[fh offsetInFile];
		[dict setObject:[NSNumber numberWithLongLong:length] forKey:XADFileSizeKey];
		[dict setObject:[NSNumber numberWithLongLong:length] forKey:XADCompressedSizeKey];
		[dict setObject:[NSNumber numberWithLongLong:length] forKey:XADDataLengthKey];
	}

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self handleAtDataOffsetForDictionary:dict];
}

-(NSString *)formatName { return @"RPM"; }

@end


