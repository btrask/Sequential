#import "XADNSAParser.h"
#import "CSMemoryHandle.h"
#import "CSBzip2Handle.h"
#import "XADRegex.h"

static NSMutableData *DecodeSPB(CSHandle *fh,uint32_t length);
static void SetSPBPixel(uint8_t *pixels,int bytesperrow,int width,int height,int channel,int n,uint8_t val);
static NSMutableData *MakeBMPContainer(int width,int height,uint32_t length,int *bytesperrowptr);

@implementation XADNSAParser

+(int)requiredHeaderSize { return 6; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	if(!name) return NO;
	if(![[name lastPathComponent] matchedByPattern:@"^arc[0-9]*\\.nsa$" options:REG_ICASE]) return NO;

	//const uint8_t *bytes=[data bytes];
	//int length=[data length];

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	int numfiles=[fh readUInt16BE];
	if(numfiles==0) numfiles=[fh readUInt16BE];

	uint32_t offset=[fh readUInt32BE];

	for(int i=0;i<numfiles && [self shouldKeepParsing];i++)
	{
		NSMutableData *namedata=[NSMutableData data];
		uint8_t c;
		while((c=[fh readUInt8])) [namedata appendBytes:&c length:1];

		int method=[fh readUInt8];
		uint32_t dataoffs=[fh readUInt32BE];
		uint32_t datalen=[fh readUInt32BE];
		uint32_t filesize=[fh readUInt32BE];

		NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[self XADPathWithData:namedata separators:XADWindowsPathSeparator],XADFileNameKey,
			[NSNumber numberWithUnsignedLong:filesize],XADFileSizeKey,
			[NSNumber numberWithUnsignedLong:datalen],XADCompressedSizeKey,
			[NSNumber numberWithUnsignedLong:datalen],XADDataLengthKey,
			[NSNumber numberWithUnsignedLong:dataoffs+offset],XADDataOffsetKey,
			[NSNumber numberWithInt:method],@"NSAMethod",
		nil];

		NSString *methodname=nil;
		switch(method)
		{
			case 0: methodname=@"None"; break;
			case 1: methodname=@"SPB"; break;
			case 2: methodname=@"LZSS"; break;
			case 4: methodname=@"Bzip2"; break;
		}
		if(methodname) [dict setObject:[self XADStringWithString:methodname] forKey:XADCompressionNameKey];

		[self addEntryWithDictionary:dict retainPosition:YES];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	int method=[[dict objectForKey:@"NSAMethod"] intValue];
	uint32_t length=[[dict objectForKey:XADFileSizeKey] unsignedIntValue];

	switch(method)
	{
		case 0:
			return handle;

		case 1:
			return [CSMemoryHandle memoryHandleForReadingData:DecodeSPB(handle,length)];

		case 2:
			//return handle;
			return [[[XADNSALZSSHandle alloc] initWithHandle:handle length:length] autorelease];

		case 4:
			return [CSBzip2Handle bzip2HandleWithHandle:handle length:length];
	}

	return nil;
}

-(NSString *)formatName { return @"NSA"; }

@end



@implementation XADNSALZSSHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [super initWithHandle:handle length:length windowSize:256];
}

-(void)resetLZSSHandle
{
	uint8_t c1=CSInputNextByte(input);
	uint8_t c2=CSInputNextByte(input);

	if(c1==0xa1&&c2==0x53) CSInputRestart(input);
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	if(CSInputNextBit(input)) return CSInputNextBitString(input,8);
	else
	{
		*offset=pos-CSInputNextBitString(input,8)-17;
		*length=CSInputNextBitString(input,4)+2;

		return XADLZSSMatch;
	}
}

@end



static NSMutableData *DecodeSPB(CSHandle *fh,uint32_t length)
{
	int width=[fh readUInt16BE];
	int height=[fh readUInt16BE];

	int bytesperrow;
	NSMutableData *data=MakeBMPContainer(width,height,length,&bytesperrow);

	uint8_t *bytes=[data mutableBytes];
	uint8_t *pixels=&bytes[54];

	CSInputBuffer *input=CSInputBufferAlloc(fh,[fh fileSize]);

	@try
	{
		for(int channel=0;channel<3;channel++)
		{
			int n=0;
			uint8_t val=CSInputNextBitString(input,8);
			SetSPBPixel(pixels,bytesperrow,width,height,channel,n++,val);

			while(n<width*height)
			{
				int nbits=CSInputNextBitString(input,3);

				if(nbits==0)
				{
					for(int i=0;i<4 && n<=width*height;i++)
					SetSPBPixel(pixels,bytesperrow,width,height,channel,n++,val);
					continue;
				}

				int mask;
				if(nbits==7) mask=CSInputNextBitString(input,1)+1;
				else mask=nbits+2;

				for(int i=0;i<4 && n<=width*height;i++)
				{
					if(mask==8) val=CSInputNextBitString(input,8);
					else
					{
						int t=CSInputNextBitString(input,mask);
						if(t&1) val+=(t>>1)+1;
						else val-=(t>>1);
					}
					SetSPBPixel(pixels,bytesperrow,width,height,channel,n++,val);
				}
			}
		}
	}
	@catch(id e)
	{
	}

	CSInputBufferFree(input);

	return data;
}

static void SetSPBPixel(uint8_t *pixels,int bytesperrow,int width,int height,int channel,int n,uint8_t val)
{
	if(n>=width*height) return;

	int x=n%width;
	int y=n/width;

	if(y&1) x=width-1-x;

	y=height-1-y;

	pixels[channel+x*3+y*bytesperrow]=val;
}

static NSMutableData *MakeBMPContainer(int width,int height,uint32_t length,int *bytesperrowptr)
{
	int bytesperrow=((width*3)+3)&~3;
	int bmpsize=54+bytesperrow*height;
	if(length>bmpsize) bmpsize=length;
	NSMutableData *data=[NSMutableData dataWithLength:bmpsize];
	uint8_t *bytes=[data mutableBytes];

	bytes[0]='B';
	bytes[1]='M';

	CSSetInt32LE(&bytes[2],bmpsize); // FILESIZE
	CSSetInt32LE(&bytes[10],54); // OFFSET
	CSSetInt32LE(&bytes[14],40); // BLOCKSIZE
	CSSetInt32LE(&bytes[18],width); // WIDTH
	CSSetInt32LE(&bytes[22],height); // HEIGHT
	CSSetInt16LE(&bytes[26],1); // FIELDS = 1
	CSSetInt16LE(&bytes[28],24); // BPP = 24

	if(bytesperrowptr) *bytesperrowptr=bytesperrow;
	return data;
}
