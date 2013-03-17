#import "XADSWFParser.h"
#import "XADSWFParser.h"
#import "XADPNGWriter.h"
#import "CSMemoryHandle.h"
#import "CSMultiHandle.h"
#import "CSZlibHandle.h"

@implementation XADSWFParser

+(int)requiredHeaderSize { return 6; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<4) return NO;

	//NSLog(@"SWF version %d\n",bytes[3]);

	if(bytes[3]>=32) return NO; // Assume the SWF format doesn't reach version 32 any time soon.
	if(bytes[0]=='F'&&bytes[1]=='W'&&bytes[2]=='S') return YES;
	if(bytes[0]=='C'&&bytes[1]=='W'&&bytes[2]=='S') return YES;

	return NO;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if((self=[super initWithHandle:handle name:name]))
	{
		parser=[[XADSWFTagParser parserWithHandle:handle] retain];
		dataobjects=[NSMutableArray new];
	}
	return self;
}

-(void)dealloc
{
	[parser release];
	[dataobjects release];
	[super dealloc];
}

-(void)parse
{
	[parser parseHeader];

	CSHandle *fh=[parser handle];

	int numimages=0;
	int numsounds=0;
	int numstreams=0;
	int laststreamframe=-1;
	NSData *jpegtables=nil;
	NSMutableData *mainstream=nil;

	NSString *compname;
	if([parser isCompressed]) compname=@"Zlib";
	else compname=@"None";

	int tag;
	while((tag=[parser nextTag]) && [self shouldKeepParsing])
	switch(tag)
	{
		case SWFJPEGTables:
		{
			int length=[parser tagLength];
			if(length>=2)
			{
				jpegtables=[fh readDataOfLength:length-2];
			}
			else
			{
				 // Apparently sometimes Flash uses a zero-length table tag,
				 // and this implicitly means that the header should be a
				 // single SOI marker.
				jpegtables=[NSData dataWithBytes:(uint8_t[2]){0xff,0xd8} length:2];
			}
			[dataobjects addObject:jpegtables];
		}
		break;

		case SWFDefineBitsJPEGTag:
		{
			numimages++;

			[fh skipBytes:4];
			off_t offset=[fh offsetInFile];
			off_t length=[parser tagBytesLeft];

			if(!jpegtables) [XADException raiseIllegalDataException];

			[self addEntryWithName:[NSString stringWithFormat:
			@"Image %d at frame %d.jpg",numimages,[parser frame]]
			data:jpegtables offset:offset length:length];
		}
		break;

		case SWFDefineBitsJPEG2Tag:
		case SWFDefineBitsJPEG3Tag:
		case SWFDefineBitsJPEG4Tag:
		{
			numimages++;

			[fh skipBytes:2];

			int alphaoffs=0;
			if(tag==SWFDefineBitsJPEG3Tag||tag==SWFDefineBitsJPEG4Tag)
			{
				alphaoffs=[fh readUInt32LE];
			}

			if(tag==SWFDefineBitsJPEG4Tag)
			{
				[fh skipBytes:2]; // Skip deblocking filter params.
			}

			off_t startoffs=[fh offsetInFile];

			int first=[fh readUInt16BE];
			if(first==0x8950)
			{
				// PNG image.
				[self reportInterestingFileWithReason:@"Image with PNG data"];
				[self addEntryWithName:[NSString stringWithFormat:
				@"Image %d at frame %d.png",numimages,[parser frame]]
				data:[NSData dataWithBytes:(uint8_t[2]){ 0x89,0x50 } length:2]
				offset:[fh offsetInFile] length:[parser tagBytesLeft]];
			}
			else if(first==0x4749)
			{
				// GIF image.
				[self reportInterestingFileWithReason:@"Image with GIF data"];
				[self addEntryWithName:[NSString stringWithFormat:
				@"Image %d at frame %d.gif",numimages,[parser frame]]
				data:[NSData dataWithBytes:(uint8_t[2]){ 0x47,0x49 } length:2]
				offset:[fh offsetInFile] length:[parser tagBytesLeft]];
			}
			else if(first==0xffd8||first==0xffd9)
			{
				// JPEG image.

				// Check if there is an invalid EOI/SOI marker pair at
				// the start of the image, and skip it.
				if(first==0xffd9)
				{
					[fh skipBytes:4];
					first=0xffd8;
				}

				// Parse JPEG markers to find image dimensions, and
				// to remove possible later EOI/SOI pairs.
				int width=0,height=0;

				CSMemoryHandle *header=[CSMemoryHandle memoryHandleForWriting];
				[header writeUInt16BE:first];
				for(;;)
				{
					int marker=[fh readUInt16BE];

					if(marker==0xffda)
					{
						[header writeUInt16BE:marker];

						off_t imagestart=[fh offsetInFile];
						int imagelength=[parser tagBytesLeft];

						// Calculate alpha channel extent and adjust
						// main image if needed.
						off_t alphastart=0;
						int alphalength=0;
						if(alphaoffs)
						{
							alphastart=startoffs+alphaoffs;
							alphalength=imagestart+imagelength-alphastart;
							imagelength=alphastart-imagestart;
						}

						// Emit main image.
						[self addEntryWithName:[NSString stringWithFormat:
						@"Image %d at frame %d.jpg",numimages,[parser frame]]
						data:[header data] offset:imagestart length:imagelength];

						// Emit alpha channel image if one exists.
						if(alphaoffs && width && height)
						{
							[self addEntryWithName:[NSString stringWithFormat:
							@"Image %d alpha channel at frame %d.png",numimages,[parser frame]]
							losslessFormat:-1 width:width height:height alpha:NO
							offset:alphastart length:alphalength];
						}

						break;
					}
					else if(marker==0xffd9)
					{
						// EOI marker. This is garbage introduced by Flash.
						// An SOI marker follows. Skip this.
						[fh skipBytes:2];
					}
					else
					{
						// Other markers. Copy, and parse if known.
						int len=[fh readUInt16BE];
						[header writeUInt16BE:marker];
						[header writeUInt16BE:len];
						if(len>2)
						{
							uint8_t contents[len-2];
							[fh readBytes:len-2 toBuffer:contents];
							[header writeBytes:len-2 fromBuffer:contents];

							if(marker>=0xffc0&&marker<=0xffc3)
							{
								// SOFx marker, extract width and height.
								width=CSUInt16BE(&contents[3]);
								height=CSUInt16BE(&contents[1]);
							}
						}
					}
				}
			}
			else NSLog(@"Error loading SWF file: invalid JPEG data in tag %d",[parser tag]);
		}
		break;

		case SWFDefineBitsLosslessTag:
		case SWFDefineBitsLossless2Tag:
		{
			numimages++;

			[fh skipBytes:2];
			int format=[fh readUInt8];
			int width=[fh readUInt16LE];
			int height=[fh readUInt16LE];

			if(format==3||format==4||format==5)
			{
				[self addEntryWithName:[NSString stringWithFormat:
				@"Image %d at frame %d.png",numimages,[parser frame]]
				losslessFormat:format width:width height:height alpha:tag==SWFDefineBitsLossless2Tag
				offset:[fh offsetInFile] length:[parser tagBytesLeft]];
			}
			else [self reportInterestingFileWithReason:@"Unsupported lossless format %d",format];
		}
		break;

		case SWFDefineSoundTag:
		{
			numsounds++;

			[fh skipBytes:2];

			int flags=[fh readUInt8];
			int format=flags>>4;
			if(format==2)
			{
				// MP3 audio.
				[fh skipBytes:4]; //uint32_t numsamples=[fh readUInt32LE];

				[self addEntryWithName:[NSString stringWithFormat:
				@"Sound %d at frame %d.mp3",numsounds,[parser frame]]
				offset:[fh offsetInFile] length:[parser tagBytesLeft]];
			}
			else if(format==0||format==3)
			{
				// Uncompresed audio. Assumes format 0 is little-endian.
				// Add a WAV header.

				[fh skipBytes:4]; //uint32_t numsamples=[fh readUInt32LE];

				int length=[parser tagBytesLeft];

				[self addEntryWithName:[NSString stringWithFormat:
				@"Sound %d at frame %d.wav",numsounds,[parser frame]]
				data:[self createWAVHeaderForFlags:flags length:length]
				offset:[fh offsetInFile] length:length];
			}
			else if(format==1) // ADPCM
			{
				// Not implemented yet.
			}
			else if(format==6) // Speex?
			{
				// Not implemented yet.
			}
			else [self reportInterestingFileWithReason:@"Unsupported sound format %d",format];
		}
		break;

		case SWFSoundStreamHeadTag:
		case SWFSoundStreamHead2Tag:
		{
			int flags=[fh readUInt8];
			int format=(flags>>4)&0x0f;
			if(format==2||format==0) // MP3 format - why is 0 MP3? Who knows!
			{
				mainstream=[NSMutableData data];
				[dataobjects addObject:mainstream];
			}
			else if(format==4) // Nellymoser
			{
				// Not implemented yet.
			}
			else [self reportInterestingFileWithReason:@"Unsupported stream format %d",format];
		}
		break;

		case SWFSoundStreamBlockTag:
		{
			if(laststreamframe!=[parser frame])
			{
				laststreamframe=[parser frame];
				[fh skipBytes:4];
			}
			[mainstream appendData:[fh readDataOfLength:[parser tagBytesLeft]]];
		}
		break;

		case SWFDefineSpriteTag:
		{
			[parser parseDefineSpriteTag];

			NSMutableData *substream=nil;
			int lastsubframe=-1;

			int tag;
			while((tag=[parser nextSubTag]) && [self shouldKeepParsing])
			switch(tag)
			{
				case SWFSoundStreamHeadTag:
				case SWFSoundStreamHead2Tag:
				{
					int flags=[fh readUInt8];
					int format=(flags>>4)&0x0f;
					if(format==2||format==0) // MP3 format - why is 0 MP3? Who knows!
					{
						substream=[NSMutableData data];
						[dataobjects addObject:substream];
					}
					else if(format==4) // Nellymoser
					{
						// Not implemented yet.
					}
					else [self reportInterestingFileWithReason:@"Unsupported stream format %d",format];
				}
				break;

				case SWFSoundStreamBlockTag:
				{
					if(lastsubframe!=[parser subFrame])
					{
						lastsubframe=[parser subFrame];
						[fh skipBytes:4];
					}
					[substream appendData:[fh readDataOfLength:[parser subTagBytesLeft]]];
				}
				break;
			}

			if(substream && [substream length])
			{
				numstreams++;

				[self addEntryWithName:[NSString stringWithFormat:
				@"Stream %d at frame %d.mp3",numstreams,[parser frame]]
				data:substream];
			}
		}
		break;
	}

	if(mainstream && [mainstream length])
	{
		[self addEntryWithName:[NSString stringWithFormat:@"Stream.mp3"]
		data:mainstream];
	}
}




