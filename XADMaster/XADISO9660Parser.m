#import "XADISO9660Parser.h"
#import "XADPaddedBlockHandle.h"
#import "NSDateXAD.h"

@implementation XADISO9660Parser

//+(int)requiredHeaderSize { return 2448*16+2048; }
+(int)requiredHeaderSize { return 0x80000; }

static BOOL IsISO9660PrimaryVolumeDescriptor(const uint8_t *bytes,int length,int offset)
{
	if(offset+2048>length) return NO;

	const uint8_t *block=bytes+offset;
	if(block[0]!=1) return NO;
	if(block[1]!='C') return NO;
	if(block[2]!='D') return NO;
	if(block[3]!='0') return NO;
	if(block[4]!='0') return NO;
	if(block[5]!='1') return NO;
	if(block[6]!=1) return NO;

	return YES;
}

static BOOL IsHighSierraPrimaryVolumeDescriptor(const uint8_t *bytes,int length,int offset)
{
	if(offset+2048>length) return NO;

	const uint8_t *block=bytes+offset;
	if(block[8]!=1) return NO;
	if(block[9]!='C') return NO;
	if(block[10]!='D') return NO;
	if(block[11]!='R') return NO;
	if(block[12]!='O') return NO;
	if(block[13]!='M') return NO;
	if(block[14]!=1) return NO;

	return YES;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data
name:(NSString *)name propertiesToAdd:(NSMutableDictionary *)props
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	// Scan for a primary volume descriptor to find the start of the image.
	for(int i=0x8000;i<length-2048-6;i++)
	{
		if(IsISO9660PrimaryVolumeDescriptor(bytes,length,i))
		{
			// Then, scan for the volume descriptor on the next block to find the block size.
			for(int j=2048;j<2448;j++)
			{
				if(i+j+6>length) break;
				if(memcmp(&bytes[i+j+1],"CD001",5)==0)
				{
					[props setObject:[NSNumber numberWithInt:j] forKey:@"ISO9660ImageBlockSize"];
					[props setObject:[NSNumber numberWithInt:i-j*16] forKey:@"ISO9660ImageBlockOffset"];
					return YES;
				}
			}
		}

		if(IsHighSierraPrimaryVolumeDescriptor(bytes,length,i))
		{
			// Then, scan for the volume descriptor on the next block to find the block size.
			for(int j=2048;j<2448;j++)
			{
				if(i+j+6>length) break;
				if(memcmp(&bytes[i+j+9],"CDROM",5)==0)
				{
					[props setObject:[NSNumber numberWithBool:YES] forKey:@"ISO9660ImageIsHighSierra"];
					[props setObject:[NSNumber numberWithInt:j] forKey:@"ISO9660ImageBlockSize"];
					[props setObject:[NSNumber numberWithInt:i-j*16] forKey:@"ISO9660ImageBlockOffset"];
					return YES;
				}
			}
		}
	}

	return NO;
}




-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if((self=[super initWithHandle:handle name:name]))
	{
		fh=nil;
		isjoliet=NO;
		ishighsierra=NO;
	}
	return self;
}

-(void)dealloc;
{
	[fh release];
	[super dealloc];
}




