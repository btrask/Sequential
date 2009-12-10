#import "XADALZipParser.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "XADDeflateHandle.h"
#import "XADCRCHandle.h"
#import "XADRegex.h"
#import "NSDateXAD.h"

static off_t ParseNumber(CSHandle *handle,int size)
{
	switch(size)
	{
		case 1: return [handle readUInt8];
		case 2: return [handle readUInt16LE];
		case 4: return [handle readUInt32LE];
		case 8: return [handle readUInt64LE];
		default: [XADException raiseIllegalDataException];
	}
	return 0;
}

static void CalculateSillyTable(int *table,int param)
{
	for(int i=0;i<19;i++) table[i]=i;
	for(int i=0;i<19;i++)
	{
		int swapindex=(i%6)*3+param;
		if(swapindex>18) swapindex%=18;
		if(swapindex!=i)
		{
			int tmp=table[i];
			table[i]=table[swapindex];
			table[swapindex]=tmp;
		}
	}
}

@implementation XADALZipParser

+(int)requiredHeaderSize { return 8; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=8&&bytes[0]=='A'&&bytes[1]=='L'&&bytes[2]=='Z'&&bytes[3]==1&&bytes[7]==0;
}

+(NSArray *)volumesForFilename:(NSString *)filename
{
	NSArray *matches;

	if(matches=[filename substringsCapturedByPattern:@"^(.*)\\.(alz|a[0-9]{2}|b[0-9]{2})$" options:REG_ICASE])
	{
		return [self scanForVolumesWithFilename:filename
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.(alz|a[0-9]{2}|b[0-9]{2})$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:@"alz"];
	}

	return nil;
}

-(void)parse
{
	XADSkipHandle *fh=[self skipHandle];

	NSArray *volumes=[self volumes];
	if(volumes)
	{
		int count=[volumes count];
		off_t offs=0;
		for(int i=0;i<count-1;i++)
		{
			offs+=[[volumes objectAtIndex:i] fileSize];
			[fh addSkipFrom:offs-16 to:offs+8];
		}
	}

	[fh skipBytes:8];

	while([self shouldKeepParsing])
	{
		uint32_t signature=[fh readID];

		if(signature=='BLZ\001')
		{
			int namelen=[fh readUInt16LE];
			int attrs=[fh readUInt8];
			uint32_t dostime=[fh readUInt32LE];
			int flags=[fh readUInt8];
			[fh skipBytes:1];

			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSDate XADDateWithMSDOSDateTime:dostime],XADLastModificationDateKey,
				[NSNumber numberWithInt:attrs],@"ALZipAttributes",
				[NSNumber numberWithInt:flags],@"ALZipFlags",
			nil];

			if(attrs&0x10) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
			if(flags&0x01) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsEncryptedKey];

			off_t compsize=0;

			int sizebytes=flags>>4;
			if(sizebytes)
			{
				int method=[fh readUInt8];
				[dict setObject:[NSNumber numberWithInt:method] forKey:@"ALZipCompressionMethod"];

				NSString *compname=nil;
				switch(method)
				{
					case 0: compname=@"None"; break;
					case 1: compname=@"Bzip2"; break;
					case 2: compname=@"Deflate"; break;
					case 3: compname=@"Obfuscated deflate"; break;
				}
				if(compname) [dict setObject:[self XADStringWithString:compname] forKey:XADCompressionNameKey];

				[fh skipBytes:1];
				[dict setObject:[NSNumber numberWithUnsignedInt:[fh readUInt32LE]] forKey:@"ALZipCRC32"];

				compsize=ParseNumber(fh,sizebytes);
				off_t size=ParseNumber(fh,sizebytes);

				[dict setObject:[NSNumber numberWithLongLong:compsize] forKey:XADCompressedSizeKey];
				[dict setObject:[NSNumber numberWithLongLong:compsize] forKey:XADSkipLengthKey];
				[dict setObject:[NSNumber numberWithLongLong:size] forKey:XADFileSizeKey];
			}

			// TODO: force korean encoding?
			NSData *namedata=[fh readDataOfLength:namelen];
			[dict setObject:[self XADPathWithData:namedata separators:XADEitherPathSeparator] forKey:XADFileNameKey];

			[dict setObject:[NSNumber numberWithLongLong:[fh offsetInFile]] forKey:XADSkipOffsetKey];

			off_t pos=[fh offsetInFile];
			[self addEntryWithDictionary:dict];
			[fh seekToFileOffset:pos+compsize];
		}
		else if(signature=='CLZ\001') break;
		else if(signature=='ELZ\001') break; // give up on comment blocks, which are always at the end anyway
		else [XADException raiseIllegalDataException];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];
	//off_t compsize=[[dict objectForKey:XADCompressedSizeKey] longLongValue];
	uint32_t crc=[[dict objectForKey:@"ALZipCRC32"] unsignedIntValue];

	if([dict objectForKey:XADIsEncryptedKey])
	{
		// TODO: encryption
		[XADException raiseNotSupportedException];
		/*handle=[[[XADZipCryptHandle alloc] initWithHandle:handle length:compsize
		password:[self encodedPassword] testByte:crc>>24] autorelease];*/
	}

	switch([[dict objectForKey:@"ALZipCompressionMethod"] intValue])
	{
		case 0: break; // No compression
		case 1: handle=[CSBzip2Handle bzip2HandleWithHandle:handle length:size]; break;
		case 2: handle=[CSZlibHandle deflateHandleWithHandle:handle length:size]; break;
		case 3:
		{
			handle=[[[XADDeflateHandle alloc] initWithHandle:handle length:size] autorelease];

			int order[19];
			CalculateSillyTable(order,[[dict objectForKey:XADFileSizeKey] intValue]%16);
			[(XADDeflateHandle *)handle setMetaTableOrder:order];
		}
		break;

		default: return nil;
	}

	if(checksum) handle=[XADCRCHandle IEEECRC32HandleWithHandle:handle length:size correctCRC:crc conditioned:YES];

	return handle;
}

-(NSString *)formatName { return @"ALZip"; }

@end
