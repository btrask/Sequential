#import "XADPackItParser.h"
#import "XADStuffItHuffmanHandle.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

@implementation XADPackItParser

+(int)requiredHeaderSize
{
	return 4;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	if(length<4) return NO;

	if(bytes[0]=='P'&&bytes[1]=='M'&&bytes[2]=='a')
	if(bytes[3]=='g'||bytes[3]=='4'||bytes[3]=='5'||bytes[3]=='6') return YES;

	return NO;
}

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *handle=[self handle];

	for(;;)
	{
		uint32_t magic=[handle readID];
		if(magic=='PEnd') break;

		off_t start=[handle offsetInFile];

		BOOL comp,encrypted;
		CSHandle *fh;
		CSInputBuffer *input=NULL;
		NSMutableDictionary *datadesc;

		if(magic=='PMag')
		{
			comp=NO;
			encrypted=NO;
			fh=handle;
		}
		else if(magic=='PMa4'||magic=='PMa5'||magic=='PMa6')
		{
			comp=YES;

			CSHandle *src;
			if(magic=='PMa4')
			{
				src=handle;
				encrypted=NO;
			}
			else if(magic=='PMa5')
			{
				src=[[[XADPackItXORHandle alloc] initWithHandle:handle
				password:[[self password] dataUsingEncoding:NSMacOSRomanStringEncoding]] autorelease];
				encrypted=YES;
			}
			else if(magic=='PMa6')
			{
				src=[[[XADPackItDESHandle alloc] initWithHandle:handle
				password:[[self password] dataUsingEncoding:NSMacOSRomanStringEncoding]] autorelease];
				encrypted=YES;
			}

			XADStuffItHuffmanHandle *hh=[[[XADStuffItHuffmanHandle alloc] initWithHandle:src] autorelease];
			input=hh->input;
			fh=hh;
		}
		else [XADException raiseIllegalDataException];

		int namelen=[fh readUInt8];
		if(namelen>63) namelen=63;
		uint8_t namebuf[63];
		[fh readBytes:63 toBuffer:namebuf];
		XADPath *name=[self XADPathWithBytes:namebuf length:namelen separators:XADNoPathSeparator];

		uint32_t type=[fh readUInt32BE];
		uint32_t creator=[fh readUInt32BE];
		int finderflags=[fh readUInt16BE];
		[fh skipBytes:2];
		uint32_t datasize=[fh readUInt32BE];
		uint32_t rsrcsize=[fh readUInt32BE];
		uint32_t modification=[fh readUInt32BE];
		uint32_t creation=[fh readUInt32BE];
		/*int headcrc=*/[fh readUInt16BE];

		uint32_t datacompsize,rsrccompsize;
		off_t end;

		if(!comp)
		{
			[fh skipBytes:datasize+rsrcsize];
			int crc=[fh readUInt16BE];

			datacompsize=datasize;
			rsrccompsize=rsrcsize;
			end=start+94+datacompsize+rsrccompsize+2;

			datadesc=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithLongLong:start+94],@"Offset",
				[NSNumber numberWithLongLong:datasize+rsrcsize],@"Length",
				[NSNumber numberWithInt:crc],@"CRC",
			nil];
		}
		else
		{
			[fh skipBytes:datasize];
			datacompsize=CSInputBufferOffset(input)-94;

			[fh skipBytes:rsrcsize];
			rsrccompsize=CSInputBufferOffset(input)-datacompsize-94;

			int crc=[fh readUInt16BE];

			CSInputSkipToByteBoundary(input);

			int crypto;
			if(magic=='PMa4')
			{
				end=start+CSInputBufferOffset(input);
				crypto=0;
			}
			else
			{
				end=start+((CSInputBufferOffset(input)+7)&~7);
				if(magic=='PMa5') crypto=1;
				else crypto=2;
			}

			datadesc=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[NSNumber numberWithLongLong:start],@"Offset",
				[NSNumber numberWithLongLong:end-start],@"Length",
				[NSNumber numberWithLongLong:datasize+rsrcsize+94],@"UncompressedLength",
				[NSNumber numberWithInt:crc],@"CRC",
				[NSNumber numberWithInt:crypto],@"Crypto",
			nil];
		}

		if(datasize||!rsrcsize)
		{
			[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				name,XADFileNameKey,
				[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
				[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
				[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
				[NSNumber numberWithUnsignedInt:datasize],XADFileSizeKey,
				[NSNumber numberWithUnsignedInt:datacompsize],XADCompressedSizeKey,
				[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
				[self XADStringWithString:comp?@"Huffman":@"None"],XADCompressionNameKey,
				[NSNumber numberWithBool:encrypted],XADIsEncryptedKey,

				datadesc,XADSolidObjectKey,
				[NSNumber numberWithUnsignedInt:0],XADSolidOffsetKey,
				[NSNumber numberWithUnsignedInt:datasize],XADSolidLengthKey,
			nil]];
		}

		if(rsrcsize)
		{
			[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				name,XADFileNameKey,
				[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
				[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
				[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
				[NSNumber numberWithUnsignedInt:rsrcsize],XADFileSizeKey,
				[NSNumber numberWithUnsignedInt:rsrccompsize],XADCompressedSizeKey,
				[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
				[self XADStringWithString:comp?@"Huffman":@"None"],XADCompressionNameKey,
				[NSNumber numberWithBool:encrypted],XADIsEncryptedKey,
				[NSNumber numberWithBool:YES],XADIsResourceForkKey,

				datadesc,XADSolidObjectKey,
				[NSNumber numberWithUnsignedInt:datasize],XADSolidOffsetKey,
				[NSNumber numberWithUnsignedInt:rsrcsize],XADSolidLengthKey,
			nil]];
		}

		[handle seekToFileOffset:end];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return [self subHandleFromSolidStreamForEntryWithDictionary:dict];
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	off_t offs=[[obj objectForKey:@"Offset"] longLongValue];
	off_t len=[[obj objectForKey:@"Length"] longLongValue];
	CSHandle *handle=[[self handle] nonCopiedSubHandleFrom:offs length:len];

	NSNumber *uncomplennum=[obj objectForKey:@"UncompressedLength"];
	if(uncomplennum)
	{
		off_t uncomplen=[uncomplennum longLongValue];
		int crypto=[[obj objectForKey:@"Crypto"] longLongValue];

		if(crypto==1)
		{
			handle=[[[XADPackItXORHandle alloc] initWithHandle:handle length:len
			password:[[self password] dataUsingEncoding:NSMacOSRomanStringEncoding]] autorelease];
		}
		else if(crypto==2)
		{
			handle=[[[XADPackItDESHandle alloc] initWithHandle:handle length:len
			password:[[self password] dataUsingEncoding:NSMacOSRomanStringEncoding]] autorelease];
		}

		handle=[[[XADStuffItHuffmanHandle alloc] initWithHandle:handle length:uncomplen] autorelease];
		handle=[handle nonCopiedSubHandleFrom:94 length:uncomplen-94];
	}

	if(checksum)
	{
		handle=[XADCRCHandle CCITTCRC16HandleWithHandle:handle length:[handle fileSize]
		correctCRC:[[obj objectForKey:@"CRC"] intValue] conditioned:NO];
	}

	return handle;
}

-(NSString *)formatName
{
	return @"PackIt";
}

@end



@implementation XADPackItXORHandle

-(id)initWithHandle:(CSHandle *)handle password:(NSData *)passdata
{
	return [self initWithHandle:handle length:CSHandleMaxLength password:passdata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata
{
	if((self=[super initWithHandle:handle length:length]))
	{
		const uint8_t *passbytes=[passdata bytes];
		int passlen=[passdata length];

		uint8_t passbuf[8];

		memset(passbuf,0,8);
		memcpy(passbuf,passbytes,passlen<8?passlen:8);

		static const int keytr1[56]=
		{
			57,49,41,33,25,17, 9, 1,58,50,42,34,26,18,10, 2,59,51,43,35,27,19,11,03,60,52,44,36,
			63,55,47,39,31,23,15, 7,62,54,46,38,30,22,14, 6,61,53,45,37,29,21,13, 5,28,20,12, 4
		};

		memset(key,0,8);
		for(int i=0;i<56;i++)
		{
			int bitindex=keytr1[i]-1;
			key[i/8]|=((passbuf[bitindex/8]<<(bitindex%8))&0x80)>>(i%8);
		}

		[self setBlockPointer:block];
	}
	return self;
}


-(int)produceBlockAtOffset:(off_t)pos
{
	memset(block,0,8);

	for(int i=0;i<8;i++)
	{
		if(CSInputAtEOF(input)) { [self endBlockStream]; break; }
		block[i]=CSInputNextByte(input)^key[(pos+i)%7];
	}

	return 8;
}

@end



@implementation XADPackItDESHandle

-(id)initWithHandle:(CSHandle *)handle password:(NSData *)passdata
{
	return [self initWithHandle:handle length:CSHandleMaxLength password:passdata];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata
{
	if((self=[super initWithHandle:handle length:length]))
	{
		const uint8_t *passbytes=[passdata bytes];
		int passlen=[passdata length];

		DES_cblock key;
		memset(key,0,8);
		memcpy(key,passbytes,passlen<8?passlen:8);

		DES_set_key_unchecked(&key,&schedule);

		[self setBlockPointer:outblock];
	}
	return self;
}


-(int)produceBlockAtOffset:(off_t)pos
{
	memset(inblock,0,8);

	for(int i=0;i<8;i++)
	{
		if(CSInputAtEOF(input)) { [self endBlockStream]; break; }
		inblock[i]=CSInputNextByte(input);
	}

	DES_ecb_encrypt(&inblock,&outblock,&schedule,0);

	return 8;
}

@end