-(NSData *)createWAVHeaderForFlags:(int)flags length:(int)length
{
	int samplerate,bitsperchannel,numchannels;

	switch((flags>>2)&0x03)
	{
		case 0: samplerate=5512; break; // 5.5125 kHz - what.
		case 1: samplerate=11025; break;
		case 2: samplerate=22050; break;
		case 3: samplerate=44100; break;
	}

	if(flags&0x02) bitsperchannel=16;
	else bitsperchannel=8;

	if(flags&0x01) numchannels=2;
	else numchannels=1;

	uint8_t header[44]=
	{
		'R','I','F','F',0x00,0x00,0x00,0x00,
		'W','A','V','E','f','m','t',' ',0x10,0x00,0x00,0x00,
		0x01,0x00, 0x00,0x00, 0x00,0x00,0x00,0x00,
		0x00,0x00,0x00,0x00,  0x00,0x00, 0x00,0x00,
		'd','a','t','a',0x00,0x00,0x00,0x00,
	};

	CSSetUInt32LE(&header[4],36+length);
	CSSetUInt16LE(&header[22],numchannels);
	CSSetUInt32LE(&header[24],samplerate);
	CSSetUInt32LE(&header[28],samplerate*numchannels*bitsperchannel/8);
	CSSetUInt16LE(&header[32],numchannels*bitsperchannel/8);
	CSSetUInt16LE(&header[34],bitsperchannel);
	CSSetUInt32LE(&header[40],length);

	return [NSData dataWithBytes:header length:sizeof(header)];
}




