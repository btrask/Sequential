#import "XADNDSParser.h"
#import "CSMemoryHandle.h"
#import "CRC.h"
#import "XADPNGWriter.h"

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
		[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
			[basepath pathByAppendingXADStringComponent:[self XADStringWithString:@"Icon.png"]],XADFileNameKey,
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
				unichar ch=[fh readUInt16LE];
				if(!ch) break;
				[string appendFormat:@"%C",ch];
			}

			NSData *data=[string dataUsingEncoding:NSUTF8StringEncoding];

			[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[basepath pathByAppendingXADStringComponent:[self XADStringWithString:filenames[i]]],XADFileNameKey,
				[NSNumber numberWithUnsignedLong:[data length]],XADFileSizeKey,
				[NSNumber numberWithUnsignedLong:0x100],XADCompressedSizeKey,
				data,@"NDSData",
			nil]];
		}
	}

	[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[basepath pathByAppendingXADStringComponent:[self XADStringWithString:
		[NSString stringWithFormat:@"ARM9-%08x-%08x.bin",arm9_addr,arm9_entry]]],XADFileNameKey,
		[NSNumber numberWithUnsignedLong:arm9_size],XADFileSizeKey,
		[NSNumber numberWithUnsignedLong:arm9_size],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLong:arm9_size],XADDataLengthKey,
		[NSNumber numberWithUnsignedLong:arm9_offs],XADDataOffsetKey,
	nil]];

	[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[basepath pathByAppendingXADStringComponent:[self XADStringWithString:
		[NSString stringWithFormat:@"ARM7-%08x-%08x.bin",arm7_addr,arm7_entry]]],XADFileNameKey,
		[NSNumber numberWithUnsignedLong:arm7_size],XADFileSizeKey,
		[NSNumber numberWithUnsignedLong:arm7_size],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLong:arm7_size],XADDataLengthKey,
		[NSNumber numberWithUnsignedLong:arm7_offs],XADDataOffsetKey,
	nil]];

	if(arm9_overlay_size)
	[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[basepath pathByAppendingXADStringComponent:[self XADStringWithString:
		[NSString stringWithFormat:@"ARM9-%08x.ovt",arm9_addr]]],XADFileNameKey,
		[NSNumber numberWithUnsignedLong:arm9_overlay_size],XADFileSizeKey,
		[NSNumber numberWithUnsignedLong:arm9_overlay_size],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLong:arm9_overlay_size],XADDataLengthKey,
		[NSNumber numberWithUnsignedLong:arm9_overlay_offs],XADDataOffsetKey,
	nil]];

	if(arm7_overlay_size)
	[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[basepath pathByAppendingXADStringComponent:[self XADStringWithString:
		[NSString stringWithFormat:@"ARM7-%08x.ovt",arm7_addr]]],XADFileNameKey,
		[NSNumber numberWithUnsignedLong:arm7_overlay_size],XADFileSizeKey,
		[NSNumber numberWithUnsignedLong:arm7_overlay_size],XADCompressedSizeKey,
		[NSNumber numberWithUnsignedLong:arm7_overlay_size],XADDataLengthKey,
		[NSNumber numberWithUnsignedLong:arm7_overlay_offs],XADDataOffsetKey,
	nil]];

	if(fnt_offs&&fnt_size&&fat_offs&&fat_size)
	{
		XADPath *directories[4096];
		memset(directories,0,sizeof(directories));

		directories[0]=[basepath pathByAppendingXADStringComponent:[self XADStringWithString:@"Datafiles"]];

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
				XADPath *path=[dirpath pathByAppendingXADStringComponent:name];

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
	XADPNGWriter *png=[XADPNGWriter PNGWriter];

	[png addIHDRWithWidth:32 height:32 bitDepth:4 colourType:3];

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

	[png addChunk:'PLTE' bytes:plte length:sizeof(plte)];

	[png startIDAT];

	for(int y=0;y<32;y++)
	{
		uint8_t row[16];
		for(int x=0;x<16;x++)
		{
			int val=tiledata[(x/4+(y/8)*4)*32+(x&3)+(y&7)*4];
			row[x]=(val>>4)|(val<<4);
		}
		[png addIDATRow:row];
	}

	[png endIDAT];

	[png addIEND];

	return [png data];
}


