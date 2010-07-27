#import "XAD7ZipParser.h"
#import "XADLZMAHandle.h"
#import "XADLZMA2Handle.h"
#import "XAD7ZipBranchHandles.h"
#import "XAD7ZipBCJ2Handle.h"
#import "XADDeflateHandle.h"
#import "XADPPMdHandles.h"
#import "XADZipShrinkHandle.h"
//#import "XADRARHandle.h"
#import "XADCompressHandle.h"
#import "XADDeltaHandle.h"
#import "XADCRCHandle.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "NSDateXAD.h"

static uint64_t ReadNumber(CSHandle *handle)
{
	uint64_t first=[handle readUInt8];
	uint64_t val=0;
	for(int i=0;i<8;i++)
	{
		if((first&(0x80>>i))==0) return val|((first&((0x80>>i)-1))<<i*8);
		val|=(uint64_t)[handle readUInt8]<<i*8;
	}

	return val;
}

static NSMutableArray *ArrayWithLength(int length)
{
	NSMutableArray *array=[NSMutableArray arrayWithCapacity:length];
	for(int i=0;i<length;i++) [array addObject:[NSMutableDictionary dictionary]];
	return array;
}

static inline void SetObjectEntryInArray(NSArray *array,int index,id obj,NSString *key)
{
	NSMutableDictionary *dict=[array objectAtIndex:index];
	if(obj) [dict setObject:obj forKey:key];
	else [dict removeObjectForKey:key];
}

static inline void SetNumberEntryInArray(NSArray *array,int index,uint64_t value,NSString *key)
{
	[[array objectAtIndex:index] setObject:[NSNumber numberWithUnsignedLongLong:value] forKey:key];
}

static inline void SkipEntry(CSHandle *handle) { [handle skipBytes:ReadNumber(handle)]; }

static void FindAttribute(CSHandle *handle,int attribute)
{
	for(;;)
	{
		uint64_t type=ReadNumber(handle);
		if(type==attribute) return;
		else if(type==0) [XADException raiseIllegalDataException];
		SkipEntry(handle);
	}
}



@implementation XAD7ZipParser

+(int)requiredHeaderSize { return 32; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=32&&bytes[0]=='7'&&bytes[1]=='z'&&bytes[2]==0xbc&&bytes[3]==0xaf
	&&bytes[4]==0x27&&bytes[5]==0x1c&&bytes[6]==0;
}


+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	NSArray *matches;

	if(matches=[name substringsCapturedByPattern:@"^(.*\\.7z)\\.([0-9]+)$" options:REG_ICASE])
	{
		return [self scanForVolumesWithFilename:name
		regex:[XADRegex regexWithPattern:[NSString stringWithFormat:@"^%@\\.([0-9]+)$",
			[[matches objectAtIndex:1] escapedPattern]] options:REG_ICASE]
		firstFileExtension:nil];
	}

	return nil;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super initWithHandle:handle name:name])
	{
		mainstreams=nil;
	}
	return self;
}

-(void)dealloc
{
	[mainstreams release];
	[super dealloc];
}

