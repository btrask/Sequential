#import "PDFStream.h"
#import "PDFParser.h"
#import "PDFEncryptionHandler.h"

#import "CCITTHandle.h"
#import "LZWHandle.h"

#import "../CSZlibHandle.h"
#import "../CSMemoryHandle.h"
#import "../CSMultiHandle.h"



@implementation PDFStream

-(id)initWithDictionary:(NSDictionary *)dictionary fileHandle:(CSHandle *)filehandle
offset:(off_t)offset reference:(PDFObjectReference *)reference parser:(PDFParser *)owner
{
	if(self=[super init])
	{
		dict=[dictionary retain];
		fh=[filehandle retain];
		offs=offset;
		ref=[reference retain];
		parser=owner;
	}
	return self;
}

-(void)dealloc
{
	[dict release];
	[fh release];
	[ref release];
	[super dealloc];
}




-(NSDictionary *)dictionary { return dict; }

-(PDFObjectReference *)reference { return ref; }



-(BOOL)isImage
{
	NSString *type=[dict objectForKey:@"Type"];
	NSString *subtype=[dict objectForKey:@"Subtype"];
	return (!type||[type isEqual:@"XObject"])&&subtype&&[subtype isEqual:@"Image"]; // kludge for broken Ghostscript PDFs
}

-(BOOL)isJPEGImage
{
	return [[self finalFilter] isEqual:@"DCTDecode"]&&[self imageBitsPerComponent]==8;
}

-(BOOL)isJPEG2000Image
{
	return [[self finalFilter] isEqual:@"JPXDecode"];
}




-(int)imageWidth
{
	return [dict intValueForKey:@"Width" default:0];
}

-(int)imageHeight
{
	return [dict intValueForKey:@"Height" default:0];
}

-(int)imageBitsPerComponent
{
	if([dict boolValueForKey:@"ImageMask" default:NO]) return 1;

	return [dict intValueForKey:@"BitsPerComponent" default:0];
}




-(int)imageType
{
	if([dict boolValueForKey:@"ImageMask" default:NO]) return PDFMaskImageType;

	id colourspace=[dict objectForKey:@"ColorSpace"];
	return [self _typeForColourSpaceObject:colourspace];
}

-(int)numberOfImageComponents
{
	if([dict boolValueForKey:@"ImageMask" default:NO]) return 1;

	id colourspace=[dict objectForKey:@"ColorSpace"];
	return [self _numberOfComponentsForColourSpaceObject:colourspace];
}

-(NSString *)imageColourSpaceName
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	return [self _nameForColourSpaceObject:colourspace];
}




-(int)imagePaletteType
{
	id colourspace=[self _paletteColourSpaceObject];
	if(!colourspace) return PDFUnsupportedImageType;
	return [self _typeForColourSpaceObject:colourspace];
}

-(int)numberOfImagePaletteComponents
{
	id colourspace=[self _paletteColourSpaceObject];
	if(!colourspace) return 0;
	return [self _numberOfComponentsForColourSpaceObject:colourspace];
}

-(NSString *)imagePaletteColourSpaceName
{
	id colourspace=[self _paletteColourSpaceObject];
	if(!colourspace) return nil;
	return [self _nameForColourSpaceObject:colourspace];
}

-(int)numberOfImagePaletteColours
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	if(!colourspace) return 0;

	if(![colourspace isKindOfClass:[NSArray class]]) return 0;
	if([colourspace count]!=4) return 0;
	if(![[colourspace objectAtIndex:0] isEqual:@"Indexed"]) return 0;

	return [[colourspace objectAtIndex:2] intValue]+1;
}

-(NSData *)imagePaletteData
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	if(!colourspace) return nil;

	if(![colourspace isKindOfClass:[NSArray class]]) return nil;
	if([colourspace count]!=4) return nil;
	if(![[colourspace objectAtIndex:0] isEqual:@"Indexed"]) return nil;

	int numcomponents=[self numberOfImagePaletteComponents];
	int numcolours=[self numberOfImagePaletteColours];

	id palette=[colourspace objectAtIndex:3];

	NSData *data;
	if([palette isKindOfClass:[PDFStream class]])
	{
		data=[[palette handle] readDataOfLength:numcomponents*numcolours];
		if(!data) return nil;
	}
	else if([palette isKindOfClass:[PDFString class]])
	{
		data=[palette data];
		if([data length]<numcomponents*numcolours) return nil;
	}
	else
	{
		return nil;
	}

	return data;
}

-(id)_paletteColourSpaceObject
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	if(!colourspace) return nil;

	if(![colourspace isKindOfClass:[NSArray class]]) return nil;
	if([colourspace count]!=4) return nil;
	if(![[colourspace objectAtIndex:0] isEqual:@"Indexed"]) return nil;

	return [colourspace objectAtIndex:1];
}




