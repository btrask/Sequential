#import "XADLBRParser.h"
#import "XADSqueezeParser.h"
#import "XADSqueezeHandle.h"
#import "XADCrunchParser.h"
#import "XADCrunchHandles.h"
#import "XADCRCHandle.h"
#import "NSDateXAD.h"

@implementation XADLBRParser

+(int)requiredHeaderSize { return 128; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<128) return NO;

	if(bytes[0]!=0) return NO;

	for(int i=1;i<12;i++) if(bytes[i]!=' ') return NO;

	if(bytes[12]!=0) return NO;
	if(bytes[13]!=0) return NO;

	for(int i=26;i<32;i++) if(bytes[i]!=0) return NO;

	int sectors=CSUInt16LE(&bytes[14]);
	if(sectors==0) return NO;

	// Check CRC if it exists, and there is enough data to do so.
	int correctcrc=CSUInt16LE(&bytes[16]);
	int size=sectors*128;
	if(correctcrc && size<=length)
	{
		int crc=0;
		crc=XADCalculateCRC(crc,&bytes[0],16,XADCRCReverseTable_1021);
		crc=XADCRC(crc,0,XADCRCReverseTable_1021);
		crc=XADCRC(crc,0,XADCRCReverseTable_1021);
		crc=XADCalculateCRC(crc,&bytes[18],size-18,XADCRCReverseTable_1021);
		if(XADUnReverseCRC16(crc)!=correctcrc) return NO;
	}

	return YES;
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:14];
	int numsectors=[fh readUInt16LE];
	int numentries=numsectors*4-1;
	[fh skipBytes:16];

	for(int i=0;i<numentries;i++)
	{
		int status=[fh readUInt8];
		if(status!=0)
		{
			[fh skipBytes:31];
			continue;
		}

		uint8_t namebuf[11];
		[fh readBytes:11 toBuffer:namebuf];

		NSMutableData *data=[NSMutableData data];

		int namelength=8;
		while(namelength>1 && namebuf[namelength-1]==' ') namelength--;
		[data appendBytes:&namebuf[0] length:namelength];

		[data appendBytes:(uint8_t []){'.'} length:1];

		int extlength=3;
		while(extlength>1 && namebuf[extlength+7]==' ') extlength--;
		[data appendBytes:&namebuf[8] length:extlength];

		BOOL lookslikesqueeze=(namebuf[9]=='q' || namebuf[9]=='Q');
		BOOL lookslikecrunch=(namebuf[9]=='z' || namebuf[9]=='Z');

		int index=[fh readUInt16LE];
		int length=[fh readUInt16LE];
		int crc=[fh readUInt16LE];
		int creationdate=[fh readUInt16LE];
		int modificationdate=[fh readUInt16LE];
		int creationtime=[fh readUInt16LE];
		int modificationtime=[fh readUInt16LE];
		int padding=[fh readUInt8];

		int filestart=index*128;
		int filesize=length*128-padding;
	
		if(!modificationdate)
		{
			modificationdate=creationdate;
			modificationtime=creationtime;
		}

		[fh skipBytes:5];
		off_t currpos=[fh offsetInFile];

		NSMutableDictionary *dict=nil;

		if(lookslikesqueeze)
		{
			[fh seekToFileOffset:filestart];

			dict=[XADSqueezeParser parseWithHandle:fh endOffset:filestart+filesize parser:self];
			if(dict)
			{
				[dict setObject:[NSNumber numberWithBool:YES] forKey:@"LBRIsSqueeze"];
				[dict setObject:[NSNumber numberWithLongLong:length*128] forKey:XADCompressedSizeKey];
			}
		}
		else if(lookslikecrunch)
		{
			[fh seekToFileOffset:filestart];

			dict=[XADCrunchParser parseWithHandle:fh endOffset:filestart+filesize parser:self];
			if(dict)
			{
				[dict setObject:[NSNumber numberWithBool:YES] forKey:@"LBRIsCrunch"];
				[dict setObject:[NSNumber numberWithLongLong:length*128] forKey:XADCompressedSizeKey];
			}
		}

		if(!dict)
		{
			dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				[self XADPathWithData:data separators:XADNoPathSeparator],XADFileNameKey,
				[NSNumber numberWithLongLong:filesize],XADFileSizeKey,
				[NSNumber numberWithLongLong:length*128],XADCompressedSizeKey,
				[NSNumber numberWithLongLong:filesize],XADDataLengthKey,
				[NSNumber numberWithLongLong:filestart],XADDataOffsetKey,
				[NSNumber numberWithInt:crc],@"LBRCRC16",
			nil];
		}

		if(creationdate)
		[dict setObject:[NSDate XADDateWithCPMDate:creationdate
		time:creationtime] forKey:XADCreationDateKey];

		if(modificationdate)
		[dict setObject:[NSDate XADDateWithCPMDate:modificationdate
		time:modificationtime] forKey:XADLastModificationDateKey];

		[self addEntryWithDictionary:dict];
		[fh seekToFileOffset:currpos];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	NSNumber *squeezenum=[dict objectForKey:@"LBRIsSqueeze"];
	NSNumber *crunchnum=[dict objectForKey:@"LBRIsCrunch"];

	if(squeezenum && [squeezenum boolValue])
	{
		handle=[XADSqueezeParser handleForEntryWithDictionary:dict
		wantChecksum:checksum handle:handle];
	}
	else if(crunchnum && [crunchnum boolValue])
	{
		handle=[XADCrunchParser handleForEntryWithDictionary:dict
		wantChecksum:checksum handle:handle];
	}
	else
	{
		off_t length=[[dict objectForKey:XADDataLengthKey] intValue];
		NSNumber *crc=[dict objectForKey:@"LBRCRC16"];

		if(checksum&&crc) handle=[XADCRCHandle CCITTCRC16HandleWithHandle:handle
		length:length correctCRC:[crc intValue] conditioned:NO];
	}

	return handle;
}

-(NSString *)formatName { return @"LBR"; }

@end