-(void)parse
{
	NSDictionary *props=[self properties];
	int blockoffset=[[props objectForKey:@"ISO9660ImageBlockOffset"] intValue];
	blocksize=[[props objectForKey:@"ISO9660ImageBlockSize"] intValue];
	ishighsierra=[[props objectForKey:@"ISO9660ImageIsHighSierra"] boolValue];

	if(blocksize!=2048)
	{
		fh=[[XADPaddedBlockHandle alloc] initWithHandle:[self handle]
		startOffset:blockoffset logicalBlockSize:2048 physicalBlockSize:blocksize];
	}
	else if(blockoffset!=0)
	{
		fh=[[[self handle] nonCopiedSubHandleToEndOfFileFrom:blockoffset] retain];
	}
	else
	{
		fh=[[self handle] retain];
	}

	if(!ishighsierra)
	for(int block=17;;block++)
	{
		[fh seekToFileOffset:block*2048];

		int type=[fh readUInt8];

		uint8_t identifier[5];
		[fh readBytes:5 toBuffer:identifier];
		if(memcmp(identifier,"CD001",5)!=0) break;

		if(type==2)
		{
			int version=[fh readUInt8];
			if(version!=1) continue;

			int flags=[fh readUInt8];
			if(flags!=0) continue;

			[fh skipBytes:80];

			int esc1=[fh readUInt8];
			int esc2=[fh readUInt8];
			int esc3=[fh readUInt8];
			if(esc1!=0x25) continue;
			if(esc2!=0x2f) continue;
			if(esc3!=0x40 && esc3!=0x43 && esc3!=0x45) continue;

			isjoliet=YES;
			[self setObject:[NSNumber numberWithBool:YES] forPropertyKey:@"ISO9660IsJoliet"];

			[self parseVolumeDescriptorAtBlock:block];
			return;
		}
		else if(type==255)
		{
			break;
		}
	}

	[self parseVolumeDescriptorAtBlock:16];
}