-(int)_typeForColourSpaceObject:(id)colourspace
{
	NSString *name;

	if([colourspace isKindOfClass:[NSString class]])
	{
		name=colourspace;
	}
	else if([colourspace isKindOfClass:[NSArray class]])
	{
		int count=[colourspace count];
		if(count<1) return PDFUnsupportedImageType;

		name=[colourspace objectAtIndex:0];
		if([name isEqual:@"ICCBased"])
		{
			if(count<2) return PDFUnsupportedImageType;

			PDFStream *def=[colourspace objectAtIndex:1];
			if(![def isKindOfClass:[PDFStream class]]) return PDFUnsupportedImageType;

			NSString *alternate=[[def dictionary] objectForKey:@"Alternate"];
			if(alternate)
			{
				name=alternate;
			}
			else
			{
				int n=[[def dictionary] intValueForKey:@"N" default:0];
				switch(n)
				{
					case 1: return PDFGrayImageType;
					case 3: return PDFRGBImageType;
					case 4: return PDFCMYKImageType;
					default: return PDFUnsupportedImageType;
				}
			}
		}
	}
	else
	{
		return PDFUnsupportedImageType;
	}

	if([name isEqual:@"DeviceGray"]||[name isEqual:@"CalGray"]) return PDFGrayImageType;
	if([name isEqual:@"DeviceRGB"]||[name isEqual:@"CalRGB"]) return PDFRGBImageType;
	if([name isEqual:@"Indexed"]) return PDFIndexedImageType;
	if([name isEqual:@"DeviceCMYK"]) return PDFCMYKImageType;
	if([name isEqual:@"Separation"]) return PDFSeparationImageType;

	return PDFUnsupportedImageType;
}

-(int)_numberOfComponentsForColourSpaceObject:(id)colourspace
{
	NSString *name;

	if([colourspace isKindOfClass:[NSString class]])
	{
		name=colourspace;
	}
	else if([colourspace isKindOfClass:[NSArray class]])
	{
		int count=[colourspace count];
		if(count<1) return 0;

		name=[colourspace objectAtIndex:0];
		if([name isEqual:@"ICCBased"])
		{
			if(count<2) return 0;

			PDFStream *def=[colourspace objectAtIndex:1];
			if(![def isKindOfClass:[PDFStream class]]) return 0;

			return [[def dictionary] intValueForKey:@"N" default:0];
		}
	}
	else
	{
		return 0;
	}

	if([name isEqual:@"DeviceGray"]||[name isEqual:@"CalGray"]) return 1;
	if([name isEqual:@"DeviceRGB"]||[name isEqual:@"CalRGB"]) return 3;
	if([name isEqual:@"Indexed"]) return 1;
	if([name isEqual:@"DeviceCMYK"]) return 4;
	if([name isEqual:@"Separation"]) return 1;

	return 0;
}

-(NSString *)_nameForColourSpaceObject:(id)colourspace
{
	if([colourspace isKindOfClass:[NSString class]])
	{
		return colourspace;
	}
	else if([colourspace isKindOfClass:[NSArray class]])
	{
		int count=[colourspace count];
		if(count<1) return nil;

		return [colourspace objectAtIndex:0];
	}
	else return nil;
}




-(NSData *)imageICCColourProfile
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	return [self _ICCColourProfileForColourSpaceObject:colourspace];
}

-(NSData *)_ICCColourProfileForColourSpaceObject:(id)colourspace
{
	if([colourspace isKindOfClass:[NSString class]])
	{
		return nil; // TODO: Handle lab?
	}
	else if([colourspace isKindOfClass:[NSArray class]])
	{
		int count=[colourspace count];
		if(count<1) return nil;

		NSString *name=[colourspace objectAtIndex:0];

		if([name isEqual:@"ICCBased"])
		{
			if(count!=2) return nil;
			id stream=[colourspace objectAtIndex:1];
			if([stream isKindOfClass:[PDFStream class]]) return [[stream handle] remainingFileContents];
			else return nil;
		}
		else if([name isEqual:@"CalRGB"])
		{
			// TODO: Generate a profile.
			return nil;
		}
		else if([name isEqual:@"CalGray"])
		{
			// TODO: Generate a profile.
			return nil;
		}
		else if([name isEqual:@"Indexed"])
		{
			if(count!=4) return nil;
			id palettespace=[colourspace objectAtIndex:1];
			return [self _ICCColourProfileForColourSpaceObject:palettespace];
		}
		else if([name isEqual:@"Separation"])
		{
			// TODO: Generate an inverted gray profile.
			return nil;
		}
		else
		{
			return nil;
		}
	}
	else return nil;
}




