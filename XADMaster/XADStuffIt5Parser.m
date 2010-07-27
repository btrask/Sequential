#import "XADStuffIt5Parser.h"
#import "XADException.h"
#import "NSDateXAD.h"

@implementation XADStuffIt5Parser

+(int)requiredHeaderSize { return 100; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const char *bytes=[data bytes];
	int length=[data length];

	if(length<100) return NO;

	const char *match="StuffIt (c)1997-\xFF\xFF\xFF\xFF Aladdin Systems, Inc., http://www.aladdinsys.com/StuffIt/\x0d\x0a";

    while(*match&&(*bytes==*match||*match=='\377')) { match++; bytes++; }

    if(!*match) return YES;
    else return NO;
}


/* header format 20 byte
  xadUINT8[80] header text
  xadUINT32     ???
  xadUINT32     total archive size
  xadUINT32     offset of some entry?
  xadUINT16     number of entries in root directory
  xadUINT32     offset of first entry in root directory
*/

/* archive block entry                          directory:
 0  xadUINT32     id = SIT5_ID                      <--
 4  xadUINT8     version                            <--
 5  xadUINT8     ???
 6  xadUINT16     header size                       <--
 8  xadUINT8     ??? (system ID?)
 9  xadUINT8     type                               <--
10  xadUINT32     creation date                     <--
14  xadUINT32     modification date                 <--
18  xadUINT32     offset of previous entry          <--
22  xadUINT32     offset of next entry              <--
26  xadUINT32     offset of directory entry         <--
30  xadUINT16     filename size                     <--
32  xadUINT16     header crc                        <--
34  xadUINT32     data file size                    offset of first entry
                                                    (can also be 0xffffffff, such entries seem to appear
													after each directory entry. meaning unclear.)
38  xadUINT32     data crunched size                size of complete directory
42  xadUINT16     data old crc16 (not with algo 15)
44  xadUINT16     ???
46  xadUINT8     data algorithm                     number of files high byte?
                none    ==  0
                fastest == 13
                max     == 15
47  xadUINT8     password data len                  number of files low byte
48  xadUINT8[..] password information
48+pwdlen            xadUINT8[..] filename          <--
48+pwdlen+namelen    xadUINT16     commentsize
48+pwdlen+namelen+2  xadUINT16     ????
48+pwdlen+namelen+4  xadUINT8[..] comment

  second block:
 0  xadUINT16     ??? (bitfield
                       bit 0: resource exists?)
 2  xadUINT16     ???
 4  xadUINT32     file type
 8  xadUINT32     file creator
12  xadUINT16     finder flags
14  xadUINT16     ???
16  xadUINT32     ??? (macintosh date variable - version 3)
20  xadUINT32     ???
24  xadUINT32     ???
28  xadUINT32     ???

32  xadUINT32     ??? (version 3 misses this one and following?)

36  xadUINT32     rsrc file size
40  xadUINT32     rsrc crunched size
44  xadUINT16     rsrc old crc16 (not with algo 15)
46  xadUINT16     ???
48  xadUINT8     rsrc algorithm

  followed by resource fork data
  followed by data fork data

  ! The header crc is CRC16 of header size with crc field cleared !
*/

#define SIT5_ID 0xA5A5A5A5

#define SIT5FLAGS_DIRECTORY     0x40
#define SIT5FLAGS_CRYPTED       0x20
#define SIT5FLAGS_RSRC_FORK     0x10

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *fh=[self handle];

	off_t base=[fh offsetInFile];

	[fh skipBytes:84];
	/*uint32_t totalsize=*/[fh readUInt32BE];
	/*uint32_t something=*/[fh readUInt32BE];
	int numfiles=[fh readUInt16BE];
	uint32_t firstoffs=[fh readUInt32BE];
	[fh seekToFileOffset:firstoffs+base];

	[self parseDirectoryWithNumberOfEntries:numfiles parent:[self XADPath]];
}