-(void)parse
{
	CSHandle *handle=[self handle];

	[handle skipBytes:12];

	off_t nextheaderoffs=[handle readUInt64LE];
	//off_t nextheadersize=[handle readUInt64LE];

	[handle seekToFileOffset:nextheaderoffs+32];

	CSHandle *fh=handle;

	for(;;)
	{
		int type=ReadNumber(fh);
		if(type==1) break; // Header
		else if(type==23) // EncodedHeader
		{
			NSDictionary *streams=[self parseStreamsForHandle:fh];
			//NSDictionary *substream=[[streams objectForKey:@"SubStreams"] objectAtIndex:0];
			//int folderindex=[[dict objectForKey:@"FolderIndex"] intValue];
			fh=[self handleForStreams:streams folderIndex:0];
		}
		else [XADException raiseIllegalDataException];
	}

	NSDictionary *additionalstreams=nil;
	NSArray *files=nil;

	for(;;)
	{
		int type=ReadNumber(fh);
		switch(type)
		{
			case 0: goto end;

			case 2: // ArchiveProperties
				for(;;)
				{
					uint64_t type=ReadNumber(fh);
					if(type==0) break;
					[fh skipBytes:ReadNumber(fh)];
				}
			break;

			case 3: // AdditionalStreamsInfo
				additionalstreams=[self parseStreamsForHandle:fh];
			break;

			case 4: // MainStreamsInfo
				mainstreams=[[self parseStreamsForHandle:fh] retain];
			break;

			case 5: // FilesInfo
				files=[self parseFilesForHandle:fh];
			break;
		}
	}

	end: 0;

	NSEnumerator *substreamenumerator=[[mainstreams objectForKey:@"SubStreams"] objectEnumerator];

	int numfiles=[files count];
	for(int i=0;i<numfiles;i++)
	{
		if(![self shouldKeepParsing]) break;

		NSMutableDictionary *file=[files objectAtIndex:i];

		if([file objectForKey:@"7zIsEmptyStream"])
		{
			if([file objectForKey:@"7zIsEmptyFile"])
			{
				[file setObject:[NSNumber numberWithInt:0] forKey:XADFileSizeKey];
				[file setObject:[NSNumber numberWithInt:0] forKey:XADCompressedSizeKey];
			}
			else
			{
				[file setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
			}
		}
		else
		{
			NSDictionary *substream=[substreamenumerator nextObject];

			NSNumber *sizeobj=[substream objectForKey:@"Size"];
			int folderindex=[[substream objectForKey:@"FolderIndex"] intValue];
			NSDictionary *folder=[[mainstreams objectForKey:@"Folders"] objectAtIndex:folderindex];
			off_t compsize=(double)[self compressedSizeForFolder:folder]*[sizeobj doubleValue]
			/(double)[self unCompressedSizeForFolder:folder];

			[file setObject:sizeobj forKey:XADFileSizeKey];
			[file setObject:sizeobj forKey:XADSolidLengthKey];
			[file setObject:[NSNumber numberWithLongLong:compsize] forKey:XADCompressedSizeKey];
			[file setObject:[substream objectForKey:@"StartOffset"] forKey:XADSolidOffsetKey];
			[file setObject:[self XADStringWithString:[self compressorNameForFolder:folder]] forKey:XADCompressionNameKey];
			[file setObject:[substream objectForKey:@"CRC"] forKey:@"7zCRC32"];

			[file setObject:[substream objectForKey:@"FolderIndex"] forKey:XADSolidObjectKey];
		}

		// UNIX permissions kludge
		uint32_t winattrs=[[file objectForKey:XADWindowsFileAttributesKey] unsignedIntValue];
		if(winattrs&0x8000)
		{
			int perms=winattrs>>16;
			[file setObject:[NSNumber numberWithInt:perms] forKey:XADPosixPermissionsKey];
			if((perms&0xf000)==0xa000) [file setObject:[NSNumber numberWithBool:YES] forKey:XADIsLinkKey];
		}

		if(![file objectForKey:@"7zIsAntiFile"]) [self addEntryWithDictionary:file];
	}
}

-(NSArray *)parseFilesForHandle:(CSHandle *)handle
{
	int numfiles=ReadNumber(handle);
	NSMutableArray *files=ArrayWithLength(numfiles);
	NSMutableArray *emptystreams=nil;

	for(;;)
	{
		int type=ReadNumber(handle);
		if(type==0) return files;

		uint64_t size=ReadNumber(handle);
		off_t next=[handle offsetInFile]+size;

		switch(type)
		{
			case 14: // EmptyStream
				[self parseBitVectorForHandle:handle array:files key:@"7zIsEmptyStream"];

				emptystreams=[NSMutableArray array];
				for(int i=0;i<numfiles;i++)
				if([[files objectAtIndex:i] objectForKey:@"7zIsEmptyStream"]) [emptystreams addObject:[files objectAtIndex:i]];
			break;

			case 15: // EmptyFile
				[self parseBitVectorForHandle:handle array:emptystreams key:@"7zIsEmptyFile"];
			break;

			case 16: // Anti
				[self parseBitVectorForHandle:handle array:emptystreams key:@"7zIsAntiFile"];
			break;

			case 17: // Names
				[self parseNamesForHandle:handle array:files];
			break;

			case 18: // CTime
				[self parseDatesForHandle:handle array:files key:XADCreationDateKey];
			break;

			case 19: // ATime
				[self parseDatesForHandle:handle array:files key:XADLastAccessDateKey];
			break;

			case 20: // MTime
				[self parseDatesForHandle:handle array:files key:XADLastModificationDateKey];
			break;

			case 21: // Attributes
				[self parseAttributesForHandle:handle array:files];
			break;

			case 22: // Comment
				NSLog(@"7z comment"); // TODO: do something with this
			break;

			case 24: // StartPos
				NSLog(@"7z startpos"); // TODO: do something with this
			break;
		}

		[handle seekToFileOffset:next];
	}
}

-(void)parseBitVectorForHandle:(CSHandle *)handle array:(NSArray *)array key:(NSString *)key
{
	NSNumber *yes=[NSNumber numberWithBool:YES];
	int num=[array count];
	int byte;
	for(int i=0;i<num;i++)
	{
		if(i%8==0) byte=[handle readUInt8];
		if(byte&(0x80>>i%8)) [[array objectAtIndex:i] setObject:yes forKey:key];
	}
}

-(NSIndexSet *)parseDefintionVectorForHandle:(CSHandle *)handle numberOfElements:(int)num
{
	if([handle readUInt8]) return [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,num)];

	NSMutableIndexSet *indexes=[NSMutableIndexSet indexSet];
	int byte;
	for(int i=0;i<num;i++)
	{
		if(i%8==0) byte=[handle readUInt8];
		if(byte&(0x80>>i%8)) [indexes addIndex:i];
	}
	return indexes;
}

