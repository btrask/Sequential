#import "XADBinHexParser.h"
#import "XADException.h"
#import "CSMemoryHandle.h"
#import "XADCRCSuffixHandle.h"

@implementation XADBinHexParser

+(int)requiredHeaderSize { return 8192; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	BOOL found=NO;
	int offs;
	for(offs=0;offs<length-45&&!found;offs++)
	{
		if(!memcmp("(This file must be converted with BinHex",bytes+offs,40)) found=YES;
	}
	if(!found) return NO;

	offs+=40;

	while(offs<length&&bytes[offs]!='\n'&&bytes[offs]!='\r') offs++;
	if(offs==length) return NO;

	while(offs<length&&(bytes[offs]=='\n'||bytes[offs]=='\r'||bytes[offs]=='\t'||bytes[offs]==' ')) offs++;
	if(offs==length) return NO;

	if(bytes[offs]!=':') return NO;

	CSMemoryHandle *mh=[CSMemoryHandle memoryHandleForReadingBuffer:(uint8_t *)bytes+offs length:length-offs];
	XADBinHexHandle *fh=[[[XADBinHexHandle alloc] initWithHandle:mh] autorelease];
	uint16_t crc=0;

	uint8_t len=[fh readUInt8];
	if(len<1||len>63) return NO;
	crc=XADCRC(crc,len,XADCRCReverseTable_1021);

	// Read and checksum header
	for(int i=0;i<len+19;i++) crc=XADCRC(crc,[fh readUInt8],XADCRCReverseTable_1021);

	// Check CRC
	uint16_t realcrc=[fh readUInt16BE];
	if(realcrc!=XADUnReverseCRC16(crc)) return NO;

	return YES;
}

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *handle=[self handle];

	uint8_t buffer[40];
	[handle readBytes:40 toBuffer:buffer];

	while(memcmp("(This file must be converted with BinHex",buffer,40))
	{
		memmove(buffer,buffer+1,39);
		buffer[39]=[handle readUInt8];
	}

	uint8_t byte;
	do { byte=[handle readUInt8]; } while(byte!='\n'&&byte!='\r');

	off_t start=[handle offsetInFile];

	XADBinHexHandle *fh=[[[XADBinHexHandle alloc] initWithHandle:[self handle]] autorelease];

	uint8_t namelen=[fh readUInt8];
	if(namelen>63) [XADException raiseIllegalDataException];

	NSData *namedata=[fh readDataOfLength:namelen];

	BOOL isarc=NO;
	if(namelen>4)
	{
		const uint8_t *name=[namedata bytes];
		const uint8_t *ext=name+namelen-4;
		if(memcmp(ext,".sit",4)==0) isarc=YES;
		else if(memcmp(ext,".cpt",4)==0) isarc=YES;
		else if(memcmp(ext,".sea",4)==0) isarc=YES;
	}

	if(!isarc)
	{
		if([[self name] matchedByPattern:@"\\.sea(\\.|$)" options:REG_ICASE]) isarc=YES;
	}

	[fh skipBytes:1];
	uint32_t type=[fh readUInt32BE];
	uint32_t creator=[fh readUInt32BE];
	uint16_t flags=[fh readUInt16BE];
	uint32_t datalen=[fh readUInt32BE];
	uint32_t resourcelen=[fh readUInt32BE];
	/*uint16_t crc=*/[fh readUInt16BE];

	[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithData:namedata separators:XADNoPathSeparator],XADFileNameKey,
		[NSNumber numberWithUnsignedInt:datalen],XADFileSizeKey,
		[NSNumber numberWithUnsignedInt:(datalen*4)/3],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
		[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
		[NSNumber numberWithUnsignedShort:flags],XADFinderFlagsKey,
		[NSNumber numberWithLongLong:start],XADDataOffsetKey,
		[NSNumber numberWithBool:isarc],XADIsArchiveKey,
		[NSNumber numberWithUnsignedInt:22+namelen],@"BinHexDataOffset",
	nil]];

	if(resourcelen)
	[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithData:namedata separators:XADNoPathSeparator],XADFileNameKey,
		[NSNumber numberWithUnsignedInt:resourcelen],XADFileSizeKey,
		//[NSNumber numberWithUnsignedInt:(resourcelen*4)/3],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
		[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
		[NSNumber numberWithUnsignedShort:flags],XADFinderFlagsKey,
		[NSNumber numberWithBool:YES],XADIsResourceForkKey,
		[NSNumber numberWithLongLong:start],XADDataOffsetKey,
		[NSNumber numberWithUnsignedInt:24+namelen+datalen],@"BinHexDataOffset",
	nil]];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	off_t size=[[dict objectForKey:XADFileSizeKey] unsignedLongValue];

	XADBinHexHandle *fh=[[[XADBinHexHandle alloc] initWithHandle:handle] autorelease];
	[fh seekToFileOffset:[[dict objectForKey:@"BinHexDataOffset"] longLongValue]];

	if(checksum) return [XADCRCSuffixHandle CCITTCRC16SuffixHandleWithHandle:[fh nonCopiedSubHandleOfLength:size]
	CRCHandle:[fh nonCopiedSubHandleOfLength:size+2] bigEndianCRC:YES conditioned:NO];
	else return [fh nonCopiedSubHandleOfLength:size];
}

-(NSString *)formatName { return @"BinHex"; }

@end



@implementation XADBinHexHandle

-(void)resetByteStream
{
	bytes=0;
	rle_byte=0;
	rle_num=0;

	// Scan for start-of-data ':' marker
	char prev='\n',curr;
	for(;;)
	{
		curr=CSInputNextByte(input);
		if(curr==':'&&(prev=='\n'||prev=='\r'||prev=='\t'||prev==' ')) break;
		prev=curr;
	}
}

static uint8_t GetBits(XADBinHexHandle *self)
{
	uint8_t *codes=(uint8_t *)"!\"#$%&'()*+,-012345689@ABCDEFGHIJKLMNPQRSTUVXYZ[`abcdefhijklmpqr";

	for(;;)
	{
		uint8_t byte=CSInputNextByte(self->input);
		if(byte==':') CSByteStreamEOF(self);
		for(int bits=0;bits<64;bits++) if(byte==codes[bits]) return bits;
	}
}

static uint8_t DecodeByte(XADBinHexHandle *self)
{
	uint8_t bits1,bits2;

	switch(self->bytes++%3)
	{
		case 0:
			bits1=GetBits(self);
			bits2=GetBits(self);
			self->prev_bits=bits2;
			return (bits1<<2)|(bits2>>4);
		break;

		case 1:
			bits1=self->prev_bits;
			bits2=GetBits(self);
			self->prev_bits=bits2;
			return (bits1<<4)|(bits2>>2);

		case 2:
			bits1=self->prev_bits;
			bits2=GetBits(self);
			return (bits1<<6)|bits2;
	}
	return 0; // can't happen
}

-(uint8_t)produceByteAtOffset:(off_t)pos;
{
	if(rle_num)
	{
		rle_num--;
		return rle_byte;
	}
	else
	{
		uint8_t byte=DecodeByte(self);

		if(byte!=0x90) return rle_byte=byte;
		else
		{
			uint8_t count=DecodeByte(self);
			if(count==0) return rle_byte=0x90;
			else
			{
				if(count==1) [XADException raiseDecrunchException];
				rle_num=count-2;
				return rle_byte;
			}
		}
	}
}
@end
