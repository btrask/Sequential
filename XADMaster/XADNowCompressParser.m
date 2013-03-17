#import "XADNowCompressParser.h"
#import "XADNowCompressHandle.h"
#import "NSDateXAD.h"

#import "XADCRCHandle.h"


@implementation XADNowCompressParser

+(int)requiredHeaderSize
{
	return 24;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	if(length<134) return NO;

	if(bytes[0]!=0x00||bytes[1]!=0x02) return NO; // Check magic bytes.

	if(CSUInt32BE(&bytes[8])>0xffff) return NO; // Check number of files. Assume no
	if(CSUInt32BE(&bytes[8])==0) return NO; //  archive has more than 65535 files.

	if(bytes[24]>31) return NO; // Check name length.
	if(bytes[24]==0) return NO;

	for(int i=0;i<bytes[24];i++)
	if(bytes[25+i]<32) return NO; // Check for valid filename.

	uint32_t sum=0;
	for(int i=24;i<130;i++) sum+=bytes[i];
	if(sum!=CSUInt32BE(&bytes[130])) return NO; // Check checksum.

	return YES;
}

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *fh=[self handle];

	[fh skipBytes:8];
	totalentries=[fh readUInt32BE];
	[fh skipBytes:12];

	currentries=0;
	entries=[NSMutableArray array];
	filesarray=[NSMutableArray array];
	solidoffset=0;

	[self parseDirectoryWithParent:[self XADPath] numberOfEntries:INT_MAX];

	int numdicts=[entries count];
	for(int i=0;i<numdicts && [self shouldKeepParsing];i++)
	[self addEntryWithDictionary:[entries objectAtIndex:i]];
}

-(void)parseDirectoryWithParent:(XADPath *)parent numberOfEntries:(int)numentries
{
	CSHandle *fh=[self handle];

	for(int i=0;i<numentries && currentries<totalentries;i++,currentries++)
	{
		if(![self shouldKeepParsing]) break;

		int namelen=[fh readUInt8];
		NSData *namedata=[fh readDataOfLength:namelen];
		[fh skipBytes:31-namelen];
		[fh skipBytes:4];

		int flags=[fh readUInt16BE];

		NSData *finderinfo=[fh readDataOfLength:16];

		uint32_t creation=[fh readUInt32BE];
		uint32_t modification=[fh readUInt32BE];
		uint32_t access=[fh readUInt32BE];
		
		[fh skipBytes:16];

		int numdirentries=[fh readUInt16BE];

		[fh skipBytes:2];

		uint32_t datasize=[fh readUInt32BE];
		uint32_t rsrcsize=[fh readUInt32BE];

		[fh skipBytes:4];

		uint32_t datastart=[fh readUInt32BE];
		uint32_t dataend=[fh readUInt32BE];

		[fh skipBytes:4]; // Skip checksum.

		XADString *name=[self XADStringWithData:namedata];
		XADPath *path=[parent pathByAppendingXADStringComponent:name];

		NSMutableDictionary *shareddict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			path,XADFileNameKey,
			[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
			[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
			finderinfo,XADFinderInfoKey,
			[NSNumber numberWithInt:flags],@"NowFlags",
		nil];

		if(access) [shareddict setObject:[NSDate XADDateWithTimeIntervalSince1904:access] forKey:XADLastAccessDateKey];

		if(flags&0x10) // Directory
		{
			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithBool:YES],XADIsDirectoryKey,
			nil];

			[dict addEntriesFromDictionary:shareddict];

			[entries addObject:dict];

			[self parseDirectoryWithParent:path numberOfEntries:numdirentries];
		}
		else
		{
			[filesarray addObject:[NSNumber numberWithUnsignedInt:datastart]];

			if(rsrcsize)
			{
				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithBool:YES],XADIsResourceForkKey,
					[NSNumber numberWithUnsignedInt:rsrcsize],XADFileSizeKey,
					[NSNumber numberWithUnsignedInt:(dataend-datastart)*rsrcsize/(datasize+rsrcsize)],XADCompressedSizeKey,
					[self XADStringWithString:@"Now Compress"],XADCompressionNameKey,
					filesarray,XADSolidObjectKey,
					[NSNumber numberWithLongLong:solidoffset],XADSolidOffsetKey,
					[NSNumber numberWithUnsignedInt:rsrcsize],XADSolidLengthKey,
				nil];

				[dict addEntriesFromDictionary:shareddict];

				[entries addObject:dict];

				solidoffset+=rsrcsize;
			}

			if(datasize||!rsrcsize)
			{
				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					[NSNumber numberWithUnsignedInt:datasize],XADFileSizeKey,
					[self XADStringWithString:@"Now Compress"],XADCompressionNameKey,
					filesarray,XADSolidObjectKey,
					[NSNumber numberWithLongLong:solidoffset],XADSolidOffsetKey,
					[NSNumber numberWithUnsignedInt:datasize],XADSolidLengthKey,
				nil];

				[dict addEntriesFromDictionary:shareddict];

				if(datasize+rsrcsize) [dict setObject:[NSNumber numberWithUnsignedInt:(dataend-datastart)*datasize/(datasize+rsrcsize)] forKey:XADCompressedSizeKey];
				else [dict setObject:[NSNumber numberWithUnsignedInt:0] forKey:XADCompressedSizeKey];

				[entries addObject:dict];

				solidoffset+=datasize;
			}
		}
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	if([dict objectForKey:XADIsDirectoryKey]) return nil;
	return [self subHandleFromSolidStreamForEntryWithDictionary:dict];

/*	CSHandle *handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];

	if([[[dict objectForKey:XADFileNameKey] lastPathComponent] isEqual:@"test5"])
	handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle correctCRC:0x4fa8ca5a conditioned:YES];

	else if([[[dict objectForKey:XADFileNameKey] lastPathComponent] isEqual:@"test6"])
	handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle correctCRC:0x4dee978f conditioned:YES];

	else if([[[dict objectForKey:XADFileNameKey] lastPathComponent] isEqual:@"test7"])
	handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle correctCRC:0xaab9ef52 conditioned:YES];

	else if([[[dict objectForKey:XADFileNameKey] lastPathComponent] isEqual:@"test8"])
	handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle correctCRC:0x23dcbf69 conditioned:YES];

	return handle;*/
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	return [[[XADNowCompressHandle alloc] initWithHandle:[self handle] files:obj] autorelease];
}

-(NSString *)formatName
{
	return @"Now Compress";
}

@end