-(NSString *)imageSeparationName
{
	id colourspace=[dict objectForKey:@"ColorSpace"];
	if(!colourspace) return nil;

	if(![colourspace isKindOfClass:[NSArray class]]) return nil;

	int count=[colourspace count];
	if(count<2) return nil;

	NSString *name=[colourspace objectAtIndex:0];
	if(![name isEqual:@"Separation"]) return nil;

	return [colourspace objectAtIndex:1];
}

-(NSArray *)imageDecodeArray
{
	id decode=[dict objectForKey:@"Decode"];
	if(!decode) return nil;

	if(![decode isKindOfClass:[NSArray class]]) return nil;

	int n=[self numberOfImageComponents];
	if([decode count]!=n*2) return nil;

	return decode;
}



-(BOOL)hasMultipleFilters
{
	id filter=[dict objectForKey:@"Filter"];

	if(!filter) return NO;
	else if([filter isKindOfClass:[NSArray class]]) return [filter count]>1;
	else return NO;
}

-(NSString *)finalFilter
{
	id filter=[dict objectForKey:@"Filter"];

	if(!filter) return NO;
	else if([filter isKindOfClass:[NSArray class]]) return [filter lastObject];
	else return filter;
}




-(CSHandle *)rawHandle
{
	return [fh subHandleFrom:offs length:[dict intValueForKey:@"Length" default:0]];
}

-(CSHandle *)handle
{
	return [self handleExcludingLast:NO decrypted:YES];
}

-(CSHandle *)JPEGHandle
{
	return [self handleExcludingLast:YES decrypted:YES];
}

-(CSHandle *)handleExcludingLast:(BOOL)excludelast
{
	return [self handleExcludingLast:excludelast decrypted:YES];
}

-(CSHandle *)handleExcludingLast:(BOOL)excludelast decrypted:(BOOL)decrypted
{
	CSHandle *handle;
	PDFEncryptionHandler *encryption=[parser encryptionHandler];

	if(encryption && decrypted) handle=[encryption decryptStream:self];
	else handle=[self rawHandle];

	NSArray *filter=[dict arrayForKey:@"Filter"];
	NSArray *decodeparms=[dict arrayForKey:@"DecodeParms"];

	if(filter)
	{
		int count=[filter count];
		if(excludelast) count--;

		for(int i=0;i<count;i++)
		{
			handle=[self handleForFilterName:[filter objectAtIndex:i]
			decodeParms:[decodeparms objectAtIndex:i] parentHandle:handle];
			if(!handle) return nil;
		}
	}

	return handle;
}

-(CSHandle *)handleForFilterName:(NSString *)filtername decodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent
{
	if(!decodeparms) decodeparms=[NSDictionary dictionary];

	if([filtername isEqual:@"FlateDecode"])
	{
		return [self predictorHandleForDecodeParms:decodeparms
		parentHandle:[CSZlibHandle zlibHandleWithHandle:parent]];
	}
	else if([filtername isEqual:@"CCITTFaxDecode"])
	{
		int k=[decodeparms intValueForKey:@"K" default:0];
		int cols=[decodeparms intValueForKey:@"Columns" default:1728];
		int white=[decodeparms intValueForKey:@"BlackIs1" default:NO]?0:1;

		if(k==0) return [[[CCITTFaxT41DHandle alloc] initWithHandle:parent columns:cols white:white] autorelease];
		else if(k>0) return nil;
//		else if(k>0) return [[[CCITTFaxT42DHandle alloc] initWithHandle:parent columns:cols white:white] autorelease];
		else return [[[CCITTFaxT6Handle alloc] initWithHandle:parent columns:cols white:white] autorelease];
	}
	else if([filtername isEqual:@"LZWDecode"])
	{
		int early=[decodeparms intValueForKey:@"EarlyChange" default:1];
		return [self predictorHandleForDecodeParms:decodeparms
		parentHandle:[[[LZWHandle alloc] initWithHandle:parent earlyChange:early] autorelease]];
	}
	else if([filtername isEqual:@"ASCII85Decode"])
	{
		return [[[PDFASCII85Handle alloc] initWithHandle:parent] autorelease];
	}
	else if([filtername isEqual:@"Crypt"])
	{
		return parent; // Handled elsewhere.
	}

	return nil;
}

-(CSHandle *)predictorHandleForDecodeParms:(NSDictionary *)decodeparms parentHandle:(CSHandle *)parent
{
	NSNumber *predictor=[decodeparms objectForKey:@"Predictor"];
	if(!predictor) return parent;

	int pred=[predictor intValue];
	if(pred==1) return parent;

	NSNumber *columns=[decodeparms objectForKey:@"Columns"];
	NSNumber *colors=[decodeparms objectForKey:@"Colors"];
	NSNumber *bitspercomponent=[decodeparms objectForKey:@"BitsPerComponent"];

	int cols=columns?[columns intValue]:1;
	int comps=colors?[colors intValue]:1;
	int bpc=bitspercomponent?[bitspercomponent intValue]:8;

	if(pred==2) return [[[PDFTIFFPredictorHandle alloc] initWithHandle:parent columns:cols components:comps bitsPerComponent:bpc] autorelease];
	else if(pred>=10&&pred<=15) return [[[PDFPNGPredictorHandle alloc] initWithHandle:parent columns:cols components:comps bitsPerComponent:bpc] autorelease];
	else [NSException raise:@"PDFStreamPredictorException" format:@"PDF Predictor %d not supported",pred];
	return nil;
}