-(void)parseDatesForHandle:(CSHandle *)handle array:(NSMutableArray *)array key:(NSString *)key
{
	NSIndexSet *indexes=[self parseDefintionVectorForHandle:handle numberOfElements:[array count]];

	int external=[handle readUInt8];
	if(external!=0) [XADException raiseNotSupportedException]; // TODO: figure out what to do

	for(NSInteger i=[indexes firstIndex];i!=NSNotFound;i=[indexes indexGreaterThanIndex:i])
	{
		uint32_t low=[handle readUInt32LE];
		uint32_t high=[handle readUInt32LE];
		SetObjectEntryInArray(array,i,[NSDate XADDateWithWindowsFileTimeLow:low high:high],key);
	}
}

-(void)parseCRCsForHandle:(CSHandle *)handle array:(NSMutableArray *)array
{
	NSIndexSet *indexes=[self parseDefintionVectorForHandle:handle numberOfElements:[array count]];
	for(NSInteger i=[indexes firstIndex];i!=NSNotFound;i=[indexes indexGreaterThanIndex:i])
	SetNumberEntryInArray(array,i,[handle readUInt32LE],@"CRC");
}

-(void)parseNamesForHandle:(CSHandle *)handle array:(NSMutableArray *)array
{
	int external=[handle readUInt8];
	if(external!=0) [XADException raiseNotSupportedException]; // TODO: figure out what to do

	int numnames=[array count];
	for(int i=0;i<numnames;i++)
	{
		NSMutableString *name=[NSMutableString string];

		for(;;)
		{
			uint16_t c=[handle readUInt16LE];
			if(c==0) break;
			[name appendFormat:@"%C",c];
		}

		SetObjectEntryInArray(array,i,[self XADPathWithString:name],XADFileNameKey);
	}
}

-(void)parseAttributesForHandle:(CSHandle *)handle array:(NSMutableArray *)array
{
	NSIndexSet *indexes=[self parseDefintionVectorForHandle:handle numberOfElements:[array count]];

	int external=[handle readUInt8];
	if(external!=0) [XADException raiseNotSupportedException]; // TODO: figure out what to do

	for(NSInteger i=[indexes firstIndex];i!=NSNotFound;i=[indexes indexGreaterThanIndex:i])
	SetNumberEntryInArray(array,i,[handle readUInt32LE],XADWindowsFileAttributesKey);
}



