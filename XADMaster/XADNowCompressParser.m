#import "XADNowCompressParser.h"
#import "NSDateXAD.h"



@implementation XADNowCompressParser

+(int)requiredHeaderSize
{
	return 24;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	if(length<24) return NO;

	// This is garbage! TODO: Figure out better detection
	if(bytes[0]!=0x00||bytes[1]!=0x02||(bytes[2]!=0x00&&bytes[2]!=0x01)||bytes[3]!=0x60) return NO;
	if(bytes[4]!=0x00||bytes[5]!=0x01||bytes[6]!=0x00||bytes[7]!=0x00) return NO;

	return YES;
}

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *fh=[self handle];
	NSMutableArray *entries=[NSMutableArray array];

	[fh skipBytes:8];
	int numfiles=[fh readUInt32BE];
	[fh skipBytes:12];

	for(int i=0;i<numfiles;i++)
	{
		int namelen=[fh readUInt8];
		NSData *namedata=[fh readDataOfLength:namelen];
		[fh skipBytes:32-namelen];
		[fh skipBytes:5];

		uint32_t type=[fh readUInt32BE];
		uint32_t creator=[fh readUInt32BE];

		[fh skipBytes:8];

		uint32_t creation=[fh readUInt32BE];
		uint32_t modification=[fh readUInt32BE];
		
		[fh skipBytes:24];

		uint32_t datasize=[fh readUInt32BE];
		uint32_t rsrcsize=[fh readUInt32BE];

		[fh skipBytes:4];

		uint32_t datastart=[fh readUInt32BE];
		uint32_t dataend=[fh readUInt32BE];

		[fh skipBytes:4];

		XADPath *path=[self XADPathWithData:namedata separators:XADNoPathSeparator];

		NSDictionary *soliddict=[NSDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithUnsignedInt:datastart],@"Offset",
			[NSNumber numberWithUnsignedInt:dataend-datastart],@"Length",
		nil];

		if(datasize||!rsrcsize)
		{
			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				path,XADFileNameKey,
				[NSNumber numberWithUnsignedInt:datasize],XADFileSizeKey,
				[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
				[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
				[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
				//[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
				//[self XADStringWithString:[self nameForMethod:0]],XADCompressionNameKey,

				soliddict,XADSolidObjectKey,
				[NSNumber numberWithLongLong:0],XADSolidOffsetKey,
//				[NSNumber numberWithUnsignedInt:datasize],XADSolidLengthKey,
				[NSNumber numberWithUnsignedInt:256],XADSolidLengthKey,
			nil];

			if(datasize+rsrcsize) [dict setObject:[NSNumber numberWithUnsignedInt:(dataend-datastart)*datasize/(datasize+rsrcsize)] forKey:XADCompressedSizeKey];
			else [dict setObject:[NSNumber numberWithUnsignedInt:0] forKey:XADCompressedSizeKey];


			[entries addObject:dict];
		}

		if(rsrcsize)
		{
			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				path,XADFileNameKey,
				[NSNumber numberWithBool:YES],XADIsResourceForkKey,
				[NSNumber numberWithUnsignedInt:rsrcsize],XADFileSizeKey,
				[NSNumber numberWithUnsignedInt:(dataend-datastart)*rsrcsize/(datasize+rsrcsize)],XADCompressedSizeKey,
				[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
				[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
				[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
				//[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
				//[self XADStringWithString:[self nameForMethod:0]],XADCompressionNameKey,

				soliddict,XADSolidObjectKey,
//				[NSNumber numberWithLongLong:datasize],XADSolidOffsetKey,
//				[NSNumber numberWithUnsignedInt:rsrcsize],XADSolidLengthKey,
				[NSNumber numberWithLongLong:0],XADSolidOffsetKey,
				[NSNumber numberWithUnsignedInt:256],XADSolidLengthKey,
			nil];

			[entries addObject:dict];
		}
	}

	for(int i=0;i<numfiles;i++) [self addEntryWithDictionary:[entries objectAtIndex:i]];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
//	return [self subHandleFromSolidStreamForEntryWithDictionary:dict];
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	off_t offs=[[obj objectForKey:@"Offset"] longLongValue];
	off_t len=[[obj objectForKey:@"Length"] longLongValue];
	CSHandle *handle=[[self handle] nonCopiedSubHandleFrom:offs length:len];

	return handle;
}

-(NSString *)formatName
{
	return @"Now Compress";
}

@end