-(void)parseVolumeDescriptorAtBlock:(uint32_t)block
{
	XADString *system,*volume;
	uint32_t volumesetsize,volumesequencenumber,logicalblocksize;
	uint32_t rootblock,rootlength;

	XADString *volumeset,*publisher,*datapreparer,*application;
	XADString *copyrightfile,*abstractfile,*bibliographicfile;

	NSDate *creation,*modification,*expiration,*effective;

	if(!ishighsierra)
	{
		[fh seekToFileOffset:block*2048+8];

		system=[self readStringOfLength:32]; 
		volume=[self readStringOfLength:32]; 
		[fh skipBytes:8];
		/*uint32_t volumespacesize=*/[fh readUInt32LE];
		[fh skipBytes:36];
		volumesetsize=[fh readUInt16LE];
		[fh skipBytes:2];
		volumesequencenumber=[fh readUInt16LE];
		[fh skipBytes:2];
		logicalblocksize=[fh readUInt16LE];
		[fh skipBytes:2];
		/*uint32_t pathtablesize=*/[fh readUInt32LE];
		[fh skipBytes:4];
		/*uint32_t pathtablelocation=*/[fh readUInt32LE];
		/*uint32_t optionalpathtablelocation=*/[fh readUInt32LE];
		[fh skipBytes:8];

		// Root directory record
		[fh skipBytes:2];
		rootblock=[fh readUInt32LE];
		[fh skipBytes:4];
		rootlength=[fh readUInt32LE];
		[fh skipBytes:20];

		volumeset=[self readStringOfLength:128]; 
		publisher=[self readStringOfLength:128]; 
		datapreparer=[self readStringOfLength:128];
		application=[self readStringOfLength:128];
		copyrightfile=[self readStringOfLength:37];
		abstractfile=[self readStringOfLength:37];
		bibliographicfile=[self readStringOfLength:37];

		creation=[self readLongDateAndTime];
		modification=[self readLongDateAndTime];
		expiration=[self readLongDateAndTime];
		effective=[self readLongDateAndTime];
	}
	else
	{
		[fh seekToFileOffset:block*2048+16];

		system=[self readStringOfLength:32]; 
		volume=[self readStringOfLength:32]; 
		[fh skipBytes:8];
		/*uint32_t volumespacesize=*/[fh readUInt32LE];
		[fh skipBytes:36];
		volumesetsize=[fh readUInt16LE];
		[fh skipBytes:2];
		volumesequencenumber=[fh readUInt16LE];
		[fh skipBytes:2];
		logicalblocksize=[fh readUInt16LE];
		[fh skipBytes:42];

		// Root directory record
		[fh skipBytes:2];
		rootblock=[fh readUInt32LE];
		[fh skipBytes:4];
		rootlength=[fh readUInt32LE];
		[fh skipBytes:20];

		volumeset=[self readStringOfLength:128]; 
		publisher=[self readStringOfLength:128]; 
		datapreparer=[self readStringOfLength:128];
		application=[self readStringOfLength:128];
		[fh skipBytes:192]; // Not sure what this part is.
		copyrightfile=nil;
		abstractfile=nil;
		bibliographicfile=nil;

		creation=[self readLongDateAndTime];
		modification=[self readLongDateAndTime];
		expiration=[self readLongDateAndTime];
		effective=[self readLongDateAndTime];
	}

	if(logicalblocksize!=2048) [XADException raiseIllegalDataException];

	if(volume) [self setObject:volume forPropertyKey:XADDiskLabelKey];
	if(creation) [self setObject:creation forPropertyKey:XADCreationDateKey];
	if(modification) [self setObject:modification forPropertyKey:XADLastModificationDateKey];

	if(system) [self setObject:system forPropertyKey:@"ISO9660SystemIndentifier"];
	if(volume) [self setObject:volume forPropertyKey:@"ISO9660VolumeIndentifier"];
	if(volumeset) [self setObject:volumeset forPropertyKey:@"ISO9660VolumeSetIndentifier"];
	if(publisher) [self setObject:publisher forPropertyKey:@"ISO9660PublisherIndentifier"];
	if(datapreparer) [self setObject:datapreparer forPropertyKey:@"ISO9660DataPreparerIndentifier"];
	if(application) [self setObject:application forPropertyKey:@"ISO9660ApplicationIndentifier"];
	if(copyrightfile) [self setObject:copyrightfile forPropertyKey:@"ISO9660CopyrightFileIndentifier"];
	if(abstractfile) [self setObject:abstractfile forPropertyKey:@"ISO9660AbstractFileIndentifier"];
	if(bibliographicfile) [self setObject:bibliographicfile forPropertyKey:@"ISO9660BibliographicFileIndentifier"];

	if(creation) [self setObject:creation forPropertyKey:@"ISO9660CreationDateAndTime"];
	if(modification) [self setObject:modification forPropertyKey:@"ISO9660ModificationDateAndTime"];
	if(expiration) [self setObject:expiration forPropertyKey:@"ISO9660ExpirationDateAndTime"];
	if(effective) [self setObject:effective forPropertyKey:@"ISO9660EffectiveDateAndTime"];

	[self setObject:[NSNumber numberWithInt:volumesetsize] forPropertyKey:@"ISO9660VolumeSetSize"];
	[self setObject:[NSNumber numberWithInt:volumesequencenumber] forPropertyKey:@"ISO9660VolumeSequenceNumber"];

	[self parseDirectoryWithPath:[self XADPath] atBlock:rootblock length:rootlength];
}

#define TypeID(a,b) (((a)<<8)|(b))

