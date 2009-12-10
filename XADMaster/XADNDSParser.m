#import "XADNDSParser.h"
#import "CSMemoryHandle.h"
#import "CRC.h"

#include <zlib.h>

static NSData *ConvertTiledIconToPNG(uint8_t *tiledata,uint16_t *palette);
static void AppendPNGChunk(NSMutableData *data,uint32_t chunktype,uint8_t *bytes,int length);

@implementation XADNDSParser

+(int)requiredHeaderSize { return 0x200; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<0x200) return NO;
	if(bytes[0x12]!=0) return NO;
	if(bytes[0x13]>7) return NO;
	if(bytes[0x15]!=0||bytes[0x16]!=0||bytes[0x17]!=0||bytes[0x18]!=0||bytes[0x19]!=0
	||bytes[0x1a]!=0||bytes[0x1b]!=0||bytes[0x1c]!=0||bytes[0x1d]!=0) return NO;
	if(XADCalculateCRC(0xffff,&bytes[0xc0],0x9c,XADCRCTable_a001)!=CSUInt16LE(&bytes[0x15c])) return NO;
	if(XADCalculateCRC(0xffff,bytes,0x15e,XADCRCTable_a001)!=CSUInt16LE(&bytes[0x15e])) return NO;

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	NSData *gametitle=[fh readDataOfLength:12];
	NSData *gamecode=[fh readDataOfLength:4];
	NSData *makercode=[fh readDataOfLength:2];
	[fh skipBytes:14];
	uint32_t arm9_offs=[fh readUInt32LE];
	uint32_t arm9_entry=[fh readUInt32LE];
	uint32_t arm9_addr=[fh readUInt32LE];
	uint32_t arm9_size=[fh readUInt32LE];
	uint32_t arm7_offs=[fh readUInt32LE];
	uint32_t arm7_entry=[fh readUInt32LE];
	uint32_t arm7_addr=[fh readUInt32LE];
	uint32_t arm7_size=[fh readUInt32LE];
	uint32_t fnt_offs=[fh readUInt32LE];
	uint32_t fnt_size=[fh readUInt32LE];
	uint32_t fat_offs=[fh readUInt32LE];
	uint32_t fat_size=[fh readUInt32LE];
	uint32_t arm9_overlay_offs=[fh readUInt32LE];
	uint32_t arm9_overlay_size=[fh readUInt32LE];
	uint32_t arm7_overlay_offs=[fh readUInt32LE];
	uint32_t arm7_overlay_size=[fh readUInt32LE];
	[fh skipBytes:8];
	uint32_t info_offs=[fh readUInt32LE];

	[properties setObject:gametitle forKey:@"NDSGameTitle"];
	[properties setObject:gamecode forKey:@"NDSGameCode"];
	[properties setObject:makercode forKey:@"NDSMakerCode"];

	BOOL homebrew;
	const uint8_t *makerbytes=[makercode bytes];
	if(makerbytes[0]==0&&makerbytes[1]==0) homebrew=YES;
	else homebrew=NO;

	BOOL unnamed;
	const uint8_t *titlebytes=[gametitle bytes];
	if(titlebytes[0]==0||(titlebytes[0]=='.'&&titlebytes[1]==0)) unnamed=YES;
	else unnamed=NO;

	XADPath *basepath;
	if(unnamed)
	{
		NSString *basename=[[self name] stringByDeletingPathExtension];
		if(homebrew) basename=[NSString stringWithFormat:@"%@ (Homebrew)",basename];
		else basename=[NSString stringWithFormat:@"%@ (%@ by %@)",basename,
		[[[NSString alloc] initWithData:gamecode encoding:NSISOLatin1StringEncoding] autorelease],
		[[[NSString alloc] initWithData:makercode encoding:NSISOLatin1StringEncoding] autorelease]];

		basepath=[self XADPathWithUnseparatedString:basename];
	}
	else
	{
		NSMutableData *basename=[NSMutableData dataWithData:gametitle];
		for(int i=0;i<12;i++)
		{
			if(!titlebytes[i])
			{
				[basename setLength:i];
				break;
			}
		}

		if(homebrew)
		{
			[basename appendBytes:" (Homebrew)" length:11];
		}
		else
		{
			[basename appendBytes:" (" length:2];
			[basename appendData:gamecode];
			[basename appendBytes:" by " length:4];
			[basename appendData:makercode];
			[basename appendBytes:")" length:1];
		}
		basepath=[self XADPathWithData:basename separators:XADNoPathSeparator];
	}

	if(info_offs)
	{
		[fh seekToFileOffset:info_offs+0x20];

		uint8_t tiledata[0x200];
		[fh readBytes:sizeof(tiledata) toBuffer:tiledata];

		uint16_t palette[16];
		[fh readBytes:sizeof(palette) toBuffer:palette];

		NSData *pngdata=ConvertTiledIconToPNG(tiledata,palette);
		[self addEntryWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
			[basepath pathByAppendingPathComponent:[self XADStringWithString:@"Icon.png"]],XADFileNameKey,
			[NSNumber numberWithUnsignedLong:[pngdata length]],XADFileSizeKey,
			[NSNumber numberWithUnsignedLong:0x210],XADCompressedSizeKey,
			pngdata,@"NDSData",
		nil]];

		NSString *filenames[6]=
		{
			[NSString stringWithUTF8String:"\346\227\245\346\234\254\350\252\236.txt"],
			@"English.txt",
			[NSString stringWithUTF8String:"Fran\303\247ais.txt"],
			@"Deutsch.txt",
			@"Italiano.txt",
			[NSString stringWithUTF8String:"Espa\303\261ol.txt"],
		};
		for(int i=0;i<6;i++)
		{
			[fh seekToFileOffset:info_offs+0x240+0x100*i];
			NSMutableString *string=[NSMutableString string];
			for(int j=0;j<128;j++)
			{
				int ch=[fh readUInt16LE];
				if(!ch) break;
				[string appendFormat:@"%C",ch];
			}

			NSData *data=[string dataUsingEncoding:NSUTF8StringEncoding];

			[self addEntryWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
				[basepath pathByAppendingPathComponent:[self XADStringWithString:filenames[i]]],XADFileNameKey,
				[NSNumber numberWithUnsignedLong:[data length]],XADFileSizeKey,
				[NSNumber numberWithUnsignedLong:0x100],XADCompressedSizeKey,
				data,@"NDSData",
			nil]];
		}
	}

	[self addEntryWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
		[basepath pathByAppendingPathComponent:[self XADStringWithString:
		[NSString stringWithFormat:@"ARM9-%08x-%08x.bin",arm9_addr,arm9_entry]]],XADFileNameKey,
		[NSNumber numberWithUnsignedLong:arm9_size],XADFileSizeKey,
		[NSNumber numberWithUnsignedLong:arm9_size],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLong:arm9_size],XADDataLengthKey,
		[NSNumber numberWithUnsignedLong:arm9_offs],XADDataOffsetKey,
	nil]];

	[self addEntryWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
		[basepath pathByAppendingPathComponent:[self XADStringWithString:
		[NSString stringWithFormat:@"ARM7-%08x-%08x.bin",arm7_addr,arm7_entry]]],XADFileNameKey,
		[NSNumber numberWithUnsignedLong:arm7_size],XADFileSizeKey,
		[NSNumber numberWithUnsignedLong:arm7_size],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLong:arm7_size],XADDataLengthKey,
		[NSNumber numberWithUnsignedLong:arm7_offs],XADDataOffsetKey,
	nil]];

	if(arm9_overlay_size)
	[self addEntryWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
		[basepath pathByAppendingPathComponent:[self XADStringWithString:
		[NSString stringWithFormat:@"ARM9.ovt",arm9_addr]]],XADFileNameKey,
		[NSNumber numberWithUnsignedLong:arm9_overlay_size],XADFileSizeKey,
		[NSNumber numberWithUnsignedLong:arm9_overlay_size],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLong:arm9_overlay_size],XADDataLengthKey,
		[NSNumber numberWithUnsignedLong:arm9_overlay_offs],XADDataOffsetKey,
	nil]];

	if(arm7_overlay_size)
	[self addEntryWithDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
		[basepath pathByAppendingPathComponent:[self XADStringWithString:
		[NSString stringWithFormat:@"ARM7.ovt",arm7_addr]]],XADFileNameKey,
		[NSNumber numberWithUnsignedLong:arm7_overlay_size],XADFileSizeKey,
		[NSNumber numberWithUnsignedLong:arm7_overlay_size],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLong:arm7_overlay_size],XADDataLengthKey,
		[NSNumber numberWithUnsignedLong:arm7_overlay_offs],XADDataOffsetKey,
	nil]];

	if(fnt_offs&&fnt_size&&fat_offs&&fat_size)
	{
		XADPath *directories[4096];
		memset(directories,0,sizeof(directories));

		directories[0]=[basepath pathByAppendingPathComponent:[self XADStringWithString:@"Datafiles"]];

		[fh seekToFileOffset:fnt_offs+6];
		int numdirs=[fh readUInt16LE];

		for(int i=0;i<numdirs;i++)
		{
			[fh seekToFileOffset:fnt_offs+i*8];
			uint32_t tableoffs=[fh readUInt32LE];
			int firstid=[fh readUInt16LE];

			XADPath *dirpath=directories[i];
			if(!dirpath) { NSLog(@"Error parsing nitro directory structure"); continue; }

			[fh seekToFileOffset:fnt_offs+tableoffs];

			int currid=firstid;
			for(;;)
			{
				int len=[fh readUInt8];
				if(len==0) break;

				NSData *namedata=[fh readDataOfLength:len&0x7f];
				XADString *name=[self XADStringWithData:namedata];
				XADPath *path=[dirpath pathByAppendingPathComponent:name];

				if(len&0x80) // directory
				{
					int dirid=[fh readUInt16LE];
					if(dirid>=0xf000)
					{
						directories[dirid-0xf000]=path;
					}
					else NSLog(@"Error parsing nitro directory entry");
				}
				else // regular file
				{
					if(currid<fat_size/8)
					{
						off_t pos=[fh offsetInFile];

						[fh seekToFileOffset:fat_offs+8*currid];
						uint32_t start=[fh readUInt32LE];
						uint32_t end=[fh readUInt32LE];

						[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
							path,XADFileNameKey,
							[NSNumber numberWithUnsignedLong:end-start],XADFileSizeKey,
							[NSNumber numberWithUnsignedLong:end-start],XADCompressedSizeKey,
							[NSNumber numberWithUnsignedLong:end-start],XADDataLengthKey,
							[NSNumber numberWithUnsignedLong:start],XADDataOffsetKey,
							[NSNumber numberWithInt:currid],@"NDSFileID",
						nil]];
						
						[fh seekToFileOffset:pos];
					}
					else NSLog(@"Error parsing nitro file entry");

					currid++;
				}
			}
		}
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSData *data=[dict objectForKey:@"NDSData"];
	if(data) return [CSMemoryHandle memoryHandleForReadingData:data];
	else return [self handleAtDataOffsetForDictionary:dict];
}

