#import "XADCompactProParser.h"
#import "XADCompactProRLEHandle.h"
#import "XADCompactProLZHHandle.h"
#import "XADException.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

@implementation XADCompactProParser

+(int)requiredHeaderSize { return 8; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<8) return NO;
	if(bytes[0]!=1) return NO;

	uint32_t offset=CSUInt32BE(bytes+4);

	off_t filesize=[handle fileSize];
	if(filesize==CSHandleMaxLength) return [name matchedByPattern:@"\\.(cpt|sea)" options:REG_ICASE];

	if(offset+7>filesize) return NO;

	@try
	{
		[handle seekToFileOffset:offset];
		uint32_t correctcrc=[handle readUInt32BE];

		uint8_t buf[256];
		uint32_t crc=0xffffffff;

		[handle readBytes:3 toBuffer:buf];
		crc=XADCalculateCRC(crc,buf,3,XADCRCTable_edb88320);

		int numentries=CSUInt16BE(buf);
		int commentsize=buf[2];

		[handle readBytes:commentsize toBuffer:buf];
		crc=XADCalculateCRC(crc,buf,commentsize,XADCRCTable_edb88320);

		for(int i=0;i<numentries;i++)
		{
			int namelen=[handle readUInt8];
			crc=XADCRC(crc,namelen,XADCRCTable_edb88320);

			[handle readBytes:namelen&0x7f toBuffer:buf];
			crc=XADCalculateCRC(crc,buf,namelen&0x7f,XADCRCTable_edb88320);

			int metadatasize;
			if(namelen&0x80) metadatasize=2;
			else metadatasize=45;

			[handle readBytes:metadatasize toBuffer:buf];
			crc=XADCalculateCRC(crc,buf,metadatasize,XADCRCTable_edb88320);
		}

		if(crc==correctcrc) return YES;
	}
	@catch(id e) {}

	return NO;
}

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *fh=[self handle];

	/*int marker=*/[fh readUInt8];
	/*int volume=*/[fh readUInt8];
	/*int xmagic=*/[fh readUInt16BE];
	uint32_t offset=[fh readUInt32BE];

	[fh seekToFileOffset:offset];

	/*uint32_t headcrc=*/[fh readUInt32BE];
	int numentries=[fh readUInt16BE];
	int commentlen=[fh readUInt8];

	if(commentlen)
	{
		NSData *comment=[fh readDataOfLength:commentlen];
		[self setObject:[self XADStringWithData:comment] forPropertyKey:XADCommentKey];
	}

	NSMutableArray *entries=[NSMutableArray array];

	// Since the recognizer has already verified that the metadata is intact, reading
	// should be safe, so to avoid stream resets, we just collect entries into an array
	// and send all of them out at once.
	[self parseDirectoryWithPath:[self XADPath] numberOfEntries:numentries entryArray:entries];

	NSEnumerator *enumerator=[entries objectEnumerator];
	NSMutableDictionary *dict;
	while((dict=[enumerator nextObject])) [self addEntryWithDictionary:dict];
}