-(void)parseDirectoryWithPath:(XADPath *)path atBlock:(uint32_t)block
length:(uint32_t)length
{
	off_t extentstart=block*2048;
	off_t extentend=extentstart+length;

	[fh seekToFileOffset:extentstart];

	int selflength=[fh readUInt8];
	[fh skipBytes:selflength-1];

	int parentlength=[fh readUInt8];
	[fh skipBytes:parentlength-1];

	while([fh offsetInFile]<extentend)
	{
		off_t startpos=[fh offsetInFile];

		int recordlength=[fh readUInt8];
		off_t endpos=startpos+recordlength;

		// If the record length is 0, we need to skip to the next block.
		if(recordlength==0)
		{
			int block=startpos/2048;
			[fh seekToFileOffset:(block+1)*2048];
			continue;
		}

		/*int extlength=*/[fh readUInt8];

		uint32_t location=[fh readUInt32LE];
		[fh skipBytes:4];
		uint32_t length=[fh readUInt32LE];
		[fh skipBytes:4];

		NSDate *date=[self readShortDateAndTime];
		int flags=[fh readUInt8];
		if(ishighsierra) [fh skipBytes:1];

		int unitsize=[fh readUInt8];
		int gapsize=[fh readUInt8];
		int volumesequencenumber=[fh readUInt16LE];
		[fh skipBytes:2];

		if(flags&0x80) [XADException raiseNotSupportedException];
		if(unitsize!=0) [XADException raiseNotSupportedException];
		if(gapsize!=0) [XADException raiseNotSupportedException];

		int namelength=[fh readUInt8];
		uint8_t name[namelength];
		[fh readBytes:namelength toBuffer:name];
		if((namelength&1)==0) [fh skipBytes:1];

		XADString *filename;
		if(isjoliet)
		{
			NSMutableString *str=[NSMutableString stringWithCapacity:namelength/2];
			for(int i=0;i+2<=namelength;i+=2)
			{
				unichar c=CSUInt16BE(&name[i]);
				[str appendFormat:@"%C",c];
			}

			if([str hasSuffix:@";1"])
			[str deleteCharactersInRange:NSMakeRange(namelength/2-2,2)];

			filename=[self XADStringWithString:str];
		}
		else
		{
			if(namelength>=2)
			if(name[namelength-2]==';')
			if(name[namelength-1]=='1')
			namelength-=2;

			filename=[self XADStringWithBytes:name length:namelength];
		}

		XADPath *currpath=[path pathByAppendingXADStringComponent:filename];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			currpath,XADFileNameKey,
			date,XADLastModificationDateKey,
			[NSNumber numberWithUnsignedInt:length],XADFileSizeKey,
			[NSNumber numberWithUnsignedInt:((length+2047)/2048)*blocksize],XADCompressedSizeKey,
			[NSNumber numberWithUnsignedInt:location],@"ISO9660LocationOfExtent",
			[NSNumber numberWithUnsignedInt:flags],@"ISO9660FileFlags",
			[NSNumber numberWithUnsignedInt:unitsize],@"ISO9660FileUnitSize",
			[NSNumber numberWithUnsignedInt:gapsize],@"ISO9660InterleaveGapSize",
			[NSNumber numberWithUnsignedInt:volumesequencenumber],@"ISO9660VolumeSequenceNumber",
		nil];

		if(flags&0x01) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsHiddenKey];
		if(flags&0x02) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
		if(flags&0x04) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

		int systemlength=recordlength-33-namelength-((namelength&1)^1);
		if(systemlength)
		{
			NSMutableData *namedata=nil;
			NSMutableData *linkdata=nil;
			NSMutableData *commentdata=nil;

			off_t nextoffset=[fh offsetInFile];
			int nextlength=systemlength;

			while(nextlength)
			{
				off_t curroffset=nextoffset;
				int currlength=nextlength;
				nextlength=0;
				nextoffset=0;

				uint8_t system[currlength];
				[fh seekToFileOffset:curroffset];
				[fh readBytes:currlength toBuffer:system];

//NSLog(@"%qd %d %@",curroffset,currlength,[NSData dataWithBytes:system length:currlength]);

				int pos=0;
				while(pos+4<=currlength)
				{
					int type=CSUInt16BE(&system[pos]);
					int length=system[pos+2];

					if(pos+length>currlength) break;
					if(length==0) break; // Sanity check.

//NSLog(@"%c%c: %@",type>>8,type&0xff,[NSData dataWithBytes:&system[pos+3] length:length-3]);

					switch(type)
					{
						case TypeID('A','A'):
						case TypeID('A','B'):
						{
							if(length!=14) break;
							if(type==TypeID('A','A') && system[pos+3]!=2) break;
							if(type==TypeID('A','B') && system[pos+3]!=6) break;

							uint32_t filetype=CSUInt32BE(&system[pos+4]);
							uint32_t filecreator=CSUInt32BE(&system[pos+8]);
							int finderflags=CSUInt16BE(&system[pos+12]);

							if(filetype) [dict setObject:[NSNumber numberWithUnsignedInt:filetype] forKey:XADFileTypeKey];
							if(filecreator) [dict setObject:[NSNumber numberWithUnsignedInt:filecreator] forKey:XADFileCreatorKey];
							if(finderflags) [dict setObject:[NSNumber numberWithInt:finderflags] forKey:XADFinderFlagsKey];
						}
						break;

						case TypeID('P','X'):
						{
							if(length!=44) break;
							if(system[pos+3]!=1) break;

							uint32_t mode=CSUInt32LE(&system[pos+4]);
							uint32_t user=CSUInt32LE(&system[pos+20]);
							uint32_t group=CSUInt32LE(&system[pos+28]);

							[dict setObject:[NSNumber numberWithUnsignedInt:mode] forKey:XADPosixPermissionsKey];
							[dict setObject:[NSNumber numberWithUnsignedInt:user] forKey:XADPosixUserKey];
							[dict setObject:[NSNumber numberWithUnsignedInt:group] forKey:XADPosixGroupKey];
						}
						break;

						case TypeID('P','N'):
						{
							if(length!=20) break;
							if(system[pos+3]!=1) break;

							uint32_t devmajor=CSUInt32LE(&system[pos+4]);
							uint32_t devminor=CSUInt32LE(&system[pos+12]);

							[dict setObject:[NSNumber numberWithUnsignedInt:devmajor] forKey:XADDeviceMajorKey];
							[dict setObject:[NSNumber numberWithUnsignedInt:devminor] forKey:XADDeviceMinorKey];
						}
						break;

						case TypeID('S','L'):
						{
							if(length<6) break;
							if(system[pos+3]!=1) break;

							BOOL continuefromlast=NO;
							int offs=5;
							while(offs+2<=length)
							{
								int flags=system[pos+offs];
								int complen=system[pos+offs+1];
								if(offs+complen>length) break;

								if(flags&0x08)
								{
									linkdata=[NSMutableData dataWithBytes:"/" length:1];
									continuefromlast=YES;
								}
								else
								{
									const void *appendbytes;
									int appendlength;
									if(flags&0x02)
									{
										appendbytes=".";
										appendlength=1;
									}
									else if(flags&0x04)
									{
										appendbytes="..";
										appendlength=2;
									}
									else
									{
										appendbytes=&system[pos+offs+2];
										appendlength=complen;
									}

									if(!linkdata)
									{
										linkdata=[NSMutableData dataWithBytes:appendbytes length:appendlength];
									}
									else
									{
										if(!continuefromlast) [linkdata appendBytes:"/" length:1];
										[linkdata appendBytes:appendbytes length:appendlength];
									}
									continuefromlast=(flags&0x01)?YES:NO;
								}

								pos+=2+complen;
							}
						}
						break;

						case TypeID('N','M'):
						{
							if(length<6) break;
							if(system[pos+3]!=1) break;

							if(!namedata) namedata=[NSMutableData dataWithBytes:&system[pos+5] length:length-5];
							else [namedata appendBytes:&system[pos+5] length:length-5];
						}
						break;

						case TypeID('T','F'):
						{
							if(length<5) break;
							if(system[pos+3]!=1) break;

							int flags=system[pos+4];
							int offs=5;
							int datelen=(flags&0x80)?17:7;

							if(flags&0x01)
							{
								if(offs+datelen>length) break;
								NSDate *date=[self parseDateAndTimeWithBytes:&system[pos+offs] long:flags&0x80];
								[dict setObject:date forKey:XADCreationDateKey];
								offs+=datelen;
							}

							if(flags&0x02)
							{
								if(offs+datelen>length) break;
								NSDate *date=[self parseDateAndTimeWithBytes:&system[pos+offs] long:flags&0x80];
								[dict setObject:date forKey:XADLastModificationDateKey];
								offs+=datelen;
							}

							if(flags&0x04)
							{
								if(offs+datelen>length) break;
								NSDate *date=[self parseDateAndTimeWithBytes:&system[pos+offs] long:flags&0x80];
								[dict setObject:date forKey:XADLastAccessDateKey];
								offs+=datelen;
							}

							if(flags&0x08)
							{
								if(offs+datelen>length) break;
								NSDate *date=[self parseDateAndTimeWithBytes:&system[pos+offs] long:flags&0x80];
								[dict setObject:date forKey:XADLastAttributeChangeDateKey];
								offs+=datelen;
							}

							if(flags&0x10)
							{
								if(offs+datelen>length) break;
								NSDate *date=[self parseDateAndTimeWithBytes:&system[pos+offs] long:flags&0x80];
								[dict setObject:date forKey:@"ISO9660BackupDate"];
								offs+=datelen;
							}

							if(flags&0x20)
							{
								if(offs+datelen>length) break;
								NSDate *date=[self parseDateAndTimeWithBytes:&system[pos+offs] long:flags&0x80];
								[dict setObject:date forKey:@"ISO9660ExpirationDate"];
								offs+=datelen;
							}

							if(flags&0x40)
							{
								if(offs+datelen>length) break;
								NSDate *date=[self parseDateAndTimeWithBytes:&system[pos+offs] long:flags&0x80];
								[dict setObject:date forKey:@"ISO9660EffectiveDate"];
							}
						}
						break;

						case TypeID('A','S'):
						{
							if(length<6) break;
							if(system[pos+3]!=1) break;

							int flags=system[pos+4];
							int commentoffs=5;

							if(flags&0x01)
							{
								if(length<9) break;
								uint32_t protection=CSUInt32BE(&system[pos+5]);
								[dict setObject:[NSNumber numberWithUnsignedInt:protection] forKey:XADAmigaProtectionBitsKey];
								commentoffs=9;
							}

							if(length>commentoffs)
							{
								if(!commentdata) commentdata=[NSMutableData dataWithBytes:&system[pos+commentoffs] length:length-commentoffs];
								else [commentdata appendBytes:&system[pos+commentoffs] length:length-commentoffs];
							}
						}
						break;

						case TypeID('C','E'):
						{
							if(length!=28) break;
							if(system[pos+3]!=1) break;

							uint32_t block=CSUInt32LE(&system[pos+4]);
							uint32_t offset=CSUInt32LE(&system[pos+12]);
							nextoffset=block*2048+offset;

							nextlength=CSUInt32LE(&system[pos+20]);
						}
						break;

						case TypeID('S','T'):
						{
							if(length!=4) break;
							if(system[pos+3]!=1) break;
							goto exitloop;
						}
						break;
					}

					pos+=length;

					// Deal with padding, which apparently happens at random!
					if(pos<currlength && (length&1) && system[pos]==0) pos++;
				}
				exitloop:
				(void)0;
			}

			if(namedata)
			{
				XADString *correctfilename=[self XADStringWithData:namedata];
				currpath=[path pathByAppendingXADStringComponent:correctfilename];
				[dict setObject:filename forKey:@"ISO9660OriginalFileName"];
				[dict setObject:currpath forKey:XADFileNameKey];
			}

			if(linkdata)
			{
				XADString *linkdest=[self XADStringWithData:linkdata];
				[dict setObject:linkdest forKey:XADLinkDestinationKey];
			}
		}

		[self addEntryWithDictionary:dict];

		if(flags&0x02)
		[self parseDirectoryWithPath:currpath atBlock:location length:length];

		[fh seekToFileOffset:endpos];
	}
}




