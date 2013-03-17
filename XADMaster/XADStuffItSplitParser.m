#import "XADStuffItSplitParser.h"
#import "CSMultiHandle.h"
#import "CSFileHandle.h"
#import "NSDateXAD.h"
#import "XADPlatform.h"

@implementation XADStuffItSplitParser

+(int)requiredHeaderSize { return 100; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<100) return NO;
	if(bytes[0]!=0xb0) return NO;
	if(bytes[1]!=0x56) return NO;
	if(bytes[2]!=0x00) return NO; // Assume there are less than 256 parts.
	if(bytes[4]==0) return NO;
	if(bytes[4]>63) return NO;
	for(int i=0;i<bytes[4];i++) if(bytes[5+i]==0) return NO;

	return YES;
}

+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];

	NSString *basename=[[name lastPathComponent] stringByDeletingPathExtension];

	NSString *dirname=[name stringByDeletingLastPathComponent];
	if(!dirname) dirname=@".";

	NSArray *dircontents=[XADPlatform contentsOfDirectoryAtPath:dirname];
	if(!dircontents) return [NSArray array];

	NSString *parts[256]={nil};

	NSEnumerator *enumerator=[dircontents objectEnumerator];
	NSString *filename;
	while((filename=[enumerator nextObject]))
	{
		if(![filename hasPrefix:basename]) continue;

		NSString *fullpath=[dirname stringByAppendingPathComponent:filename];
		@try
		{
			CSFileHandle *filehandle=[CSFileHandle fileHandleForReadingAtPath:fullpath];
			uint8_t header[100];
			int actual=[filehandle readAtMost:sizeof(header) toBuffer:header];
			if(actual<sizeof(header)) continue;
			if(header[0]!=0xb0) continue;
			if(header[1]!=0x56) continue;
			if(header[2]!=0x00) continue;
			if(header[4]!=bytes[4]) continue;
			if(memcmp(&header[5],&bytes[5],header[4])!=0) continue;
			if(memcmp(&header[68],&bytes[68],26)!=0) continue;

			int partnum=header[3];
			parts[partnum]=fullpath;

			[filehandle close];
		}
		@catch(id e) {}
	}

	NSMutableArray *volumes=[NSMutableArray array];
	for(int i=1;i<256;i++)
	{
		if(!parts[i]) break;
		[volumes addObject:parts[i]];
	}

	return volumes;
}



-(void)parse
{
	CSHandle *fh=[self handle];

	NSArray *handles=[self volumes];
	if(!handles) handles=[NSArray arrayWithObject:fh];

	XADSkipHandle *sh=[self skipHandle];
	off_t curroffset=0;

	NSEnumerator *enumerator=[handles objectEnumerator];
	CSHandle *handle;
	while((handle=[enumerator nextObject]))
	{
		[sh addSkipFrom:curroffset length:100];
		off_t volumesize=[handle fileSize];
		curroffset+=volumesize;
	}

	[fh skipBytes:4];
	int namelength=[fh readUInt8];
	NSData *namedata=[fh readDataOfLength:namelength];

	[fh seekToFileOffset:68];
	uint32_t type=[fh readUInt32BE];
	uint32_t creator=[fh readUInt32BE];
	int finderflags=[fh readUInt16BE];
	uint32_t creation=[fh readUInt32BE];
	uint32_t modification=[fh readUInt32BE];
	uint32_t rsrclength=[fh readUInt32BE];
	uint32_t datalength=[fh readUInt32BE];

	BOOL isarchive=NO;
	const uint8_t *namebytes=[namedata bytes];

	if(namelength>4)
	if(namebytes[namelength-4]=='.')
	if(namebytes[namelength-3]=='s'||namebytes[namelength-3]=='S')
	if(namebytes[namelength-2]=='i'||namebytes[namelength-2]=='I')
	if(namebytes[namelength-1]=='t'||namebytes[namelength-1]=='T')
	isarchive=YES;

	if(namelength>4)
	if(namebytes[namelength-4]=='.')
	if(namebytes[namelength-3]=='s'||namebytes[namelength-3]=='S')
	if(namebytes[namelength-2]=='e'||namebytes[namelength-2]=='E')
	if(namebytes[namelength-1]=='a'||namebytes[namelength-1]=='A')
	isarchive=YES;

	if(rsrclength)
	{
		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[self XADPathWithData:namedata separators:XADNoPathSeparator],XADFileNameKey,
			[NSNumber numberWithLongLong:rsrclength],XADFileSizeKey,
			[NSNumber numberWithLongLong:curroffset*rsrclength/(datalength+rsrclength)],XADCompressedSizeKey,
			[NSNumber numberWithLongLong:0],XADSkipOffsetKey,
			[NSNumber numberWithLongLong:rsrclength],XADSkipLengthKey,
			[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
			[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
			[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
			[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
			[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
			[NSNumber numberWithBool:YES],XADIsResourceForkKey,
		nil];

		if(isarchive) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

		[self addEntryWithDictionary:dict];
	}

	if(datalength || !rsrclength)
	{
		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[self XADPathWithData:namedata separators:XADNoPathSeparator],XADFileNameKey,
			[NSNumber numberWithLongLong:datalength],XADFileSizeKey,
			[NSNumber numberWithLongLong:curroffset*datalength/(datalength+rsrclength)],XADCompressedSizeKey,
			[NSNumber numberWithLongLong:rsrclength],XADSkipOffsetKey,
			[NSNumber numberWithLongLong:datalength],XADSkipLengthKey,
			[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
			[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
			[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
			[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
			[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
		nil];

		if(isarchive) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

		[self addEntryWithDictionary:dict];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	return handle;
}

-(NSString *)formatName { return @"StuffIt split file"; }

@end