-(NSString *)description { return [NSString stringWithFormat:@"<Stream with dictionary: %@>",dict]; }

@end




@implementation PDFASCII85Handle

-(void)resetByteStream
{
	finalbytes=0;
}

static uint8_t ASCII85NextByte(CSInputBuffer *input)
{
	uint8_t b;
	do { b=CSInputNextByte(input); }
	while(!((b>=33&&b<=117)||b=='z'||b=='~'));
	return b;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=pos&3;
	if(byte==0)
	{
		uint8_t c1=ASCII85NextByte(input);

		if(c1=='z') val=0;
		else if(c1=='~') CSByteStreamEOF(self);
		else
		{
			uint8_t c2,c3,c4,c5;

			c2=ASCII85NextByte(input);
			if(c2!='~')
			{
				c3=ASCII85NextByte(input);
				if(c3!='~')
				{
					c4=ASCII85NextByte(input);
					if(c4!='~')
					{
						c5=ASCII85NextByte(input);
						if(c5=='~') { c5=33; finalbytes=3; }
					}
					else { c4=c5=33; finalbytes=2; }
				}
				else { c3=c4=c5=33; finalbytes=1; }
			}
			else CSByteStreamEOF(self);

			val=((((c1-33)*85+c2-33)*85+c3-33)*85+c4-33)*85+c5-33;
		}
		return val>>24;
	}
	else
	{
		if(finalbytes&&byte>=finalbytes) CSByteStreamEOF(self);
		return val>>24-byte*8;
	}
}

@end




@implementation PDFTIFFPredictorHandle

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp
{
	if(self=[super initWithHandle:handle])
	{
		cols=columns;
		comps=components;
		bpc=bitspercomp;
		if(bpc!=8) [NSException raise:@"PDFTIFFPredictorException" format:@"Bit depth %d not supported for TIFF predictor",bpc];
		if(comps>4||comps<1) [NSException raise:@"PDFTIFFPredictorException" format:@"Color count %d not supported for TIFF predictor",bpc];
	}
	return self;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(bpc==8)
	{
		int comp=pos%comps;
		if((pos/comps)%cols==0) prev[comp]=CSInputNextByte(input);
		else prev[comp]+=CSInputNextByte(input);
		return prev[comp];
	}
	return 0;
}

@end



static inline int iabs(int a) { return a>=0?a:-a; }

@implementation PDFPNGPredictorHandle

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns
components:(int)components bitsPerComponent:(int)bitspercomp
{
	if(self=[super initWithHandle:handle])
	{
		cols=columns;
		comps=components;
		bpc=bitspercomp;
		if(bpc<8) comps=1;
		if(bpc>8) [NSException raise:@"PDFPNGPredictorException" format:@"Bit depth %d not supported for PNG predictor",bpc];

		prevbuf=malloc(cols*comps+2*comps);
	}
	return self;
}

-(void)dealloc
{
	free(prevbuf);
	[super dealloc];
}

-(void)resetByteStream
{
	memset(prevbuf,0,cols*comps+2*comps);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(bpc<=8)
	{
		int row=pos/(cols*comps);
		int col=pos%(cols*comps);
		int buflen=cols*comps+2*comps;
		int bufoffs=((col-comps*row)%buflen+buflen)%buflen;

		if(col==0)
		{
			type=CSInputNextByte(input);
			for(int i=0;i<comps;i++) prevbuf[(i+cols*comps+comps+bufoffs)%buflen]=0;
		}

		int x=CSInputNextByte(input);
		int a=prevbuf[(cols*comps+comps+bufoffs)%buflen];
		int b=prevbuf[(comps+bufoffs)%buflen];
		int c=prevbuf[bufoffs];
		int val;

		switch(type)
		{
			case 0: val=x; break;
			case 1: val=x+a; break;
			case 2: val=x+b; break;
			case 3: val=x+(a+b)/2; break;
			case 4:
			{
				int p=a+b-c;
				int pa=iabs(p-a);
				int pb=iabs(p-b);
				int pc=iabs(p-c);

				if(pa<=b&&pa<=pc) val=pa;
				else if(pb<=pc) val=pb;
				else val=pc;
			}
			break;
		}

		prevbuf[bufoffs]=val;
		return val;
	}
	return 0;
}

@end