-(NSDictionary *)parseStreamsForHandle:(CSHandle *)handle
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];
	NSArray *folders=nil,*packedstreams=nil;
	for(;;)
	{
		int type=ReadNumber(handle);
		switch(type)
		{
			case 0: // End
				[dict setObject:[self collectAllSubStreamsFromFolders:folders] forKey:@"SubStreams"];
				return dict;

			case 6: // PackInfo
				packedstreams=[self parsePackedStreamsForHandle:handle];
				[dict setObject:packedstreams forKey:@"PackedStreams"];
			break;

			case 7: // CodersInfo
				folders=[self parseFoldersForHandle:handle packedStreams:packedstreams];
				[self setupDefaultSubStreamsForFolders:folders];
				[dict setObject:folders forKey:@"Folders"];
			break;

			case 8: // SubStreamsInfo
				[self parseSubStreamsInfoForHandle:handle folders:folders];
			break;

			default: [XADException raiseIllegalDataException];
		}
	}
	return nil; // can't happen
}

-(NSArray *)parsePackedStreamsForHandle:(CSHandle *)handle
{
	uint64_t dataoffset=ReadNumber(handle)+32;
	int numpackedstreams=ReadNumber(handle);
	NSMutableArray *packedstreams=ArrayWithLength(numpackedstreams);

	for(;;)
	{
		int type=ReadNumber(handle);
		switch(type)
		{
			case 0: return packedstreams;

			case 9: // Size
			{
				uint64_t total=0;
				for(int i=0;i<numpackedstreams;i++)
				{
					uint64_t size=ReadNumber(handle);
					SetNumberEntryInArray(packedstreams,i,size,@"Size");
					SetNumberEntryInArray(packedstreams,i,dataoffset+total,@"Offset");
					total+=size;
				}
			}
			break;

			case 10: // CRC
				[self parseCRCsForHandle:handle array:packedstreams];
			break;

			default: SkipEntry(handle); break;
		}
	}
	return nil; // can't happen
}

-(NSArray *)parseFoldersForHandle:(CSHandle *)handle packedStreams:(NSArray *)packedstreams
{
	FindAttribute(handle,11); // Folder

	int numfolders=ReadNumber(handle);
	NSMutableArray *folders=ArrayWithLength(numfolders);

	int external=[handle readUInt8];
	if(external!=0) [XADException raiseNotSupportedException]; // TODO: figure out how the hell to handle this

	int packedstreamindex=0;
	for(int i=0;i<numfolders;i++)
	[self parseFolderForHandle:handle dictionary:[folders objectAtIndex:i]
	packedStreams:packedstreams packedStreamIndex:&packedstreamindex];

	for(;;)
	{
		int type=ReadNumber(handle);
		switch(type)
		{
			case 0: return folders;

			case 12: // CodersUnpackSize
				for(int i=0;i<numfolders;i++)
				{
					NSArray *outstreams=[[folders objectAtIndex:i] objectForKey:@"OutStreams"];
					int numoutstreams=[outstreams count];
					for(int j=0;j<numoutstreams;j++)
					SetNumberEntryInArray(outstreams,j,ReadNumber(handle),@"Size");
				}
			break;

			case 10: // CRC
				[self parseCRCsForHandle:handle array:folders];
			break;

			default: SkipEntry(handle); break;
		}
	}

	return nil; // can't happen
}

