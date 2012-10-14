#import "XADLZXParser.h"
#import "XADLZXHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"



@implementation XADLZXParser

+(int)requiredHeaderSize { return 10; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=10&&bytes[0]=='L'&&bytes[1]=='Z'&&bytes[2]=='X';
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:10];

	NSMutableArray *solidfiles=[NSMutableArray array];
	off_t solidsize=0;

	while([self shouldKeepParsing])
	{
		int attributes;
		@try { attributes=[fh readUInt16LE]; }
		@catch(id e) { break; }

		uint32_t filesize=[fh readUInt32LE];
		uint32_t compsize=[fh readUInt32LE];
		int os=[fh readUInt8];
		int method=[fh readUInt8];
		int flags=[fh readUInt16LE];
		int commentlen=[fh readUInt8];
		int version=[fh readUInt8];
		[fh skipBytes:2];
		uint32_t date=[fh readUInt32LE];
		uint32_t datacrc=[fh readUInt32LE];
		/*uint32_t headercrc=*/[fh readUInt32LE];
		int namelen=[fh readUInt8];

		NSData *namedata=[fh readDataOfLength:namelen];
		NSData *commentdata=nil;
		if(commentlen) commentdata=[fh readDataOfLength:commentlen];

		off_t dataoffs=[fh offsetInFile];

		int day=(date>>27)&31;
		int month=((date>>23)&15)+1;
		int year=((date>>17)&63)+1970;
		int hour=(date>>12)&31;
		int minute=(date>>6)&63;
		int second=(date&63);

		// From libxad LZX:
		if(year>=2028) year+=2000-2028; // Original LZX
		else if(year<1978) year+=2034-1970; // Dr.Titus
		// Dates from 1978 to 1999 are correct
		// Dates from 2000 to 2027 Mikolaj patch are correct
		// Dates from 2000 to 2005 LZX/Dr.Titus patch are correct
		// Dates from 2034 to 2041 Dr.Titus patch are correct

		NSDate *dateobj=[NSDate XADDateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:nil];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[self XADPathWithData:namedata separators:XADUnixPathSeparator],XADFileNameKey,
			[NSNumber numberWithUnsignedLong:filesize],XADFileSizeKey,
			[NSNumber numberWithUnsignedLong:filesize],XADSolidLengthKey,
			[NSNumber numberWithUnsignedLong:solidsize],XADSolidOffsetKey,
			//[NSNumber numberWithUnsignedLong:compsize],XADCompressedSizeKey,
			dateobj,XADLastModificationDateKey,
			[NSNumber numberWithInt:os],@"LZXOS",
			[NSNumber numberWithInt:method],@"LZXMethod",
			[NSNumber numberWithInt:flags],@"LZXFlags",
			[NSNumber numberWithInt:version],@"LZXVersion",
			[NSNumber numberWithInt:datacrc],@"LZXCRC32",
		nil];

		NSString *methodname=nil;
		switch(method)
		{
			case 0: methodname=@"None"; break;
			case 2: methodname=@"LZX"; break;
		}
		if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

		NSString *osname=nil;
		switch(os)
		{
			case 0: osname=@"MSDOS"; break;
			case 1: osname=@"Windows"; break;
			case 2: osname=@"OS/2"; break;
			case 10: osname=@"Amiga"; break;
			case 20: osname=@"Unix"; break;
		}
		if(osname) [dict setObject:[self XADStringWithString:osname] forKey:@"LZXOSName"];

		if(os==10)
		{
			// Decode Amiga protection bits
			int prot=0;
			if(!(attributes&0x01)) prot|=0x08; // Read
			if(!(attributes&0x02)) prot|=0x04; // Write
			if(!(attributes&0x04)) prot|=0x01; // Delete
			if(!(attributes&0x08)) prot|=0x02; // Execute
			if(attributes&0x10) prot|=0x10; // Archive
			if(attributes&0x20) prot|=0x80; // Hold
			if(attributes&0x40) prot|=0x40; // Script
			if(attributes&0x80) prot|=0x20; // Pure
			
			[dict setObject:[NSNumber numberWithInt:prot] forKey:XADAmigaProtectionBitsKey];
		}

		[solidfiles addObject:dict];
		solidsize+=filesize;

		if(compsize)
		{
			NSMutableDictionary *solidobj=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithUnsignedInt:compsize],XADDataLengthKey,
				[NSNumber numberWithUnsignedInt:dataoffs],XADDataOffsetKey,
				[NSNumber numberWithLongLong:solidsize],@"TotalSize",
				[NSNumber numberWithInt:method],@"Method",
			nil];

			NSEnumerator *enumerator=[solidfiles objectEnumerator];
			NSMutableDictionary *dict;
			while((dict=[enumerator nextObject]))
			{
				[dict setObject:solidobj forKey:XADSolidObjectKey];
				[dict setObject:[NSNumber numberWithLongLong:
				([[dict objectForKey:XADFileSizeKey] longLongValue]*(off_t)compsize)/solidsize]
				forKey:XADCompressedSizeKey];
				[self addEntryWithDictionary:dict];
			}

			[solidfiles removeAllObjects];
			solidsize=0;
		}

		[fh seekToFileOffset:dataoffs+compsize];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:[handle fileSize]
	correctCRC:[[dict objectForKey:@"LZXCRC32"] unsignedIntValue] conditioned:YES];

	return handle;
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:obj];
	off_t length=[[obj objectForKey:@"TotalSize"] longLongValue];
	int method=[[obj objectForKey:@"Method"] intValue];

	switch(method)
	{
		case 0: return handle;
		case 2: return [[[XADLZXHandle alloc] initWithHandle:handle length:length] autorelease];
		default: return nil;
	}
}

-(NSString *)formatName { return @"LZX"; }

@end
