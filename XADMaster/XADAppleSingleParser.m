#import "XADAppleSingleParser.h"
#import "XADAppleDouble.h"
#import "NSDateXAD.h"

@implementation XADAppleSingleParser

+(int)requiredHeaderSize
{
	return 8;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<8) return NO;
	if(CSUInt32BE(&bytes[0])!=0x00051600 && CSUInt32BE(&bytes[0])!=0x00051607 &&
	CSUInt32BE(&bytes[0])!=0x00160500 && CSUInt32BE(&bytes[0])!=0x07160500) return NO;
	if(CSUInt32BE(&bytes[4])!=0x00020000 && CSUInt32BE(&bytes[4])!=0x00000200) return NO;
	return YES;
}

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *fh=[self handle];

	uint32_t magic=[fh readUInt32BE];

	BOOL bigendian;
	if(magic==0x00051600 || magic==0x00051607) bigendian=YES;
	else if(magic==0x00160500 || magic==0x07160500) bigendian=NO;
	else return;

	[fh skipBytes:20];

	int num=[fh readUInt16InBigEndianOrder:bigendian];

	uint32_t dataoffs=0,datalen=0;
	uint32_t rsrcoffs=0,rsrclen=0;

	NSMutableDictionary *shared=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithString:[self name]],XADFileNameKey,
	nil];

	for(int i=0;i<num;i++)
	{
		uint32_t entryid=[fh readUInt32InBigEndianOrder:bigendian];
		uint32_t entryoffs=[fh readUInt32InBigEndianOrder:bigendian];
		uint32_t entrylen=[fh readUInt32InBigEndianOrder:bigendian];

		off_t offs=[fh offsetInFile];

		switch(entryid)
		{
			case 1: // Data fork
				dataoffs=entryoffs;
				datalen=entrylen;
			break;

			case 2: // Resource fork
				rsrcoffs=entryoffs;
				rsrclen=entrylen;
			break;

			case 3: // Name
			{
				[fh seekToFileOffset:entryoffs];

				NSData *data=[fh readDataOfLength:entrylen];
				XADPath *path=[self XADPathWithData:data separators:XADNoPathSeparator];
				[shared setObject:path forKey:XADFileNameKey];
			}
			break;

			case 4: // Comment
			{
				[fh seekToFileOffset:entryoffs];

				NSData *data=[fh readDataOfLength:entrylen];
				XADString *comment=[self XADStringWithData:data];
				[shared setObject:comment forKey:XADCommentKey];
			}
			break;

			case 8: // Dates
			{
				[fh seekToFileOffset:entryoffs];

				// Why are some fields of variable endianness, but not these? Who knows!

				if(entrylen>=4)
				{
					uint32_t creation=[fh readUInt32BE]; 
					[shared setObject:[NSDate XADDateWithTimeIntervalSince2000:creation] forKey:XADCreationDateKey];
				}

				if(entrylen>=8)
				{
					uint32_t modification=[fh readUInt32BE];
					[shared setObject:[NSDate XADDateWithTimeIntervalSince2000:modification] forKey:XADLastModificationDateKey];
				}

				if(entrylen>=12)
				{
					uint32_t backup=[fh readUInt32BE];
					[shared setObject:[NSDate XADDateWithTimeIntervalSince2000:backup] forKey:XADLastBackupDateKey];
				}

				if(entrylen>=16)
				{
					uint32_t access=[fh readUInt32BE];
					[shared setObject:[NSDate XADDateWithTimeIntervalSince2000:access] forKey:XADLastAccessDateKey];
				}
			}
			break;

			case 9: // Finder info
			{
				[fh seekToFileOffset:entryoffs];

				NSMutableDictionary *extattrs=nil;

				NSData *finderinfo=nil;
				if(entrylen>32) finderinfo=[fh readDataOfLength:32];
				else finderinfo=[fh readDataOfLength:entrylen];

				// Add FinderInfo to extended attributes only if it is not empty.
				static const uint8_t zerobytes[32]={0x00};
				if(memcmp([finderinfo bytes],zerobytes,[finderinfo length])!=0)
				{
					extattrs=[NSMutableDictionary dictionaryWithObject:finderinfo
					forKey:@"com.apple.FinderInfo"];
				}

				// The FinderInfo struct is optionally followed by the extended attributes.
				if(entrylen>70)
				{
					if(!extattrs) extattrs=[NSMutableDictionary dictionary];
					[XADAppleDouble parseAppleDoubleExtendedAttributesWithHandle:fh intoDictionary:extattrs];
				}

				if(extattrs) [shared setObject:extattrs forKey:XADExtendedAttributesKey];
			}
			break;
		}

		[fh seekToFileOffset:offs];
	}

	if(dataoffs)
	{
		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithLongLong:datalen],XADFileSizeKey,
			[NSNumber numberWithLongLong:datalen],XADCompressedSizeKey,
			[NSNumber numberWithLongLong:dataoffs],XADDataOffsetKey,
			[NSNumber numberWithLongLong:datalen],XADDataLengthKey,
		nil];

		[dict addEntriesFromDictionary:shared];

		[self addEntryWithDictionary:dict];
	}

	if(rsrcoffs)
	{
		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithLongLong:rsrclen],XADFileSizeKey,
			[NSNumber numberWithLongLong:rsrclen],XADCompressedSizeKey,
			[NSNumber numberWithLongLong:rsrcoffs],XADDataOffsetKey,
			[NSNumber numberWithLongLong:rsrclen],XADDataLengthKey,
			[NSNumber numberWithBool:YES],XADIsResourceForkKey,
		nil];

		[dict addEntriesFromDictionary:shared];

		[self addEntryWithDictionary:dict];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self handleAtDataOffsetForDictionary:dict];
}

-(NSString *)formatName
{
	return @"AppleSingle";
}

@end