-(void)parseFolderForHandle:(CSHandle *)handle dictionary:(NSMutableDictionary *)dictionary
packedStreams:(NSArray *)packedstreams packedStreamIndex:(int *)packedstreamindex
{
	int numcoders=ReadNumber(handle);
	NSMutableArray *instreams=[NSMutableArray array];
	NSMutableArray *outstreams=[NSMutableArray array];

	// Load coders
	for(int i=0;i<numcoders;i++)
	{
		int flags=[handle readUInt8];
		NSData *coderid=[handle readDataOfLength:flags&0x0f];

		int numinstreams=0,numoutstreams=0;
		if(flags&0x10)
		{
			numinstreams=ReadNumber(handle);
			numoutstreams=ReadNumber(handle);
		}
		else numoutstreams=numinstreams=1;

		NSData *props=nil;
		if(flags&0x20) props=[handle readDataOfLength:ReadNumber(handle)];

		NSMutableDictionary *coder=[NSMutableDictionary dictionaryWithObjectsAndKeys:
			coderid,@"ID",
			[NSNumber numberWithInt:[instreams count]],@"FirstInStreamIndex",
			[NSNumber numberWithInt:[outstreams count]],@"FirstOutStreamIndex",
			props,@"Properties",
		nil];

		for(int j=0;j<numinstreams;j++) [instreams addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
			coder,@"Coder",
			[NSNumber numberWithInt:j],@"SubIndex",
		nil]];

		for(int j=0;j<numoutstreams;j++) [outstreams addObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
			coder,@"Coder",
			[NSNumber numberWithInt:j],@"SubIndex",
		nil]];

		while(flags&0x80)
		{
			flags=[handle readUInt8];
			[handle skipBytes:flags&0x0f];
			if(flags&0x10) { ReadNumber(handle); ReadNumber(handle); }
			if(flags&0x20) [handle skipBytes:ReadNumber(handle)];
		}
	}

	[dictionary setObject:instreams forKey:@"InStreams"];
	[dictionary setObject:outstreams forKey:@"OutStreams"];

	int totalinstreams=[instreams count];
	int totaloutstreams=[outstreams count];

	// Load binding pairs
	int numbindpairs=totaloutstreams-1;
	for(int i=0;i<numbindpairs;i++)
	{
		uint64_t inindex=ReadNumber(handle);
		uint64_t outindex=ReadNumber(handle);
		SetNumberEntryInArray(instreams,inindex,outindex,@"SourceIndex");
		SetNumberEntryInArray(outstreams,outindex,inindex,@"DestinationIndex");
	}

	// Load packed stream indexes, if any
	int numpackedstreams=totalinstreams-numbindpairs;
	if(numpackedstreams==1)
	{
		for(int i=0;i<totalinstreams;i++)
		if(![[instreams objectAtIndex:i] objectForKey:@"SourceIndex"])
		{
			SetObjectEntryInArray(instreams,i,[packedstreams objectAtIndex:*packedstreamindex],@"PackedStream");
			break;
		}
	}
	else
	{
		for(int i=0;i<numpackedstreams;i++)
		SetObjectEntryInArray(instreams,ReadNumber(handle),[packedstreams objectAtIndex:*packedstreamindex+i],@"PackedStream");
	}
	*packedstreamindex+=numpackedstreams;

	// Find output stream
	for(int i=0;i<totaloutstreams;i++)
	if(![[outstreams objectAtIndex:i] objectForKey:@"DestinationIndex"])
	{
		[dictionary setObject:[NSNumber numberWithInt:i] forKey:@"FinalOutStreamIndex"];
		break;
	}
}

-(void)parseSubStreamsInfoForHandle:(CSHandle *)handle folders:(NSArray *)folders
{
	int numfolders=[folders count];

	for(;;)
	{
		int type=ReadNumber(handle);
		switch(type)
		{
			case 0: return;

			case 13: // NumUnpackStreams
				for(int i=0;i<numfolders;i++)
				{
					int numsubstreams=ReadNumber(handle);
					if(numsubstreams!=1) // Re-use default substream when there is only one
					{
						NSArray *substreams=ArrayWithLength(numsubstreams);
						for(int j=0;j<numsubstreams;j++)
						{
							SetNumberEntryInArray(substreams,j,i,@"FolderIndex");
							SetNumberEntryInArray(substreams,j,j,@"SubIndex");
						}
						SetObjectEntryInArray(folders,i,substreams,@"SubStreams");
					}
				}
			break;

			case 9: // Size
				for(int i=0;i<numfolders;i++)
				{
					NSDictionary *folder=[folders objectAtIndex:i];
					NSMutableArray *substreams=[folder objectForKey:@"SubStreams"];
					int numsubstreams=[substreams count];
					uint64_t sum=0;
					for(int j=0;j<numsubstreams-1;j++)
					{
						uint64_t size=ReadNumber(handle);
						SetNumberEntryInArray(substreams,j,size,@"Size");
						SetNumberEntryInArray(substreams,j,sum,@"StartOffset");
						sum+=size;
					}

					int outindex=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];
					NSDictionary *outstream=[[folder objectForKey:@"OutStreams"] objectAtIndex:outindex];
					uint64_t totalsize=[[outstream objectForKey:@"Size"] unsignedLongLongValue];

					SetNumberEntryInArray(substreams,numsubstreams-1,totalsize-sum,@"Size");
					SetNumberEntryInArray(substreams,numsubstreams-1,sum,@"StartOffset");
				}
			break;

			case 10: // CRC
			{
				NSMutableArray *crcstreams=[NSMutableArray array];
				for(int i=0;i<numfolders;i++)
				{
					NSMutableArray *substreams=[[folders objectAtIndex:i] objectForKey:@"SubStreams"];
					int numsubstreams=[substreams count];
					for(int j=0;j<numsubstreams;j++)
					{
						NSMutableDictionary *stream=[substreams objectAtIndex:j];
						if(![stream objectForKey:@"CRC"]) [crcstreams addObject:stream];
					}
				}

				[self parseCRCsForHandle:handle array:crcstreams];
			}
			break;

			default: SkipEntry(handle); break;
		}
	}
}