-(void)parseDirectoryWithNumberOfEntries:(int)numentries parent:(XADPath *)parent
{
	CSHandle *fh=[self handle];

	for(int i=0;i<numentries;i++)
	{
		if(![self shouldKeepParsing]) return;

		off_t offs=[fh offsetInFile];

		uint32_t headid=[fh readID];
		if(headid!=SIT5_ID) [XADException raiseDataFormatException];

		int version=[fh readUInt8];
		[fh skipBytes:1];
		int headersize=[fh readUInt16BE];
		off_t headerend=offs+headersize;
		[fh skipBytes:1];
		int flags=[fh readUInt8];
		uint32_t creationdate=[fh readUInt32BE];
		uint32_t modificationdate=[fh readUInt32BE];
		/*uint32_t prevoffs=*/[fh readUInt32BE];
		/*uint32_t nextoffs=*/[fh readUInt32BE];
		/*uint32_t diroffs=*/[fh readUInt32BE];
		int namelength=[fh readUInt16BE];
		/*int headercrc=*/[fh readUInt16BE];
		uint32_t datalength=[fh readUInt32BE];
		uint32_t datacomplen=[fh readUInt32BE];
		int datacrc=[fh readUInt16BE];
		[fh skipBytes:2];

		int datamethod,numfiles;
		if(flags&SIT5FLAGS_DIRECTORY)
		{
			numfiles=[fh readUInt16BE];

			if(datalength==0xffffffff) { numentries++; continue; }
			// Skip these entries, whatever they are.
			// They seem to appear after every directory entry.
		}
		else
		{
			datamethod=[fh readUInt8];
			int passlen=[fh readUInt8];
			[fh skipBytes:passlen];
		}

		NSData *namedata=[fh readDataOfLength:namelength];

		XADString *comment=nil;
		if([fh offsetInFile]<headerend)
		{
			int commentsize=[fh readUInt16BE];
			[fh skipBytes:2];
			comment=[self XADStringWithData:[fh readDataOfLength:commentsize]];
		}

		int something=[fh readUInt16BE];
		[fh skipBytes:2];
		uint32_t filetype=[fh readID];
		uint32_t filecreator=[fh readID];
		int finderflags=[fh readUInt16BE];

		if(version==1) [fh skipBytes:22];
		else [fh skipBytes:18];

		uint32_t resourcelength=0,resourcecomplen=0;
		int resourcecrc,resourcemethod;
		if(something&0x01)
		{
			resourcelength=[fh readUInt32BE];
			resourcecomplen=[fh readUInt32BE];
			resourcecrc=[fh readUInt16BE];
			[fh skipBytes:2];
			resourcemethod=[fh readUInt8];
			[fh skipBytes:1];
		}

		off_t datastart=[fh offsetInFile];

		XADPath *path=[parent pathByAppendingPathComponent:[self XADStringWithData:namedata]];

		if(flags&SIT5FLAGS_DIRECTORY)
		{
			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				path,XADFileNameKey,
				[NSDate XADDateWithTimeIntervalSince1904:modificationdate],XADLastModificationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:creationdate],XADCreationDateKey,
				[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
				[NSNumber numberWithBool:YES],XADIsDirectoryKey,
				[NSNumber numberWithInt:flags],@"StuffItFlags",
				comment,XADCommentKey,
			nil];

			[self addEntryWithDictionary:dict];
			[fh seekToFileOffset:datastart];
			[self parseDirectoryWithNumberOfEntries:numfiles parent:path];
		}
		else
		{
			BOOL hasresource=something&0x01;

			if(hasresource)
			{
				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					path,XADFileNameKey,
					[NSNumber numberWithUnsignedInt:resourcelength],XADFileSizeKey,
					[NSNumber numberWithUnsignedInt:resourcecomplen],XADCompressedSizeKey,
					[NSDate XADDateWithTimeIntervalSince1904:modificationdate],XADLastModificationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:creationdate],XADCreationDateKey,
					[NSNumber numberWithUnsignedInt:filetype],XADFileTypeKey,
					[NSNumber numberWithUnsignedInt:filecreator],XADFileCreatorKey,
					[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
					[NSNumber numberWithBool:YES],XADIsResourceForkKey,

					[NSNumber numberWithLongLong:datastart],XADDataOffsetKey,
					[NSNumber numberWithUnsignedInt:resourcecomplen],XADDataLengthKey,
					[NSNumber numberWithInt:resourcemethod],@"StuffItCompressionMethod",
					[NSNumber numberWithInt:resourcecrc],@"StuffItCRC16",
					[NSNumber numberWithInt:flags],@"StuffItFlags",
					comment,XADCommentKey,
				nil];

				XADString *compressionname=[self nameOfCompressionMethod:resourcemethod];
				if(compressionname) [dict setObject:compressionname forKey:XADCompressionNameKey];

				if(flags&SIT5FLAGS_CRYPTED) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];

				//if(datamethod!=0&&datamethod!=13&&datamethod!=15)
				//DebugFileSearched(ai, "Unknown or untested compression method %ld.",datam;

				[self addEntryWithDictionary:dict];
			}

			if(datalength||!hasresource)
			{
				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					path,XADFileNameKey,
					[NSNumber numberWithUnsignedInt:datalength],XADFileSizeKey,
					[NSNumber numberWithUnsignedInt:datacomplen],XADCompressedSizeKey,
					[NSDate XADDateWithTimeIntervalSince1904:modificationdate],XADLastModificationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:creationdate],XADCreationDateKey,
					[NSNumber numberWithUnsignedInt:filetype],XADFileTypeKey,
					[NSNumber numberWithUnsignedInt:filecreator],XADFileCreatorKey,
					[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,

					[NSNumber numberWithLongLong:datastart+resourcecomplen],XADDataOffsetKey,
					[NSNumber numberWithUnsignedInt:datacomplen],XADDataLengthKey,
					[NSNumber numberWithInt:datamethod],@"StuffItCompressionMethod",
					[NSNumber numberWithInt:datacrc],@"StuffItCRC16",
					[NSNumber numberWithInt:flags],@"StuffItFlags",
					comment,XADCommentKey,
				nil];

				XADString *compressionname=[self nameOfCompressionMethod:datamethod];
				if(compressionname) [dict setObject:compressionname forKey:XADCompressionNameKey];

				if(flags&SIT5FLAGS_CRYPTED) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];

				//if(datamethod!=0&&datamethod!=13&&datamethod!=15)
				//DebugFileSearched(ai, "Unknown or untested compression method %ld.",datam;

				[self addEntryWithDictionary:dict];
			}
			[fh seekToFileOffset:datastart+resourcecomplen+datacomplen];
		}
	}
}

-(NSString *)formatName { return @"StuffIt 5"; }

@end



@implementation XADStuffIt5ExeParser

+(int)requiredHeaderSize { return 8192; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<4104) return NO;

	if(bytes[0]=='M'&&bytes[1]=='Z'&&CSUInt32BE(bytes+4100)==0x4203e853) return YES;
	return NO;
}

-(void)parse
{
	[[self handle] skipBytes:0x1a000];
	[super parse];
}

@end
