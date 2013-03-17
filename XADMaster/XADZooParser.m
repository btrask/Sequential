#import "XADZooParser.h"
#import "XADLZHStaticHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

@implementation XADZooParser

+(int)requiredHeaderSize { return 0x22; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<0x22) return NO;
	if(bytes[0x14]!=0xdc||bytes[0x15]!=0xa7||bytes[0x16]!=0xc4||bytes[0x17]!=0xfd) return NO;

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh seekToFileOffset:0x18];
	uint32_t firstoffset=[fh readUInt32LE];

	[fh seekToFileOffset:firstoffset];

	while([self shouldKeepParsing])
	{
		uint32_t magic=[fh readUInt32LE];
		if(magic!=0xfdc4a7dc) [XADException raiseIllegalDataException];

		int type=[fh readUInt8];
		int method=[fh readUInt8];
		uint32_t nextdirentry=[fh readUInt32LE];
		uint32_t dataoffset=[fh readUInt32LE];
		int date=[fh readUInt16LE];
		int time=[fh readUInt16LE];
		int crc16=[fh readUInt16LE];
		uint32_t uncompsize=[fh readUInt32LE];
		uint32_t compsize=[fh readUInt32LE];
		int creatorversion=[fh readUInt8];
		int minversion=[fh readUInt8];
		int deleted=[fh readUInt8];
		int structure=[fh readUInt8];
		uint32_t commentoffset=[fh readUInt32LE];
		int commentlength=[fh readUInt16LE];

		if(!nextdirentry) break;

		uint8_t shortnamebuf[13];
		[fh readBytes:13 toBuffer:shortnamebuf];
		int shortnamelength=0;
		while(shortnamelength<12 && shortnamebuf[shortnamelength]!=0) shortnamelength++;
		NSData *shortnamedata=[NSData dataWithBytes:shortnamebuf length:shortnamelength];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[NSNumber numberWithUnsignedLong:uncompsize],XADFileSizeKey,
			[NSNumber numberWithUnsignedLong:compsize],XADCompressedSizeKey,
			[NSNumber numberWithUnsignedLong:dataoffset],XADDataOffsetKey,
			[NSNumber numberWithUnsignedLong:compsize],XADDataLengthKey,
			[NSNumber numberWithInt:type],@"ZooType",
			[NSNumber numberWithInt:method],@"ZooMethod",
			[NSNumber numberWithInt:crc16],@"ZooCRC16",
			[NSNumber numberWithInt:creatorversion],@"ZooCreatorVersion",
			[NSNumber numberWithInt:minversion],@"ZooMinimumVersion",
			[NSNumber numberWithInt:deleted],@"ZooIsDeleted",
			[NSNumber numberWithInt:structure],@"ZooStructure",
			shortnamedata,@"ZooShortnameData",
		nil];

		NSString *methodname=nil;
		switch(method)
		{
			case 0: methodname=@"None"; break;
			case 1: methodname=@"LZW"; break;
			case 2: methodname=@"LZH"; break;
		}
		if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

		XADPath *path=nil;
		NSTimeZone *timezone=nil;

		if(type==2)
		{
			int varlength=[fh readUInt16LE];
			int tzoffs=[fh readUInt8];
			/*int crcent=*/[fh readUInt16LE];

			if(tzoffs<128) timezone=[NSTimeZone timeZoneForSecondsFromGMT:tzoffs*15*60];
			else timezone=[NSTimeZone timeZoneForSecondsFromGMT:(tzoffs-256)*15*60];
			[dict setObject:[NSNumber numberWithInt:tzoffs] forKey:@"ZooTimeZone"];

			NSData *longnamedata=nil,*dirdata=nil;
			int longnamelength=0,dirlength=0;
			if(varlength>=1) longnamelength=[fh readUInt8];
			if(varlength>=2) dirlength=[fh readUInt8];

			if(longnamelength && varlength>=2+longnamelength)
			{
				longnamedata=[fh readDataOfLength:longnamelength];

				// Strip trailing nul byte, if it exists. Not sure if it is
				// always present, so make this conditional.
				const uint8_t *bytes=[longnamedata bytes];
				if(bytes[longnamelength-1]==0)
				longnamedata=[longnamedata subdataWithRange:NSMakeRange(0,longnamelength-1)];
			}

			if(dirlength && varlength>=2+longnamelength+dirlength)
			{
				dirdata=[fh readDataOfLength:dirlength];

				// Strip trailing nul byte, if it exists. Not sure if it is
				// always present, so make this conditional.
				const uint8_t *bytes=[dirdata bytes];
				if(bytes[dirlength-1]==0)
				dirdata=[dirdata subdataWithRange:NSMakeRange(0,dirlength-1)];
			}

			if(longnamedata) [dict setObject:longnamedata forKey:@"ZooLongNameData"];
			if(dirdata) [dict setObject:dirdata forKey:@"ZooDirectoryData"];

			int totalnamelength=2+longnamelength+dirlength;

			if(varlength>totalnamelength+2)
			{
				int system=[fh readUInt16LE];
				[dict setObject:[NSNumber numberWithInt:system] forKey:@"ZooSystem"];
			}

			if(varlength>totalnamelength+5)
			{
				int perm=[fh readUInt16LE];
				perm+=[fh readUInt8]<<16;
				[dict setObject:[NSNumber numberWithInt:perm] forKey:@"ZooPermissions"];
			}

			int generation=0;
			if(varlength>totalnamelength+6)
			{
				generation=[fh readUInt8];
				[dict setObject:[NSNumber numberWithInt:generation] forKey:@"ZooGeneration"];
			}

			if(varlength>totalnamelength+8)
			{
				int extraversion=[fh readUInt16LE];
				[dict setObject:[NSNumber numberWithInt:extraversion] forKey:@"ZooExtraVersion"];
			}

			if(longnamedata||dirdata||generation)
			{
				XADPath *parent;
				if(dirdata) parent=[self XADPathWithData:dirdata separators:XADUnixPathSeparator];
				else parent=[self XADPath];

				NSData *namedata;
				if(longnamedata) namedata=longnamedata;
				else namedata=shortnamedata;

				if(generation)
				{
					NSMutableData *mutablenamedata=[NSMutableData dataWithData:namedata];
					char string[32];
					sprintf(string,";%d",generation);
					[mutablenamedata appendBytes:string length:strlen(string)];
					namedata=mutablenamedata;
				}

				path=[parent pathByAppendingXADStringComponent:[self XADStringWithData:namedata]];
			}
		}

		if(path) [dict setObject:path forKey:XADFileNameKey];
		else [dict setObject:[self XADPathWithData:shortnamedata separators:XADNoPathSeparator] forKey:XADFileNameKey];

		[dict setObject:[NSDate XADDateWithMSDOSDate:date time:time timeZone:timezone]
		forKey:XADLastModificationDateKey];

		if(commentoffset&&commentlength)
		{
			[fh seekToFileOffset:commentoffset];
			NSData *commentdata=[fh readDataOfLength:commentlength];

			// Strip trailing nul byte, if it exists. Not sure if it is
			// always present, so make this conditional.
			const uint8_t *bytes=[commentdata bytes];
			if(bytes[commentlength-1]==0)
			commentdata=[commentdata subdataWithRange:NSMakeRange(0,commentlength-1)];

			[dict setObject:[self XADStringWithData:commentdata] forKey:XADCommentKey];
		}

		[self addEntryWithDictionary:dict];

		[fh seekToFileOffset:nextdirentry];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	int method=[[dict objectForKey:@"ZooMethod"] intValue];
	int crc=[[dict objectForKey:@"ZooCRC16"] intValue];
	uint32_t length=[[dict objectForKey:XADFileSizeKey] unsignedIntValue];

	switch(method)
	{
		case 0:
		break;

		case 1:
			handle=[[[XADZooMethod1Handle alloc] initWithHandle:handle length:length] autorelease];
		break;

		case 2:
			handle=[[[XADLZHStaticHandle alloc] initWithHandle:handle length:length windowBits:13] autorelease];
		break;

		default:
			[self reportInterestingFileWithReason:@"Unsupported compression method %d",method];
			return nil;
	}

	if(checksum) handle=[XADCRCHandle IBMCRC16HandleWithHandle:handle length:length correctCRC:crc conditioned:NO];

	return handle;
}

-(NSString *)formatName { return @"Zoo"; }

@end



@implementation XADZooMethod1Handle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithHandle:handle length:length]))
	{
		lzw=AllocLZW(8192,2);
	}
	return self;
}

-(void)dealloc
{
	FreeLZW(lzw);
	[super dealloc];
}

-(void)resetByteStream
{
	ClearLZWTable(lzw);
	currbyte=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!currbyte)
	{
		int symbol;
		for(;;)
		{
			symbol=CSInputNextBitStringLE(input,LZWSuggestedSymbolSize(lzw));
			if(symbol==256)
			{
				ClearLZWTable(lzw);
			}
			else if(symbol==257)
			{
				CSByteStreamEOF(self);
			}
			else break;
		}

		if(NextLZWSymbol(lzw,symbol)==LZWInvalidCodeError) [XADException raiseDecrunchException];
		currbyte=LZWReverseOutputToBuffer(lzw,buffer);
	}

	return buffer[--currbyte];
}

@end