-(XADString *)readStringOfLength:(int)length
{
	uint8_t buffer[length];
	[fh readBytes:length toBuffer:buffer];

	if(isjoliet)
	{
		if(length&1) length--;

		while(length>0 && (CSUInt16BE(&buffer[length-2])==0x0020 ||
		CSUInt16BE(&buffer[length-2])==0x0000)) length-=2;

		if(!length) return nil;

		NSMutableString *str=[NSMutableString stringWithCapacity:length/2];
		for(int i=0;i+2<=length;i+=2) [str appendFormat:@"%C",CSUInt16BE(&buffer[i])];
		return [self XADStringWithString:str];
	}
	else
	{
		while(length>0 && (buffer[length-1]==0x20 || buffer[length-1]==0x00))
		length--;

		if(!length) return nil;

		return [self XADStringWithBytes:buffer length:length];
	}
}

-(NSDate *)readLongDateAndTime
{
	uint8_t buffer[17];
	if(ishighsierra) [fh readBytes:16 toBuffer:buffer];
	else [fh readBytes:16 toBuffer:buffer];
	return [self parseLongDateAndTimeWithBytes:buffer];
}

-(NSDate *)readShortDateAndTime
{
	uint8_t buffer[7];
	if(ishighsierra) [fh readBytes:6 toBuffer:buffer];
	else [fh readBytes:7 toBuffer:buffer];
	return [self parseShortDateAndTimeWithBytes:buffer];
}

