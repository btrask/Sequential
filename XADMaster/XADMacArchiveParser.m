#import "XADMacArchiveParser.h"
#import "NSDateXAD.h"
#import "CRC.h"

NSString *XADIsMacBinaryKey=@"XADIsMacBinary";
NSString *XADMightBeMacBinaryKey=@"XADMightBeMacBinary";
NSString *XADDisableMacForkExpansionKey=@"XADDisableMacForkExpansionKey";

@implementation XADMacArchiveParser

+(int)macBinaryVersionForHeader:(NSData *)header
{
	if([header length]<128) return NO;
	const uint8_t *bytes=[header bytes];

	if(CSUInt32BE(bytes+102)=='mBIN') return 3; // MacBinary III

	if(bytes[0]!=0) return 0;
	if(bytes[74]!=0) return 0;
	if(XADCalculateCRC(0,bytes,124,XADCRCReverseTable_1021)==
	XADUnReverseCRC16(CSUInt16BE(bytes+124))) return 2; // MacBinary II

	if(bytes[82]!=0) return 0;
	for(int i=101;i<=125;i++) if(bytes[i]!=0) return 0;
	if(bytes[1]==0||bytes[1]>63) return 0;
	for(int i=0;i<bytes[1];i++) if(bytes[i+2]==0) return 0;
	if(CSUInt32BE(bytes+83)>0x7fffffff) return 0;
	if(CSUInt32BE(bytes+87)>0x7fffffff) return 0;

	return 1; // MacBinary I
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super initWithHandle:handle name:name])
	{
		currhandle=nil;
		dittostack=[[NSMutableArray array] retain];
	}
	return self;
}

-(void)dealloc
{
	[dittostack release];
	[super dealloc];
}

