#import "XADDiskDoublerParser.h"
#import "XADCompressHandle.h"
#import "XADCompactProRLEHandle.h"
#import "XADCompactProLZHHandle.h"
#import "XADStuffItHuffmanHandle.h"
#import "XADXORHandle.h"
#import "XADCRCHandle.h"
#import "XADChecksumHandle.h"
#import "NSDateXAD.h"

@implementation XADDiskDoublerParser

+(int)requiredHeaderSize
{
	return 124;
}

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	int length=[data length];
	const uint8_t *bytes=[data bytes];

	if(length>=84)
	{
		if(CSUInt32BE(bytes)==0xabcd0054)
		if(XADCalculateCRC(0,bytes,82,XADCRCReverseTable_1021)==
		XADUnReverseCRC16(CSUInt16BE(bytes+82))) return YES;
	}

	if(length>=78)
	{
		if(CSUInt32BE(bytes)=='DDAR')
		if(XADCalculateCRC(0,bytes,76,XADCRCReverseTable_1021)==
		XADUnReverseCRC16(CSUInt16BE(bytes+76))) return YES;
	}

	if(length>=62)
	{
		if(CSUInt32BE(bytes)=='DDA2')
		if(XADCalculateCRC(0,bytes,60,XADCRCReverseTable_1021)==
		XADUnReverseCRC16(CSUInt16BE(bytes+60))) return YES;
	}

	return NO;
}

-(void)parse
{
	[self setIsMacArchive:YES];

	CSHandle *fh=[self handle];
	uint32_t magic=[fh readID];

	if(magic==0xabcd0054) [self parseFileHeaderWithHandle:fh name:[self XADPathWithUnseparatedString:[self name]]];
	else if(magic=='DDAR') [self parseArchive];
	else if(magic=='DDA2') [self parseArchive2];
}

// TODO: look at memory and refcount issues for automatic pool upgrade

