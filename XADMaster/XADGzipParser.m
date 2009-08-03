#import "XADGzipParser.h"
#import "CSZlibHandle.h"
#import "XADCRCSuffixHandle.h"



@implementation XADGzipParser

+(int)requiredHeaderSize { return 3; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<3) return NO;
	if(bytes[0]==0x1f)
	{
		if((bytes[1]==0x8b||bytes[1]==0x9e) && bytes[2]==8) return YES;
		if(bytes[1]==0xa1) return YES; /* BSD-compress variant */
	}
	return NO;
}

-(void)parse
{
	CSHandle *handle=[self handle];

	uint16_t headid=[handle readUInt16BE];
	uint8_t method=[handle readUInt8];
	uint8_t flags=[handle readUInt8];
	uint32_t time=[handle readUInt32LE];
	uint8_t extraflags=[handle readUInt8];
	uint8_t os=[handle readUInt8];

	if(method!=8) [XADException raiseIllegalDataException];

	NSMutableData *filename=nil,*comment=nil;

    if(headid!=0x1fa1)
    {
		if(flags&0x04) // FEXTRA: extra fields
		{
			uint16_t len=[handle readUInt16LE];
			[handle skipBytes:len];
		}
		if(flags&0x08) // FNAME: filename
		{
			filename=[NSMutableData data];
			uint8_t chr;
			while(chr=[handle readUInt8]) [filename appendBytes:&chr length:1];
		}
		if(flags&0x10) // FCOMMENT: comment
		{
			comment=[NSMutableData data];
			uint8_t chr;
			while(chr=[handle readUInt8]) [comment appendBytes:&chr length:1];
		}
		if(flags&0x02) // FHCRC: header crc
		{
			[handle skipBytes:2];
		}
    }

	off_t datapos=[handle offsetInFile];

	[handle seekToEndOfFile];
	[handle skipBytes:-4];
	off_t size=[handle readUInt32LE];
	off_t compsize=[handle offsetInFile]-datapos-8;

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithLongLong:compsize],XADCompressedSizeKey,
		[NSNumber numberWithLongLong:datapos],XADDataOffsetKey,
		[NSDate dateWithTimeIntervalSince1970:time],XADLastModificationDateKey,
		[self XADStringWithString:@"Deflate"],XADCompressionNameKey,
		[NSNumber numberWithUnsignedInt:extraflags],@"GzipExtraFlags",
		[NSNumber numberWithUnsignedInt:os],@"GzipOS",
	nil];

	[dict setObject:[NSNumber numberWithLongLong:size] forKey:XADFileSizeKey];

	if(filename)
	{
		[dict setObject:[self XADPathWithData:filename separators:XADUnixPathSeparator] forKey:XADFileNameKey];

		NSString *stringname=[[NSString alloc] initWithData:filename encoding:NSISOLatin1StringEncoding];
		if([stringname matchedByPattern:@"\\.(tar|cpio)" options:REG_ICASE])
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];
		[stringname release];
	}
	else
	{
		NSString *name=[self name];
		NSString *extension=[[name pathExtension] lowercaseString];
		NSString *contentname;
		if([extension isEqual:@"tgz"]) contentname=[[name stringByDeletingPathExtension] stringByAppendingPathExtension:@"tar"];
		else if([extension isEqual:@"adz"]) contentname=[[name stringByDeletingPathExtension] stringByAppendingPathExtension:@"adf"];
		else if([extension isEqual:@"cpgz"]) contentname=[[name stringByDeletingPathExtension] stringByAppendingPathExtension:@"cpio"];
		else contentname=[name stringByDeletingPathExtension];

		// TODO: set no filename flag
		[dict setObject:[self XADPathWithUnseparatedString:contentname] forKey:XADFileNameKey];

		if([contentname matchedByPattern:@"\\.(tar|cpio)" options:REG_ICASE])
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];
	}

	if(comment) [dict setObject:[self XADStringWithData:comment] forKey:XADCommentKey];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dictionary];
	CSZlibHandle *zh=[CSZlibHandle deflateHandleWithHandle:handle];

	// TODO: somehow make checksumming work even though there are a million broken gzip files out there
	if(checksum)
	{
		[zh setSeekBackAtEOF:YES]; // enable seeking back after zlib reads too much data at the end
		return [XADCRCSuffixHandle IEEECRC32SuffixHandleWithHandle:zh
		CRCHandle:handle bigEndianCRC:NO conditioned:YES];
	}
	else return zh;
}

-(NSString *)formatName { return @"Gzip"; }

@end



@implementation XADGzipSFXParser

+(int)requiredHeaderSize { return 5000; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<5) return NO;
	if(length>5000) length=5000;

	if(bytes[0]!='#'||bytes[1]!='!') return NO;

	for(int i=2;i<length-3;i++)
	{
		if(bytes[i]==0x1f&&(bytes[i+1]==0x8b||bytes[i+1]==0x9e)&&bytes[i+2]==8) return YES;
    }

	return NO;
}

-(void)parse
{
	CSHandle *fh=[self handle];
	uint8_t buf[5000-2];
	[fh skipBytes:2];
	[fh readBytes:sizeof(buf) toBuffer:buf];

	for(int i=0;i<5000-5;i++)
	{
		if(buf[i]==0x1f&&(buf[i+1]==0x8b||buf[i+1]==0x9e)&&buf[i+2]==8)
		{
			[fh seekToFileOffset:i+2];
			[super parse];
			return;
		}
	}
}

-(NSString *)formatName { return @"Gzip (Self-extracting)"; }

@end