-(void)addEntryWithName:(NSString *)name data:(NSData *)data
{
	NSUInteger index=[dataobjects indexOfObjectIdenticalTo:data];
	if(index==NSNotFound)
	{
		index=[dataobjects count];
		[dataobjects addObject:data];
	}

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithString:name],XADFileNameKey,
		[NSNumber numberWithLongLong:[data length]],XADFileSizeKey,
		[self XADStringWithString:[parser isCompressed]?@"Zlib":@"None"],XADCompressionNameKey,
		[NSNumber numberWithInt:index],@"SWFDataIndex",
	nil];
	[self addEntryWithDictionary:dict];
}

-(void)addEntryWithName:(NSString *)name
offset:(off_t)offset length:(off_t)length
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithString:name],XADFileNameKey,
		[NSNumber numberWithLongLong:length],XADFileSizeKey,
		[NSNumber numberWithLongLong:length],@"SWFDataLength",
		[NSNumber numberWithLongLong:offset],@"SWFDataOffset",
		[self XADStringWithString:[parser isCompressed]?@"Zlib":@"None"],XADCompressionNameKey,
	nil];
	[self addEntryWithDictionary:dict];
}

-(void)addEntryWithName:(NSString *)name data:(NSData *)data
offset:(off_t)offset length:(off_t)length
{
	NSUInteger index=[dataobjects indexOfObjectIdenticalTo:data];
	if(index==NSNotFound)
	{
		index=[dataobjects count];
		[dataobjects addObject:data];
	}

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithString:name],XADFileNameKey,
		[NSNumber numberWithLongLong:length+[data length]],XADFileSizeKey,
		[NSNumber numberWithLongLong:length],@"SWFDataLength",
		[NSNumber numberWithLongLong:offset],@"SWFDataOffset",
		[self XADStringWithString:[parser isCompressed]?@"Zlib":@"None"],XADCompressionNameKey,
		[NSNumber numberWithInt:index],@"SWFDataIndex",
	nil];
	[self addEntryWithDictionary:dict];
}