-(void)popDittoStackUntilPrefixFor:(XADPath *)path
{
	while([dittostack count])
	{
		XADPath *dir=[dittostack lastObject];
		if([path hasPrefix:dir]) return;
		[dittostack removeLastObject];
	}
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos
{
	if(retainpos) [XADException raiseNotSupportedException];

	// Check if expansion of forks is disabled
	NSNumber *disable=[properties objectForKey:XADDisableMacForkExpansionKey];
	if(disable&&[disable boolValue])
	{
		NSNumber *isbin=[dict objectForKey:XADIsMacBinaryKey];
		if(isbin&&[isbin boolValue]) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

		[super addEntryWithDictionary:dict retainPosition:retainpos];
		return;
	}

	XADPath *name=[dict objectForKey:XADFileNameKey];
	NSNumber *isdir=[dict objectForKey:XADIsDirectoryKey];

	// Handle directories
	if(isdir&&[isdir boolValue])
	{
		// Discard directories used for ditto forks
		if([[name firstPathComponent] isEqual:@"__MACOSX"]) return;

		// Pop deeper directories off the directory stack, and push this directory
		[self popDittoStackUntilPrefixFor:name];
		[dittostack addObject:name];

		[super addEntryWithDictionary:dict retainPosition:retainpos];
		return;
	}

	// Check if the file is a ditto fork
	if([self parseAppleDoubleWithDictionary:dict name:name]) return;

	// Check for MacBinary files
	if([self parseMacBinaryWithDictionary:dict name:name]) return;

	// Nothing else worked, it's a normal file
	[super addEntryWithDictionary:dict retainPosition:retainpos];
}

-(BOOL)parseAppleDoubleWithDictionary:(NSMutableDictionary *)dict name:(XADPath *)name
{
//	dittoregex=[[XADRegex alloc] initWithPattern:@"(^__MACOSX/|\\./|^)((.*/)\\._|\\._)([^/]+)$" options:0];

	XADString *first=[name firstPathComponent];
	XADString *last=[name lastPathComponent];
	XADPath *basepath=[name pathByDeletingLastPathComponent];

	NSString *laststring=[last string];
	if(![laststring hasPrefix:@"._"]) return NO;
	XADString *newlast=[self XADStringWithString:[laststring substringFromIndex:2]];

	if([first isEqual:@"__MACOSX"]||[first isEqual:@"."]) basepath=[basepath pathByDeletingFirstPathComponent];

	XADPath *origname=[basepath pathByAppendingPathComponent:newlast];

	uint32_t rsrcoffs=0,rsrclen=0;
	uint32_t finderoffs=0,finderlen=0;
	NSData *finderinfo=nil;
	CSHandle *fh=[self rawHandleForEntryWithDictionary:dict wantChecksum:YES];

	@try
	{
		if([fh readUInt32BE]!=0x00051607) return NO;
		if([fh readUInt32BE]!=0x00020000) return NO;
		[fh skipBytes:16];
		int num=[fh readUInt16BE];

		for(int i=0;i<num;i++)
		{
			uint32_t entryid=[fh readUInt32BE];
			uint32_t entryoffs=[fh readUInt32BE];
			uint32_t entrylen=[fh readUInt32BE];

			switch(entryid)
			{
				case 2: // resource fork
					rsrcoffs=entryoffs;
					rsrclen=entrylen;
				break;
				case 9: // finder
					finderoffs=entryoffs;
					finderlen=entrylen;
				break;
			}
		}

		if(finderoffs)
		{
			[fh seekToFileOffset:finderoffs];
			finderinfo=[fh readDataOfLength:finderlen];
		}
	}
	@catch(id e)
	{
		return NO;
	}

	if(!rsrcoffs) return NO;

	NSMutableDictionary *newdict=[NSMutableDictionary dictionaryWithDictionary:dict];

	[newdict setObject:dict forKey:@"MacOriginalDictionary"];
	[newdict setObject:[NSNumber numberWithUnsignedInt:rsrcoffs] forKey:@"MacDataOffset"];
	[newdict setObject:[NSNumber numberWithUnsignedInt:rsrclen] forKey:@"MacDataLength"];
	[newdict setObject:[NSNumber numberWithUnsignedInt:rsrclen] forKey:XADFileSizeKey];
	[newdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsResourceForkKey];

	if(finderinfo)
	{
		[newdict setObject:finderinfo forKey:XADFinderInfoKey];

		const uint8_t *bytes=[finderinfo bytes];
		uint32_t type=CSUInt32BE(bytes+0);
		uint32_t creator=CSUInt32BE(bytes+4);

		if(type!=0&&creator!=0&&(type&0xf000f000)==0&&(creator&0xf000f000)==0) // heuristic to recognize FolderInfo structures
		{
			[newdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
		}
		else
		{
			if(type) [newdict setObject:[NSNumber numberWithUnsignedInt:type] forKey:XADFileTypeKey];
			if(creator) [newdict setObject:[NSNumber numberWithUnsignedInt:creator] forKey:XADFileCreatorKey];
		}
	}

	// Pop deeper directories off the stack, and see this entry is on the stack as a directory
	[self popDittoStackUntilPrefixFor:origname];
	if([dittostack count]&&[[dittostack lastObject] isEqual:origname])
	[newdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	[newdict setObject:origname forKey:XADFileNameKey];

	[newdict removeObjectForKey:XADDataLengthKey];
	[newdict removeObjectForKey:XADDataOffsetKey];

	currhandle=fh;
	[self inspectEntryDictionary:newdict];
	[super addEntryWithDictionary:newdict retainPosition:NO];
	currhandle=nil;

	return YES;
}

-(BOOL)parseMacBinaryWithDictionary:(NSMutableDictionary *)dict name:(XADPath *)name
{
	NSNumber *isbinobj=[dict objectForKey:XADIsMacBinaryKey];
	BOOL isbin=isbinobj?[isbinobj boolValue]:NO;

	NSNumber *checkobj=[dict objectForKey:XADMightBeMacBinaryKey];
	BOOL check=checkobj?[checkobj boolValue]:NO;

	if(!isbin&&!check) return NO;

	CSHandle *fh=[self rawHandleForEntryWithDictionary:dict wantChecksum:YES];

	NSData *header=[fh readDataOfLengthAtMost:128];
	if([header length]!=128) return NO;

	if(!isbin)
	{
		if([XADMacArchiveParser macBinaryVersionForHeader:header]==0) return NO;
	}

	// TODO: should this be turned on or not? probably not.
	//[self setIsMacArchive:YES];

	const uint8_t *bytes=[header bytes];

	uint32_t datasize=CSUInt32BE(bytes+83);
	uint32_t rsrcsize=CSUInt32BE(bytes+87);
	int extsize=CSUInt16BE(bytes+120);

	NSMutableDictionary *template=[NSMutableDictionary dictionaryWithDictionary:dict];
	[template setObject:dict forKey:@"MacOriginalDictionary"];
	[template setObject:[self XADPathWithBytes:bytes+2 length:bytes[1] separators:XADNoPathSeparator] forKey:XADFileNameKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+65)] forKey:XADFileTypeKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+69)] forKey:XADFileCreatorKey];
	[template setObject:[NSNumber numberWithInt:bytes[73]+(bytes[101]<<8)] forKey:XADFinderFlagsKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+65)] forKey:XADFileTypeKey];
	[template setObject:[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(bytes+91)] forKey:XADCreationDateKey];
	[template setObject:[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(bytes+95)] forKey:XADLastModificationDateKey];
	[template removeObjectForKey:XADDataLengthKey];
	[template removeObjectForKey:XADDataOffsetKey];
	[template removeObjectForKey:XADIsMacBinaryKey];
	[template removeObjectForKey:XADMightBeMacBinaryKey];

	currhandle=fh;

	#define BlockSize(size) (((size)+127)&~127)
	if(datasize||!rsrcsize)
	{
		NSMutableDictionary *newdict=[NSMutableDictionary dictionaryWithDictionary:template];
		[newdict setObject:[NSNumber numberWithUnsignedInt:128+BlockSize(extsize)] forKey:@"MacDataOffset"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:datasize] forKey:@"MacDataLength"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:datasize] forKey:XADFileSizeKey];
		[newdict setObject:[NSNumber numberWithUnsignedInt:BlockSize(datasize)] forKey:XADCompressedSizeKey];

		[self inspectEntryDictionary:newdict];
		[super addEntryWithDictionary:newdict retainPosition:NO];
	}

	if(rsrcsize)
	{
		NSMutableDictionary *newdict=[NSMutableDictionary dictionaryWithDictionary:template];
		[newdict setObject:[NSNumber numberWithUnsignedInt:128+BlockSize(extsize)+BlockSize(datasize)] forKey:@"MacDataOffset"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:rsrcsize] forKey:@"MacDataLength"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:rsrcsize] forKey:XADFileSizeKey];
		[newdict setObject:[NSNumber numberWithUnsignedInt:BlockSize(rsrcsize)] forKey:XADCompressedSizeKey];
		[newdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsResourceForkKey];

		[self inspectEntryDictionary:newdict];
		[super addEntryWithDictionary:newdict retainPosition:NO];
	}

	currhandle=nil;

	return YES;
}



-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSDictionary *origdict=[dict objectForKey:@"MacOriginalDictionary"];
	if(origdict)
	{
		off_t offset=[[dict objectForKey:@"MacDataOffset"] longLongValue];
		off_t length=[[dict objectForKey:@"MacDataLength"] longLongValue];

		CSHandle *handle;
		if(currhandle) handle=currhandle;
		else handle=[self rawHandleForEntryWithDictionary:origdict wantChecksum:checksum];

		return [handle nonCopiedSubHandleFrom:offset length:length];
	}

	return [self rawHandleForEntryWithDictionary:dict wantChecksum:checksum];
}



-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

-(void)inspectEntryDictionary:(NSMutableDictionary *)dict
{
}

@end