-(void)parseArchive
{
	CSHandle *fh=[self handle];
	[fh skipBytes:74];

	XADPath *currdir=[self XADPath];

	while([self shouldKeepParsing])
	{
		uint32_t magic;
		@try { magic=[fh readID]; }
		@catch(id e) { break; }
		if(magic!='DDAR') [XADException raiseIllegalDataException];

		[fh skipBytes:4];

		int namelen=[fh readUInt8];
		if(namelen>63) namelen=63;
		uint8_t namebuf[63];
		[fh readBytes:63 toBuffer:namebuf];

		int isdir=[fh readUInt8];
		int enddir=[fh readUInt8];
		uint32_t datasize=[fh readUInt32BE];
		uint32_t rsrcsize=[fh readUInt32BE];
		uint32_t creation=[fh readUInt32BE];
		uint32_t modification=[fh readUInt32BE];
		uint32_t type=[fh readUInt32BE];
		uint32_t creator=[fh readUInt32BE];
		int finderflags=[fh readUInt16BE];
		[fh skipBytes:18];
		int datacrc=[fh readUInt16BE];
		int rsrccrc=[fh readUInt16BE];
		[fh skipBytes:2];

		XADPath *name=[currdir pathByAppendingPathComponent:[self XADStringWithBytes:namebuf length:namelen]];

		off_t start=[fh offsetInFile];
		uint32_t totalsize=0;

		if(enddir)
		{
			currdir=[currdir pathByDeletingLastPathComponent];
		}
		else if(isdir)
		{
			NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
				name,XADFileNameKey,
				[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
				[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
				[NSNumber numberWithInt:finderflags],XADFinderFlagsKey, // TODO: is this valid?
				[NSNumber numberWithBool:YES],XADIsDirectoryKey,
			nil];

			[self addEntryWithDictionary:dict];
			currdir=name;
		}
		else if(finderflags&0x20)
		{
			if(datasize||!rsrcsize)
			{
				[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
					name,XADFileNameKey,
					[NSNumber numberWithUnsignedInt:datasize],XADFileSizeKey,
					[NSNumber numberWithUnsignedInt:datasize],XADCompressedSizeKey,
					[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
					[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
					[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
					[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
					[self XADStringWithString:[self nameForMethod:0]],XADCompressionNameKey,

					[NSNumber numberWithLongLong:start],XADDataOffsetKey,
					[NSNumber numberWithUnsignedInt:datasize],XADDataLengthKey,
					[NSNumber numberWithInt:0],@"DiskDoublerMethod",
					[NSNumber numberWithInt:datacrc],@"DiskDoublerCRC",
					[NSNumber numberWithInt:0],@"DiskDoublerDeltaType",
				nil]];
			}

			if(rsrcsize)
			{
				[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
					name,XADFileNameKey,
					[NSNumber numberWithUnsignedInt:rsrcsize],XADFileSizeKey,
					[NSNumber numberWithUnsignedInt:rsrcsize],XADCompressedSizeKey,
					[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
					[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
					[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
					[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
					[self XADStringWithString:[self nameForMethod:0]],XADCompressionNameKey,
					[NSNumber numberWithBool:YES],XADIsResourceForkKey,

					[NSNumber numberWithLongLong:start+datasize],XADDataOffsetKey,
					[NSNumber numberWithUnsignedInt:rsrcsize],XADDataLengthKey,
					[NSNumber numberWithInt:0],@"DiskDoublerMethod",
					[NSNumber numberWithInt:rsrccrc],@"DiskDoublerCRC",
					[NSNumber numberWithInt:0],@"DiskDoublerDeltaType",
				nil]];
			}

			totalsize=datasize+rsrcsize;
		}
		else
		{
			uint32_t filemagic=[fh readID];
			if(filemagic!=0xabcd0054) [XADException raiseIllegalDataException];

			totalsize=[self parseFileHeaderWithHandle:fh name:name]+84*2;
		}

		[fh seekToFileOffset:start+totalsize];
	}
}

-(void)parseArchive2
{
	CSHandle *fh=[self handle];
	[fh skipBytes:58];

	XADPath *currdir=[self XADPath];
	int lastdirlevel=0;

	while([self shouldKeepParsing])
	{
		off_t start=[fh offsetInFile];

		uint32_t magic=[fh readID];
		if(magic!='DDA2') [XADException raiseIllegalDataException];

		int entrytype=[fh readUInt16BE];
		if(entrytype==0xbbbb) break;

		int namelen=[fh readUInt8];
		if(namelen>31) namelen=31;
		uint8_t namebuf[31];
		[fh readBytes:31 toBuffer:namebuf];

		int dirlevel=[fh readUInt32BE]-2;
		uint32_t totalsize=[fh readUInt32BE];

		if(dirlevel<0)
		{
			[fh seekToFileOffset:start+totalsize];
			continue;
		}

		for(int i=dirlevel;i<lastdirlevel;i++) currdir=[currdir pathByDeletingLastPathComponent];
		lastdirlevel=dirlevel;

		XADPath *name=[currdir pathByAppendingPathComponent:[self XADStringWithBytes:namebuf length:namelen]];

		if(entrytype&0x8000)
		{
			if(dirlevel>=0) // ignore top-level directory
			{
				[fh skipBytes:8];
				uint32_t creation=[fh readUInt32BE];
				uint32_t modification=[fh readUInt32BE];

				NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
					name,XADFileNameKey,
					[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
					[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
					[NSNumber numberWithBool:YES],XADIsDirectoryKey,
				nil];

				[self addEntryWithDictionary:dict];
				currdir=name;
			}
		}
		else
		{
			[fh skipBytes:10];
			uint32_t filemagic=[fh readID];
			if(filemagic!=0xabcd0054) [XADException raiseIllegalDataException];

			[self parseFileHeaderWithHandle:fh name:name];
		}

		[fh seekToFileOffset:start+totalsize];
	}
}

-(uint32_t)parseFileHeaderWithHandle:(CSHandle *)fh name:(XADPath *)name
{
	uint32_t datasize=[fh readUInt32BE];
	uint32_t datacompsize=[fh readUInt32BE];
	uint32_t rsrcsize=[fh readUInt32BE];
	uint32_t rsrccompsize=[fh readUInt32BE];
	uint32_t datamethod=[fh readUInt8];
	uint32_t rsrcmethod=[fh readUInt8];
	int info1=[fh readUInt8];
	[fh skipBytes:1];
	uint32_t modification=[fh readUInt32BE];
	uint32_t creation=[fh readUInt32BE];
	uint32_t type=[fh readUInt32BE];
	uint32_t creator=[fh readUInt32BE];
	int finderflags=[fh readUInt16BE];
	[fh skipBytes:6];
	int datacrc=[fh readUInt16BE];
	int rsrccrc=[fh readUInt16BE];
	int info2=[fh readUInt8];
	[fh skipBytes:1];
	int datadelta=[fh readUInt16BE];
	int rsrcdelta=[fh readUInt16BE];
	[fh skipBytes:20];
	int datacrc2=[fh readUInt16BE];
	int rsrccrc2=[fh readUInt16BE];
	[fh skipBytes:2];

	off_t start=[fh offsetInFile];

	if(datasize||!rsrcsize)
	{
		[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
			name,XADFileNameKey,
			[NSNumber numberWithUnsignedInt:datasize],XADFileSizeKey,
			[NSNumber numberWithUnsignedInt:datacompsize],XADCompressedSizeKey,
			[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
			[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
			[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
			[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
			[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
			[self XADStringWithString:[self nameForMethod:datamethod]],XADCompressionNameKey,

			[NSNumber numberWithLongLong:start],XADDataOffsetKey,
			[NSNumber numberWithUnsignedInt:datacompsize],XADDataLengthKey,
			[NSNumber numberWithInt:datamethod],@"DiskDoublerMethod",
			[NSNumber numberWithInt:datacrc],@"DiskDoublerCRC",
			[NSNumber numberWithInt:datacrc2],@"DiskDoublerCRC2",
			[NSNumber numberWithInt:datadelta],@"DiskDoublerDeltaType",
			[NSNumber numberWithInt:info1],@"DiskDoublerInfo1",
			[NSNumber numberWithInt:info2],@"DiskDoublerInfo2",
		nil]];
	}

	if(rsrcsize)
	{
		[self addEntryWithDictionary:[NSMutableDictionary dictionaryWithObjectsAndKeys:
			name,XADFileNameKey,
			[NSNumber numberWithUnsignedInt:rsrcsize],XADFileSizeKey,
			[NSNumber numberWithUnsignedInt:rsrccompsize],XADCompressedSizeKey,
			[NSDate XADDateWithTimeIntervalSince1904:modification],XADLastModificationDateKey,
			[NSDate XADDateWithTimeIntervalSince1904:creation],XADCreationDateKey,
			[NSNumber numberWithUnsignedInt:type],XADFileTypeKey,
			[NSNumber numberWithUnsignedInt:creator],XADFileCreatorKey,
			[NSNumber numberWithInt:finderflags],XADFinderFlagsKey,
			[self XADStringWithString:[self nameForMethod:rsrcmethod]],XADCompressionNameKey,
			[NSNumber numberWithBool:YES],XADIsResourceForkKey,

			[NSNumber numberWithLongLong:start+datacompsize],XADDataOffsetKey,
			[NSNumber numberWithUnsignedInt:rsrccompsize],XADDataLengthKey,
			[NSNumber numberWithInt:rsrcmethod],@"DiskDoublerMethod",
			[NSNumber numberWithInt:rsrccrc],@"DiskDoublerCRC",
			[NSNumber numberWithInt:rsrccrc2],@"DiskDoublerCRC2",
			[NSNumber numberWithInt:rsrcdelta],@"DiskDoublerDeltaType",
			[NSNumber numberWithInt:info1],@"DiskDoublerInfo1",
			[NSNumber numberWithInt:info2],@"DiskDoublerInfo2",
		nil]];
	}

	return datacompsize+rsrccompsize;
}

-(NSString *)nameForMethod:(int)method
{
	switch(method&0x7f)
	{
		case 0: return @"None";
		case 1: return @"Compress";
		case 3: return @"RLE";
		case 4: return @"Huffman"; // packit?
		case 7: return @"LZSS";
		case 8: return @"Compact Pro"; // Compact Pro
		default: return [NSString stringWithFormat:@"Method %d",method&0x7f];
	}
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	if([dict objectForKey:XADIsDirectoryKey]) return nil;

	CSHandle *handle=[self handleAtDataOffsetForDictionary:dict];
	off_t size=[[dict objectForKey:XADFileSizeKey] longLongValue];

	int method=[[dict objectForKey:@"DiskDoublerMethod"] intValue];
	int info1=[[dict objectForKey:@"DiskDoublerInfo1"] intValue];
	int info2=[[dict objectForKey:@"DiskDoublerInfo2"] intValue];
	int correctchecksum=[[dict objectForKey:@"DiskDoublerCRC"] intValue];

	switch(method&0x7f)
	{
		case 0: // No compression
		break;

		case 1: // Compress
		{
			int xor=0;
			if(info1>=0x2a&&(info2&0x80)==0) xor=0x5a;

			int m1=[handle readUInt8]^xor;
			int m2=[handle readUInt8]^xor;
			int flags=[handle readUInt8]^xor;

			handle=[[[XADCompressHandle alloc] initWithHandle:handle length:size flags:flags] autorelease];
			if(xor) handle=[[[XADXORHandle alloc] initWithHandle:handle
			password:[NSData dataWithBytes:"Z" length:1]] autorelease];

			if(checksum)
			{
				handle=[[[XADChecksumHandle alloc] initWithHandle:handle length:size
				correctChecksum:correctchecksum-m1-m2-flags
				mask:0xffff] autorelease];
			}
		}
		break;

		case 2: // Untested!
		{
			int xor=0;
			if(info1>=0x2a&&(info2&0x80)==0) xor=0x5a;

			handle=[[[XADStuffItHuffmanHandle alloc] initWithHandle:handle length:size] autorelease];
			if(xor) handle=[[[XADXORHandle alloc] initWithHandle:handle
			password:[NSData dataWithBytes:"Z" length:1]] autorelease];

			if(checksum)
			{
				handle=[[[XADChecksumHandle alloc] initWithHandle:handle length:size
				correctChecksum:correctchecksum mask:0xffff] autorelease];
			}
		}
		break;

		case 8:
		{
			int sub=0;
			for(int i=0;i<16;i++) sub+=[handle readUInt8];

			if(sub==0) handle=[[[XADCompactProLZHHandle alloc] initWithHandle:handle blockSize:0xfff0] autorelease];
			handle=[[[XADCompactProRLEHandle alloc] initWithHandle:handle length:size] autorelease];

			if(checksum)
			{
				handle=[XADCRCHandle IBMCRC16HandleWithHandle:handle length:size
				correctCRC:correctchecksum conditioned:NO];
			}
		}
		break;

		default: return nil;
	}

	int delta=[[dict objectForKey:@"DiskDoublerDeltaType"] intValue];
	switch(delta)
	{
		case 0: break; // No delta processing

		default: return nil;
	}

	return handle;
}

-(NSString *)formatName
{
	return @"DiskDoubler";
}

@end



