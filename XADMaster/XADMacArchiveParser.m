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

	// Check zero fill bytes.
	if(bytes[0]!=0) return 0;
	if(bytes[74]!=0) return 0;
	if(bytes[82]!=0) return 0;
	for(int i=108;i<=115;i++) if(bytes[i]!=0) return 0;

	// Check for a valid name.
	if(bytes[1]==0||bytes[1]>63) return 0;
	for(int i=0;i<bytes[1];i++) if(bytes[i+2]==0) return 0;

	// Check for a valid checksum.
	if(XADCalculateCRC(0,bytes,124,XADCRCReverseTable_1021)==
	XADUnReverseCRC16(CSUInt16BE(bytes+124)))
	{
		// Check for a valid signature.
		if(CSUInt32BE(bytes+102)=='mBIN') return 3; // MacBinary III
		else return 2; // MacBinary II
	}

	// Some final heuristics before accepting a version I file.
	for(int i=99;i<=125;i++) if(bytes[i]!=0) return 0;
	if(CSUInt32BE(bytes+83)>0x7fffffff) return 0; // Data fork size
	if(CSUInt32BE(bytes+87)>0x7fffffff) return 0; // Resource fork size
	if(CSUInt32BE(bytes+91)==0) return 0; // Creation date
	if(CSUInt32BE(bytes+95)==0) return 0; // Last modified date

	return 1; // MacBinary I
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if(self=[super initWithHandle:handle name:name])
	{
		currhandle=nil;
		queuedditto=nil;
		dittostack=[[NSMutableArray array] retain];
	}
	return self;
}

-(void)dealloc
{
	[queuedditto release];
	[dittostack release];
	[super dealloc];
}

-(void)parse
{
	[self parseWithSeparateMacForks];

	// If we have a queued ditto fork left over, get rid of it as it isn't a directory.
	if(queuedditto) [self addQueuedDittoDictionaryAsDirectory:NO];
}

-(void)parseWithSeparateMacForks {}

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

		// If we have a queued ditto fork, check if it matches this directory
		// and get rid of it.
		if(queuedditto)
		{
			BOOL match=[[queuedditto objectForKey:XADFileNameKey] isEqual:name];
			[self addQueuedDittoDictionaryAsDirectory:match];
		}

		[super addEntryWithDictionary:dict retainPosition:retainpos];
		return;
	}

	// If we have a queued ditto fork, get rid of it as it isn't a directory.
	if(queuedditto) [self addQueuedDittoDictionaryAsDirectory:NO];

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

	if(![last hasASCIIPrefix:@"._"]) return NO;
	XADString *newlast=[last XADStringByStrippingASCIIPrefixOfLength:2];
/*	NSString *laststring=[last string];
	if(![laststring hasPrefix:@"._"]) return NO;
	XADString *newlast=[self XADStringWithString:[laststring substringFromIndex:2]];
*/

	if([first isEqual:@"__MACOSX"]||[first isEqual:@"."]) basepath=[basepath pathByDeletingFirstPathComponent];

	XADPath *origname=[basepath pathByAppendingPathComponent:newlast];

	uint32_t rsrcoffs=0,rsrclen=0;
	uint32_t finderoffs=0,finderlen=0;
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

	if(finderoffs) // Load FinderInfo struct if available
	{
		[fh seekToFileOffset:finderoffs];
		NSData *finderinfo=[fh readDataOfLength:finderlen];
		[newdict setObject:finderinfo forKey:XADFinderInfoKey];
	}

	// Replace name, remove unused entries
	[newdict setObject:origname forKey:XADFileNameKey];
	[newdict removeObjectsForKeys:[NSArray arrayWithObjects:
		XADDataLengthKey,XADDataOffsetKey,XADPosixPermissionsKey,
		XADPosixUserKey,XADPosixUserNameKey,XADPosixGroupKey,XADPosixGroupNameKey,
	nil]];

	// Pop deeper directories off the stack, and see this entry is on the stack as a directory
	[self popDittoStackUntilPrefixFor:origname];
	BOOL isdir=[dittostack count]&&[[dittostack lastObject] isEqual:origname];
	if(isdir) [newdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	if(rsrclen||isdir)
	{
		currhandle=fh;
		[self inspectEntryDictionary:newdict];
		[super addEntryWithDictionary:newdict retainPosition:NO];
		currhandle=nil;
	}
	else
	{
		// Entries without a resource fork might be directories, so keep them around until
		// we can analyze the next entry.
		[self queueDittoDictionary:newdict];
	}

	return YES;
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

-(void)queueDittoDictionary:(NSMutableDictionary *)dict
{
	queuedditto=[dict retain];
}

-(void)addQueuedDittoDictionaryAsDirectory:(BOOL)isdir
{
	if(isdir) [queuedditto setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
	[self inspectEntryDictionary:queuedditto];
	[super addEntryWithDictionary:queuedditto retainPosition:NO];
	[queuedditto release];
	queuedditto=nil;
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

	XADPath *filename=[dict objectForKey:XADFileNameKey];
	XADPath *parent=[filename pathByDeletingLastPathComponent];
	if(!parent) parent=[self XADPath];
	XADString *namepart=[self XADStringWithBytes:bytes+2 length:bytes[1]];
	XADPath *newpath=[parent pathByAppendingPathComponent:namepart];

	NSMutableDictionary *template=[NSMutableDictionary dictionaryWithDictionary:dict];
	[template setObject:dict forKey:@"MacOriginalDictionary"];
	[template setObject:newpath forKey:XADFileNameKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+65)] forKey:XADFileTypeKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+69)] forKey:XADFileCreatorKey];
	[template setObject:[NSNumber numberWithInt:bytes[101]+(bytes[73]<<8)] forKey:XADFinderFlagsKey];
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

		if(!length) return [self zeroLengthHandleWithChecksum:checksum];

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