-(NSString *)formatName { return @"NDS"; }

@end

static NSData *ConvertTiledIconToPNG(uint8_t *tiledata,uint16_t *palette)
{
	NSMutableData *data=[NSMutableData dataWithCapacity:672];

	[data appendBytes:"\211PNG\r\n\032\n" length:8];

	AppendPNGChunk(data,'IHDR',(uint8_t *)"\000\000\000\040\000\000\000\040\004\003\000\000\000",13);

	uint8_t plte[3*16];
	for(int i=0;i<16;i++)
	{
		int r=(palette[i]>>0)&0x1f;
		int g=(palette[i]>>5)&0x1f;
		int b=(palette[i]>>10)&0x1f;
		plte[3*i+0]=(r*0x21)>>2;
		plte[3*i+1]=(g*0x21)>>2;
		plte[3*i+2]=(b*0x21)>>2;
	}

	AppendPNGChunk(data,'PLTE',plte,sizeof(plte));

	uint8_t idat[7+32*17+4]="\170\234\001\040\002\337\375";

	for(int y=0;y<32;y++)
	{
		idat[7+y*17]=0;
		for(int x=0;x<16;x++)
		{
			int val=tiledata[(x/4+(y/8)*4)*32+(x&3)+(y&7)*4];
			idat[7+y*17+1+x]=(val>>4)|(val<<4);
		}
	}

	CSSetUInt32BE(&idat[sizeof(idat)-4],adler32(1,&idat[7],sizeof(idat)-7-4));

	AppendPNGChunk(data,'IDAT',idat,sizeof(idat));

	AppendPNGChunk(data,'IEND',(uint8_t *)"",0);

	return data;
}

static void AppendPNGChunk(NSMutableData *data,uint32_t chunktype,uint8_t *bytes,int length)
{
	uint8_t buf[4];
	uint32_t crc=0xffffffff;

	CSSetUInt32BE(buf,length);
	[data appendBytes:buf length:4];

	CSSetUInt32BE(buf,chunktype);
	[data appendBytes:buf length:4];
	crc=XADCalculateCRC(crc,buf,4,XADCRCTable_edb88320);

	[data appendBytes:bytes length:length];
	crc=XADCalculateCRC(crc,bytes,length,XADCRCTable_edb88320);

	CSSetUInt32BE(buf,~crc);
	[data appendBytes:buf length:4];
}
