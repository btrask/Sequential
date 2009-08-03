#import "XADPowerPackerParser.h"
#import "CSMemoryHandle.h"
#import "XADException.h"

static NSData *PowerPackerUnpack(NSData *packeddata,int unpackedlength);

@implementation XADPowerPackerParser

+(int)requiredHeaderSize { return 4; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	return length>=8&&bytes[0]=='P'&&bytes[1]=='P'&&bytes[2]=='2'&&bytes[3]=='0';
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh seekToEndOfFile];

	off_t compsize=[fh offsetInFile]-4;

	[fh skipBytes:-4];

	int size=[fh readUInt8]<<16;
	size|=[fh readUInt8]<<8;
	size|=[fh readUInt8];

	[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithUnseparatedString:[[self name] stringByDeletingPathExtension]],XADFileNameKey,
		[NSNumber numberWithLongLong:size],XADFileSizeKey,
		[NSNumber numberWithLongLong:compsize],XADCompressedSizeKey,
		[self XADStringWithString:@"PowerPacker"],XADCompressionNameKey,

		[NSNumber numberWithLongLong:4],XADDataOffsetKey,
		[NSNumber numberWithLongLong:compsize],XADDataLengthKey,
	nil]];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSData *data=[dict objectForKey:@"PowerPackerFileContents"];
	if(!data)
	{
		CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
		data=PowerPackerUnpack([handle remainingFileContents],[[dict objectForKey:XADFileSizeKey] intValue]);
		[(NSMutableDictionary *)dict setObject:data forKey:@"PowerPackerFileContents"];
	}

	return [CSMemoryHandle memoryHandleForReadingData:data];
}

-(NSString *)formatName { return @"PowerPacker"; }

@end

static uint32_t GetBits(int n,const uint8_t *buffer,int *bitpos)
{
	uint32_t result=0;

	for(int i=0;i<n;i++)
	{
		(*bitpos)--;
		if(*bitpos<0) [XADException raiseDecrunchException];
		int currbyte=*bitpos/8;
		int currbit=7-(*bitpos&7);
		result=(result<<1)|((buffer[currbyte]>>currbit)&1);
	}
	return result;
}

static NSData *PowerPackerUnpack(NSData *packeddata,int unpackedlength)
{
	const uint8_t *packed=[packeddata bytes];
	int packedlength=[packeddata length];

	NSMutableData *unpackeddata=[NSMutableData dataWithLength:unpackedlength];
	uint8_t *unpacked=[unpackeddata mutableBytes];

	int bitpos=packedlength*8-32;
	uint8_t *dest=unpacked+unpackedlength;

	// Skip extra bits
	GetBits(packed[packedlength-1],packed,&bitpos);

	for(;;)
	{
		if(GetBits(1,packed,&bitpos)==0) // copy some bytes from the source
		{
			int add,numbytes=1;
			do
			{
				add=GetBits(2,packed,&bitpos);
				numbytes+=add;
			} while(add==3);

			for(int i=0;i<numbytes;i++)
			{
				if(dest<=unpacked) [XADException raiseDecrunchException];
				*--dest=GetBits(8,packed,&bitpos);
			}
			if(dest==unpacked) return unpackeddata;
		}

		// decode what to copy from the destination file
		int index=GetBits(2,packed,&bitpos);
		int numbits=packed[index];
		int numbytes=index+2;
		int offset; 

		if(numbytes==5) // 5 means >=5
		{
			// and maybe a bigger offset
			if(GetBits(1,packed,&bitpos)==0) offset=GetBits(7,packed,&bitpos);
			else offset=GetBits(numbits,packed,&bitpos);

			int add;
			do {
				add=GetBits(3,packed,&bitpos);
				numbytes+=add;
			} while(add==7);
		}
		else offset=GetBits(numbits,packed,&bitpos);

		for(int i=0;i<numbytes;i++)
		{
			if(dest<=unpacked) [XADException raiseDecrunchException];
			dest[-1]=dest[offset];
			dest--;
		}
		if(dest==unpacked) return unpackeddata;
	}

	return nil; // can't happen
}