-(void)setupDefaultSubStreamsForFolders:(NSArray *)folders
{
	int numfolders=[folders count];
	for(int i=0;i<numfolders;i++)
	{
		NSMutableDictionary *folder=[folders objectAtIndex:i];
		int outindex=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];
		NSDictionary *outstream=[[folder objectForKey:@"OutStreams"] objectAtIndex:outindex];
		NSMutableArray *substreams=ArrayWithLength(1);

		SetNumberEntryInArray(substreams,0,i,@"FolderIndex");
		SetNumberEntryInArray(substreams,0,0,@"SubIndex");
		SetNumberEntryInArray(substreams,0,0,@"StartOffset");
		SetObjectEntryInArray(substreams,0,[outstream objectForKey:@"Size"],@"Size");
		SetObjectEntryInArray(substreams,0,[folder objectForKey:@"CRC"],@"CRC");

		SetObjectEntryInArray(folders,i,substreams,@"SubStreams");
	}
}

-(NSArray *)collectAllSubStreamsFromFolders:(NSArray *)folders
{
	int numfolders=[folders count];
	NSMutableArray *allsubstreams=[NSMutableArray array];

	for(int i=0;i<numfolders;i++)
	[allsubstreams addObjectsFromArray:[[folders objectAtIndex:i] objectForKey:@"SubStreams"]];

	return allsubstreams;
}





-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSNumber *isempty=[dict objectForKey:@"7zIsEmptyFile"];
	if(isempty&&[isempty boolValue]) return [self zeroLengthHandleWithChecksum:checksum];

	CSHandle *handle=[self subHandleFromSolidStreamForEntryWithDictionary:dict];

	if(checksum)
	{
		NSNumber *crc=[dict objectForKey:@"7zCRC32"];
		if(crc) return [XADCRCHandle IEEECRC32HandleWithHandle:handle
		length:[handle fileSize] correctCRC:[crc unsignedLongValue] conditioned:YES];
	}

	return handle;
}

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum
{
	return [self handleForStreams:mainstreams folderIndex:[obj intValue]];
}

-(CSHandle *)handleForStreams:(NSDictionary *)streams folderIndex:(int)folderindex
{
	NSDictionary *folder=[[streams objectForKey:@"Folders"] objectAtIndex:folderindex];
	int finalindex=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];

	return [self outHandleForFolder:folder index:finalindex];
}