-(BOOL)parseDirectoryWithPath:(XADPath *)parent numberOfEntries:(int)numentries entryArray:(NSMutableArray *)entries
{
	CSHandle *fh=[self handle];

	while(numentries)
	{
		if(![self shouldKeepParsing]) return NO;

		int namelen=[fh readUInt8];
		NSData *namedata=[fh readDataOfLength:namelen&0x7f];
		XADPath *path=[parent pathByAppendingXADStringComponent:[self XADStringWithData:namedata]];

		if(namelen&0x80)
		{
			int numdirentries=[fh readUInt16BE];

			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				path,XADFileNameKey,
				[NSNumber numberWithBool:YES],XADIsDirectoryKey,
			nil];

			[entries addObject:dict];

			if(![self parseDirectoryWithPath:path numberOfEntries:numdirentries entryArray:entries]) return NO;

			numentries-=numdirentries+1;
		}
		else
		{
			int volume=[fh readUInt8];
			uint32_t fileoffs=[fh readUInt32BE];
			uint32_t type=[fh readUInt32BE];
			uint32_t creator=[fh readUInt32BE];
			uint32_t creationdate=[fh readUInt32BE];
			uint32_t modificationdate=[fh readUInt32BE];
			int finderflags=[fh readUInt16BE];
			uint32_t crc=[fh readUInt32BE];
			int flags=[fh readUInt16BE]; // TODO: bit 0 means encryption
			uint32_t resourcelength=[fh readUInt32BE];
			uint32_t datalength=[fh readUInt32BE];
			uint32_t resourcecomplen=[fh readUInt32BE];
			uint32_t datacomplen=[fh readUInt32BE];

			if(resourcelength)
			{
				NSString *crckey;
				if(datalength) crckey=@"CompactProSharedCRC32";
				else crckey=@"CompactProCRC32";

				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					path,XADFileNameKey,
					[NSNumber numberWithUnsignedInt:resourcelength],XADFileSizeKey,
					[NSNumber numberWithUnsignedInt:resourcecomplen],XADCompressedSizeKey,
					[NSDate XADDateWithTimeIntervalSince1904:modificationdate],XADLastModificationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:creationdate],XADCreationDateKey,
					[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
					[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
					[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
					[self XADStringWithString:flags&2?@"LZH+RLE":@"RLE"],XADCompressionNameKey,

					[NSNumber numberWithBool:YES],XADIsResourceForkKey,
					[NSNumber numberWithUnsignedInt:resourcecomplen],XADDataLengthKey,
					[NSNumber numberWithLongLong:fileoffs],XADDataOffsetKey,
					[NSNumber numberWithBool:flags&2?YES:NO],@"CompactProLZH",
					[NSNumber numberWithInt:flags],@"CompactProFlags",
					[NSNumber numberWithUnsignedInt:crc],crckey,
					[NSNumber numberWithUnsignedInt:volume],@"CompactProVolume",
				nil];

				[entries addObject:dict];
			}

			if(datalength||resourcelength==0)
			{
				NSString *crckey;
				if(resourcelength) crckey=@"CompactProSharedCRC32";
				else crckey=@"CompactProCRC32";

				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					path,XADFileNameKey,
					[NSNumber numberWithUnsignedInt:datalength],XADFileSizeKey,
					[NSNumber numberWithUnsignedInt:datacomplen],XADCompressedSizeKey,
					[NSDate XADDateWithTimeIntervalSince1904:modificationdate],XADLastModificationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:creationdate],XADCreationDateKey,
					[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
					[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
					[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
					[self XADStringWithString:flags&4?@"LZH+RLE":@"RLE"],XADCompressionNameKey,

					[NSNumber numberWithLongLong:fileoffs+resourcecomplen],XADDataOffsetKey,
					[NSNumber numberWithUnsignedInt:datacomplen],XADDataLengthKey,
					[NSNumber numberWithBool:flags&4?YES:NO],@"CompactProLZH",
					[NSNumber numberWithInt:flags],@"CompactProFlags",
					[NSNumber numberWithUnsignedInt:crc],crckey,
					[NSNumber numberWithUnsignedInt:volume],@"CompactProVolume",
				nil];

				[entries addObject:dict];
			}

			numentries--;
		}
	}
	return YES;
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];

	if([[dict objectForKey:@"CompactProLZH"] boolValue])
	handle=[[[XADCompactProLZHHandle alloc] initWithHandle:handle blockSize:0x1fff0] autorelease];

	handle=[[[XADCompactProRLEHandle alloc] initWithHandle:handle length:size] autorelease];

	NSNumber *crc=[dict objectForKey:@"CompactProCRC32"];
	if(checksum&&crc)
	handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:size correctCRC:~[crc unsignedIntValue] conditioned:YES];

	return handle;
}

-(NSString *)formatName { return @"Compact Pro"; }

@end