-(void)addEntryWithName:(NSString *)name losslessFormat:(int)format
width:(int)width height:(int)height alpha:(BOOL)alpha
offset:(off_t)offset length:(off_t)length
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithString:name],XADFileNameKey,
		//[NSNumber numberWithLongLong:length],XADFileSizeKey,
		[NSNumber numberWithLongLong:length],@"SWFDataLength",
		[NSNumber numberWithLongLong:offset],@"SWFDataOffset",
		[NSNumber numberWithInt:format],@"SWFLosslessFormat",
		[NSNumber numberWithInt:width],@"SWFLosslessWidth",
		[NSNumber numberWithInt:height],@"SWFLosslessHeight",
		[NSNumber numberWithBool:alpha],@"SWFLosslessAlpha",
		[self XADStringWithString:@"Zlib"],XADCompressionNameKey,
	nil];
	[self addEntryWithDictionary:dict];
}




-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=nil;
	NSNumber *offsetnum=[dict objectForKey:@"SWFDataOffset"];
	NSNumber *lengthnum=[dict objectForKey:@"SWFDataLength"];
	if(offsetnum&&lengthnum)
	{
		handle=[[parser handle] nonCopiedSubHandleFrom:[offsetnum longLongValue]
		length:[lengthnum longLongValue]];

		NSNumber *formatnum=[dict objectForKey:@"SWFLosslessFormat"];
		if(formatnum)
		{
			return [CSMemoryHandle memoryHandleForReadingData:
			[self convertLosslessFormat:[formatnum intValue]
			width:[[dict objectForKey:@"SWFLosslessWidth"] intValue]
			height:[[dict objectForKey:@"SWFLosslessHeight"] intValue]
			alpha:[[dict objectForKey:@"SWFLosslessAlpha"] boolValue]
			handle:handle]];
		}
	}

	CSHandle *datahandle=nil;
	NSNumber *indexnum=[dict objectForKey:@"SWFDataIndex"];
	if(indexnum)
	{
		datahandle=[CSMemoryHandle memoryHandleForReadingData:
		[dataobjects objectAtIndex:[indexnum intValue]]];
	}

	if(handle&&datahandle)
	{
		return [CSMultiHandle multiHandleWithHandles:datahandle,handle,nil];
	}
	else if(datahandle)
	{
		return datahandle;
	}
	else
	{
		return handle;
	}
}