-(CSHandle *)outHandleForFolder:(NSDictionary *)folder index:(int)index
{
	NSDictionary *outstream=[[folder objectForKey:@"OutStreams"] objectAtIndex:index];
	uint64_t size=[[outstream objectForKey:@"Size"] unsignedLongLongValue];
	NSDictionary *coder=[outstream objectForKey:@"Coder"];
	NSData *props=[coder objectForKey:@"Properties"];

	CSHandle *inhandle=[self inHandleForFolder:folder coder:coder index:0];
	if(!inhandle) return nil;

	switch([self IDForCoder:coder])
	{
		case 0x00000000: return inhandle;
		case 0x00000021: return [[[XADLZMA2Handle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		//case 0x02030200: return @"Swap2";
		//case 0x02030400: return @"Swap4";
		case 0x02040000: return [[[XADDeltaHandle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		case 0x03010100: return [[[XADLZMAHandle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		case 0x03030103: return [[[XAD7ZipBCJHandle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		case 0x0303011b:
		{
			CSHandle *inhandle1=[self inHandleForFolder:folder coder:coder index:1];
			CSHandle *inhandle2=[self inHandleForFolder:folder coder:coder index:2];
			CSHandle *inhandle3=[self inHandleForFolder:folder coder:coder index:3];
			if(!inhandle1||!inhandle2||!inhandle3) return nil;
			return [[[XAD7ZipBCJ2Handle alloc] initWithHandle:inhandle callHandle:inhandle1
			jumpHandle:inhandle2 rangeHandle:inhandle3 length:size] autorelease];
		}
		case 0x03030205: return [[[XAD7ZipPPCHandle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		//case 0x03030301: return [[[XAD7ZipAlphaHandle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		case 0x03030401: return [[[XAD7ZipIA64Handle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		case 0x03030501: return [[[XAD7ZipARMHandle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		//case 0x03030605: return [[[XAD7ZipM68kHandle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		case 0x03030701: return [[[XAD7ZipThumbHandle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		case 0x03030805: return [[[XAD7ZipSPARCHandle alloc] initWithHandle:inhandle length:size propertyData:props] autorelease];
		case 0x03040100:
		{
			if([props length]<5) return nil;
			const uint8_t *bytes=[props bytes];
			int maxorder=bytes[0];
			int suballocsize=CSUInt32LE(&bytes[1]);
			return [[[XAD7ZipPPMdHandle alloc] initWithHandle:inhandle length:size
			maxOrder:maxorder subAllocSize:suballocsize] autorelease];
		}
		case 0x04010000: return inhandle;
		case 0x04010100: return [[[XADZipShrinkHandle alloc] initWithHandle:inhandle length:size] autorelease];
		//case 0x04010600: return @"Implode";
		case 0x04010800: return [CSZlibHandle deflateHandleWithHandle:inhandle length:size];
		case 0x04010900: return [[[XADDeflateHandle alloc] initWithHandle:inhandle length:size variant:XADDeflate64DeflateVariant] autorelease];
		case 0x04011200:
		case 0x04020200: return [CSBzip2Handle bzip2HandleWithHandle:inhandle length:size];
		//case 0x04030100: return @"RAR v1.5";
		//case 0x04030200: return @"RAR v2.0";
		//case 0x04030300: return @"RAR v2.9";
		//case 0x04040100: return @"ARJ";
		//case 0x04040200: return @"ARJ v4";
		case 0x04050000: [[[XADCompressHandle alloc] initWithHandle:inhandle length:size flags:((uint8_t *)[props bytes])[0]] autorelease];
		//case 0x04060000: return @"Lzh";
		//case 0x04080000: return @"Cab";
		//case 0x04090100: return @"DeflateNSIS";
		//case 0x04090200: return @"Bzip2NSIS";
		default: return nil;
	}

	return nil;
}

-(CSHandle *)inHandleForFolder:(NSDictionary *)folder coder:(NSDictionary *)coder index:(int)index
{
	return [self inHandleForFolder:folder index:[[coder objectForKey:@"FirstInStreamIndex"] intValue]+index];
}

-(CSHandle *)inHandleForFolder:(NSDictionary *)folder index:(int)index
{
	NSDictionary *instream=[[folder objectForKey:@"InStreams"] objectAtIndex:index];

	NSDictionary *packedstream=[instream objectForKey:@"PackedStream"];
	if(packedstream)
	{
		uint64_t start=[[packedstream objectForKey:@"Offset"] unsignedLongLongValue];
		uint64_t length=[[packedstream objectForKey:@"Size"] unsignedLongLongValue];

		// Try to make a copied subhandle in case there are multiple-input coders
		// like BCJ2 in use. If it fails, use noncopied ones, but this will cause
		// BCJ2 to break.
		CSHandle *handle;
		@try { handle=[[self handle] subHandleFrom:start length:length]; }
		@catch(id e) { handle=[[self handle] nonCopiedSubHandleFrom:start length:length]; }
		return handle;
	}

	NSNumber *sourceindex=[instream objectForKey:@"SourceIndex"];
	if(sourceindex)
	{
		return [self outHandleForFolder:folder index:[sourceindex intValue]];
	}

	return nil;
}



-(int)IDForCoder:(NSDictionary *)coder
{
	NSData *coderid=[coder objectForKey:@"ID"];
	const uint8_t *idbytes=[coderid bytes];
	int idlength=[coderid length];

	switch(idlength)
	{
		case 1: return idbytes[0]<<24;
		case 2: return (idbytes[0]<<24)|(idbytes[1]<<16);
		case 3: return (idbytes[0]<<24)|(idbytes[1]<<16)|(idbytes[2]<<8);
		case 4: return (idbytes[0]<<24)|(idbytes[1]<<16)|(idbytes[2]<<8)|idbytes[3];
		default: return -1;
	}
}

-(off_t)compressedSizeForFolder:(NSDictionary *)folder
{
	off_t totalsize=0;
	NSEnumerator *enumerator=[[folder objectForKey:@"InStreams"] objectEnumerator];
	NSDictionary *instream;
	while(instream=[enumerator nextObject])
	{
		NSDictionary *packedstream=[instream objectForKey:@"PackedStream"];
		if(packedstream) totalsize+=[[packedstream objectForKey:@"Size"] longLongValue];
	}

	return totalsize;
}

-(off_t)unCompressedSizeForFolder:(NSDictionary *)folder
{
	int finalindex=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];
	NSDictionary *stream=[[folder objectForKey:@"OutStreams"] objectAtIndex:finalindex];
	return [[stream objectForKey:@"Size"] longLongValue];
}

-(NSString *)compressorNameForFolder:(NSDictionary *)folder
{
	int finalindex=[[folder objectForKey:@"FinalOutStreamIndex"] intValue];
	return [self compressorNameForFolder:folder index:finalindex];
}

-(NSString *)compressorNameForFolder:(NSDictionary *)folder index:(int)index
{
	NSDictionary *outstream=[[folder objectForKey:@"OutStreams"] objectAtIndex:index];
	NSDictionary *coder=[outstream objectForKey:@"Coder"];
	NSDictionary *instream=[[folder objectForKey:@"InStreams"] objectAtIndex:[[coder objectForKey:@"FirstInStreamIndex"] intValue]];
	NSString *name=[self compressorNameForCoder:coder];

	NSNumber *source=[instream objectForKey:@"SourceIndex"];
	if(!source) return name;
	else return [NSString stringWithFormat:@"%@+%@",
	[self compressorNameForFolder:folder index:[source intValue]],name];
}


-(NSString *)compressorNameForCoder:(NSDictionary *)coder
{
	switch([self IDForCoder:coder])
	{
		case 0x00000000: return @"None";
		case 0x02030200: return @"Swap2";
		case 0x02030400: return @"Swap4";
		case 0x02040000: return @"Delta";
		case 0x03010100: return @"LZMA";
		case 0x03030103: return @"BCJ";
		case 0x0303011b: return @"BCJ2";
		case 0x03030205: return @"PPC";
		case 0x03030301: return @"Alpha";
		case 0x03030401: return @"IA64";
		case 0x03030501: return @"ARM";
		case 0x03030605: return @"M68k";
		case 0x03030701: return @"ARM Thumb";
		case 0x03030805: return @"SPARC";
		case 0x03040100: return @"PPMD";
		case 0x04010000: return @"None";
		case 0x04010100: return @"Shrink";
		case 0x04010600: return @"Implode";
		case 0x04010800: return @"Deflate";
		case 0x04010900: return @"Deflate64";
		case 0x04011200: return @"Bzip2";
		case 0x04020200: return @"Bzip2";
		case 0x04030100: return @"RAR v1.5";
		case 0x04030200: return @"RAR v2.0";
		case 0x04030300: return @"RAR v2.9";
		case 0x04040100: return @"ARJ";
		case 0x04040200: return @"ARJ v4";
		case 0x04050000: return @"Compress";
		case 0x04060000: return @"Lzh";
		case 0x04080000: return @"Cab";
		case 0x04090100: return @"DeflateNSIS";
		case 0x04090200: return @"Bzip2NSIS";
		default: return nil;
	}
}



-(NSString *)formatName { return @"7-Zip"; }

@end
