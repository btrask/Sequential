#import "XADCpioParser.h"
#import "XADChecksumHandle.h"
#import "NumberParsing.h"


@implementation XADCpioParser

+(int)requiredHeaderSize { return 6; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<6) return NO;
	if(bytes[0]=='0'&&bytes[1]=='7'&&bytes[2]=='0'&&bytes[3]=='7'&&bytes[4]=='0'&&bytes[5]=='7') return YES;
	if(bytes[0]=='0'&&bytes[1]=='7'&&bytes[2]=='0'&&bytes[3]=='7'&&bytes[4]=='0'&&bytes[5]=='1') return YES;
	if(bytes[0]=='0'&&bytes[1]=='7'&&bytes[2]=='0'&&bytes[3]=='7'&&bytes[4]=='0'&&bytes[5]=='2') return YES;
	if(bytes[0]==0x71&&bytes[1]==0xc7) return YES;
	if(bytes[0]==0xc7&&bytes[1]==0x71) return YES;

	return NO;
}

-(void)parseWithSeparateMacForks
{
	CSHandle *fh=[self handle];

	while([self shouldKeepParsing])
	{
		uint8_t magic[2];
		[fh readBytes:2 toBuffer:magic];

		int devmajor,devminor,ino,mode,uid,gid,nlink,rdevmajor,rdevminor,namesize,checksum;
		uint64_t mtime,filesize;
		NSData *namedata;
		int pad=0;
		BOOL haschecksum=NO;

		if(magic[0]=='0'&&magic[1]=='7') // ASCII
		{
			uint8_t more[4];
			[fh readBytes:4 toBuffer:more];
			if(more[0]=='0'&&more[1]=='7'&&more[2]=='0'&&more[3]=='7')
			{
				devmajor=[fh readOctalNumberWithDigits:3];
				devminor=[fh readOctalNumberWithDigits:3];
				ino=[fh readOctalNumberWithDigits:6];
				mode=[fh readOctalNumberWithDigits:6];
				uid=[fh readOctalNumberWithDigits:6];
				gid=[fh readOctalNumberWithDigits:6];
				nlink=[fh readOctalNumberWithDigits:6];
				rdevmajor=[fh readOctalNumberWithDigits:3];
				rdevminor=[fh readOctalNumberWithDigits:3];
				mtime=[fh readOctalNumberWithDigits:11];
				namesize=[fh readOctalNumberWithDigits:6];
				filesize=[fh readOctalNumberWithDigits:11];
				namedata=[fh readDataOfLength:namesize-1];
				[fh skipBytes:1];
			}
			else if(more[0]=='0'&&more[1]=='7'&&more[2]=='0'&&(more[3]=='1'||more[3]=='2'))
			{
				ino=[fh readHexadecimalNumberWithDigits:8];
				mode=[fh readHexadecimalNumberWithDigits:8];
				uid=[fh readHexadecimalNumberWithDigits:8];
				gid=[fh readHexadecimalNumberWithDigits:8];
				nlink=[fh readHexadecimalNumberWithDigits:8];
				mtime=[fh readHexadecimalNumberWithDigits:8];
				filesize=[fh readHexadecimalNumberWithDigits:8];
				devmajor=[fh readHexadecimalNumberWithDigits:8];
				devminor=[fh readHexadecimalNumberWithDigits:8];
				rdevmajor=[fh readHexadecimalNumberWithDigits:8];
				rdevminor=[fh readHexadecimalNumberWithDigits:8];
				namesize=[fh readHexadecimalNumberWithDigits:8];
				checksum=[fh readHexadecimalNumberWithDigits:8];
				namedata=[fh readDataOfLength:namesize-1];
				[fh skipBytes:1+((-namesize-2&3))];

				pad=(-filesize)&3;
				if(more[3]=='2') haschecksum=YES;
			}
			else [XADException raiseIllegalDataException];
		}
		else if(magic[0]==0x71&&magic[1]==0xc7) // big-endian binary
		{
			int dev=[fh readUInt16BE];
			ino=[fh readUInt16BE];
			mode=[fh readUInt16BE];
			uid=[fh readUInt16BE];
			gid=[fh readUInt16BE];
			nlink=[fh readUInt16BE];
			int rdev=[fh readUInt16BE];
			mtime=[fh readUInt32BE];
			namesize=[fh readUInt16BE];
			filesize=[fh readUInt32BE];

			namedata=[fh readDataOfLength:namesize-1];
			[fh skipBytes:1+(namesize&1)];

			devmajor=dev>>9;
			devminor=dev&0x1ff;
			rdevmajor=rdev>>9;
			rdevminor=rdev&0x1ff;

			pad=filesize&1;
		}
		else if(magic[0]==0xc7&&magic[1]==0x71) // little-endian binary
		{
			int dev=[fh readUInt16LE];
			ino=[fh readUInt16LE];
			mode=[fh readUInt16LE];
			uid=[fh readUInt16LE];
			gid=[fh readUInt16LE];
			nlink=[fh readUInt16LE];
			int rdev=[fh readUInt16LE];
			int mtimehigh=[fh readUInt16LE];
			int mtimelow=[fh readUInt16LE];
			namesize=[fh readUInt16LE];
			int filesizehigh=[fh readUInt16LE];
			int filesizelow=[fh readUInt16LE];

			namedata=[fh readDataOfLength:namesize-1];
			[fh skipBytes:1+(namesize&1)];

			mtime=(mtimehigh<<16)+mtimelow;
			filesize=(filesizehigh<<16)+filesizelow;

			devmajor=dev>>9;
			devminor=dev&0x1ff;
			rdevmajor=rdev>>9;
			rdevminor=rdev&0x1ff;

			pad=filesize&1;
		}
		else [XADException raiseIllegalDataException];

		if([namedata length]==10&&memcmp([namedata bytes],"TRAILER!!!",10)==0) break;

		off_t pos=[fh offsetInFile];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithInt:devmajor],@"CpioDevMajor",
			[NSNumber numberWithInt:devminor],@"CpioDevMinor",
			[NSNumber numberWithInt:ino],@"CpioIno",
			[NSNumber numberWithInt:mode],XADPosixPermissionsKey,
			[NSNumber numberWithInt:uid],XADPosixUserKey,
			[NSNumber numberWithInt:gid],XADPosixGroupKey,
			[NSNumber numberWithInt:nlink],@"CpioNlink",
			[self XADPathWithData:namedata separators:XADUnixPathSeparator],XADFileNameKey,
			[NSDate dateWithTimeIntervalSince1970:mtime],XADLastModificationDateKey,
			[NSNumber numberWithLongLong:filesize],XADFileSizeKey,
			[NSNumber numberWithLongLong:filesize+pad],XADCompressedSizeKey,
			[NSNumber numberWithLongLong:filesize],XADDataLengthKey,
			[NSNumber numberWithLongLong:pos],XADDataOffsetKey,
		nil];

		int type=mode&0xf000;

		if(type==0x4000)
		{
			[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
		}

		if(type==0x2000||type==0x6000)
		{
			[dict setObject:[NSNumber numberWithInt:rdevmajor] forKey:XADDeviceMajorKey];
			[dict setObject:[NSNumber numberWithInt:rdevminor] forKey:XADDeviceMinorKey];
		}

		if(haschecksum)
		if(type==0x8000)
		{
			[dict setObject:[NSNumber numberWithInt:checksum] forKey:@"CpioChecksum"];
		}

		[self addEntryWithDictionary:dict];

		[fh seekToFileOffset:pos+filesize+pad];
	}
}

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];

	if(checksum)
	{
		NSNumber *check=[dict objectForKey:@"CpioChecksum"];
		if(check) handle=[[[XADChecksumHandle alloc] initWithHandle:handle
		length:[[dict objectForKey:XADDataLengthKey] longLongValue]
		correctChecksum:[check intValue] mask:0xffffffff] autorelease];
	}

	return handle;
}

-(NSString *)formatName { return @"Cpio"; }

@end