-(NSDate *)parseDateAndTimeWithBytes:(const uint8_t *)buffer long:(BOOL)islong
{
	if(islong) return [self parseLongDateAndTimeWithBytes:buffer];
	else return [self parseShortDateAndTimeWithBytes:buffer];
}

-(NSDate *)parseLongDateAndTimeWithBytes:(const uint8_t *)buffer
{
	if(memcmp(buffer,"0000000000000000",16)==0 && buffer[16]==0) return nil;
	for(int i=0;i<16;i++) if(buffer[i]<'0'||buffer[i]>'9') return nil;

	int year=(buffer[0]-'0')*1000+(buffer[1]-'0')*100+(buffer[2]-'0')*10+(buffer[3]-'0');
	int month=(buffer[4]-'0')*10+(buffer[5]-'0');
	int day=(buffer[6]-'0')*10+(buffer[7]-'0');
	int hour=(buffer[8]-'0')*10+(buffer[9]-'0');
	int minute=(buffer[10]-'0')*10+(buffer[11]-'0');
	int second=(buffer[12]-'0')*10+(buffer[13]-'0');
	//int hundreths=(buffer[14]-'0')*10+(buffer[15]-'0');

	NSTimeZone *tz=nil;
	if(!ishighsierra)
	{
		int offset=(int8_t)buffer[16];
		tz=[NSTimeZone timeZoneForSecondsFromGMT:offset*15*60];
	}

	return [NSDate XADDateWithYear:year month:month day:day
	hour:hour minute:minute second:second timeZone:tz];
}

-(NSDate *)parseShortDateAndTimeWithBytes:(const uint8_t *)buffer
{
	int year=buffer[0]+1900;
	int month=buffer[1];
	int day=buffer[2];
	int hour=buffer[3];
	int minute=buffer[4];
	int second=buffer[5];

	NSTimeZone *tz=nil;
	if(!ishighsierra)
	{
		int offset=(int8_t)buffer[6];
		tz=[NSTimeZone timeZoneForSecondsFromGMT:offset*15*60];
	}

	return [NSDate XADDateWithYear:year month:month day:day
	hour:hour minute:minute second:second timeZone:tz];
}




-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	uint32_t startblock=[[dict objectForKey:@"ISO9660LocationOfExtent"] unsignedIntValue];
	uint32_t length=[[dict objectForKey:XADFileSizeKey] unsignedIntValue];

	return [fh nonCopiedSubHandleFrom:startblock*2048 length:length];
}

-(NSString *)formatName { return @"ISO 9660"; }

@end