-(NSData *)convertLosslessFormat:(int)format width:(int)width height:(int)height
alpha:(BOOL)alpha handle:(CSHandle *)handle
{
	XADPNGWriter *png=[XADPNGWriter PNGWriter];

	switch(format)
	{
		case 3:
		{
			int numcolours=[handle readUInt8]+1;

			[png addIHDRWithWidth:width height:height bitDepth:8 colourType:3];

			CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:handle];
			if(alpha)
			{
				uint8_t palette[4*numcolours];
				[zh readBytes:4*numcolours toBuffer:palette];

				uint8_t plte[3*numcolours];
				uint8_t trns[numcolours];
				for(int i=0;i<numcolours;i++)
				{
					plte[3*i+0]=palette[4*i+0];
					plte[3*i+1]=palette[4*i+1];
					plte[3*i+2]=palette[4*i+2];
					trns[i]=palette[4*i+3];
				}
				[png addChunk:'PLTE' bytes:plte length:3*numcolours];
				[png addChunk:'tRNS' bytes:trns length:numcolours];
			}
			else
			{
				uint8_t plte[3*numcolours];
				[zh readBytes:3*numcolours toBuffer:plte];
				[png addChunk:'PLTE' bytes:plte length:3*numcolours];
			}

			[png startIDAT];
			int bytesperrow=(width+3)&~3;
			for(int y=0;y<height;y++)
			{
				uint8_t row[bytesperrow];
				[zh readBytes:bytesperrow toBuffer:row];
				[png addIDATRow:row];
			}
			[png endIDAT];
		}
		break;

		case 4:
		{
			CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:handle];

			[png addIHDRWithWidth:width height:height bitDepth:8 colourType:2];
			[png startIDAT];

			int bytesperrow=(2*width+3)&~3;
			for(int y=0;y<height;y++)
			{
				uint8_t row[bytesperrow];
				uint8_t rgbrow[3*width];
				[zh readBytes:bytesperrow toBuffer:row];

				for(int x=0;x<width;x++)
				{
					uint16_t rgb=CSUInt16BE(&row[2*x]);
					uint8_t r=(((rgb>>10)&0x1f)*0x21)>>2;
					uint8_t g=(((rgb>>5)&0x1f)*0x21)>>2;
					uint8_t b=(((rgb>>0)&0x1f)*0x21)>>2;

					rgbrow[3*x+0]=r;
					rgbrow[3*x+1]=g;
					rgbrow[3*x+2]=b;
				}

				[png addIDATRow:rgbrow];
			}

			[png endIDAT];
		}
		break;

		case 5:
		{
			CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:handle];

			if(alpha) [png addIHDRWithWidth:width height:height bitDepth:8 colourType:6];
			else [png addIHDRWithWidth:width height:height bitDepth:8 colourType:2];

			[png startIDAT];

			int bytesperrow=width*4;
			for(int y=0;y<height;y++)
			{
				uint8_t row[bytesperrow];
				[zh readBytes:bytesperrow toBuffer:row];

				if(alpha)
				{
					for(int x=0;x<width;x++)
					{
						uint8_t a=row[4*x+0],r=row[4*x+1],g=row[4*x+2],b=row[4*x+3];
						row[4*x+0]=r;
						row[4*x+1]=g;
						row[4*x+2]=b;
						row[4*x+3]=a;
					}
				}
				else
				{
					for(int x=0;x<width;x++)
					{
						uint8_t r=row[4*x+1],g=row[4*x+2],b=row[4*x+3];
						row[3*x+0]=r;
						row[3*x+1]=g;
						row[3*x+2]=b;
					}
				}

				[png addIDATRow:row];
			}

			[png endIDAT];
		}
		break;

		case -1: // Special alpha channel format.
		{
			[png addIHDRWithWidth:width height:height bitDepth:8 colourType:0];

			CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:handle];

			[png startIDAT];
			int bytesperrow=width;
			for(int y=0;y<height;y++)
			{
				uint8_t row[bytesperrow];
				// Kludge: Some alpha channels end (one byte) early.
				// Just zero the buffer and accept short reads to work around it.
				memset(row,0,sizeof(row));
				[zh readAtMost:bytesperrow toBuffer:row];
				[png addIDATRow:row];
			}
			[png endIDAT];
		}
		break;
	}

	[png addIEND];

	return [png data];
}

-(NSString *)formatName { return @"SWF"; }

@end

