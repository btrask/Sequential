#import "XADMacArchiveParser.h"
#import "XADArchiveParserDescriptions.h"
#import "XADAppleDouble.h"
#import "CSMemoryHandle.h"
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
	if((self=[super initWithHandle:handle name:name]))
	{
		previousname=nil;
		dittodirectorystack=[NSMutableArray new];

		queueddittoentry=nil;
		queueddittodata=nil;

		cachedentry=nil;
		cacheddata=nil;
		cachedhandle=nil;
	}
	return self;
}

-(void)dealloc
{
	[previousname release];
	[dittodirectorystack release];
	[queueddittoentry release];
	[queueddittodata release];
	[super dealloc];
}

-(void)parse
{
	[self parseWithSeparateMacForks];

	// If we have a queued ditto fork left over, get rid of it as it isn't a directory.
	if(queueddittoentry) [self addQueuedDittoDictionaryAndRetainPosition:NO];
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

	NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
	BOOL isdir=dirnum && [dirnum boolValue];

	// If we have a queued ditto fork, check if it has the same name as this entry,
	// and get rid of it. 
	if(queueddittoentry)
	{
		XADPath *queuedname=[queueddittoentry objectForKey:XADFileNameKey];
		if([queuedname isCanonicallyEqual:name])
		{
			[self addQueuedDittoDictionaryWithName:name isDirectory:isdir retainPosition:retainpos];
		}
		else
		{
			[self addQueuedDittoDictionaryAndRetainPosition:retainpos];
		}
	}

	// Handle directories
	if(isdir)
	{
		// Discard directories used for ditto forks
		NSString *firstcomponent=[name firstPathComponentWithEncodingName:XADUTF8StringEncodingName];
		if(firstcomponent && [firstcomponent isEqual:@"__MACOSX"]) return;

		// Pop deeper directories off the directory stack, and push this directory
		[self popDittoDirectoryStackUntilCanonicalPrefixFor:name];
		[self pushDittoDirectory:name];
	}
	else
	{
		// Check for MacBinary files.
		if([self parseMacBinaryWithDictionary:dict name:name retainPosition:retainpos]) return;

		// Check if the file is a ditto fork.
		if([self parseAppleDoubleWithDictionary:dict name:name retainPosition:retainpos]) return;

	}

	// Nothing else worked, it's a normal file. Remember its filename, and output it.
	[self setPreviousFilename:[dict objectForKey:XADFileNameKey]];
	[super addEntryWithDictionary:dict retainPosition:retainpos];
}



-(BOOL)parseAppleDoubleWithDictionary:(NSMutableDictionary *)dict
name:(XADPath *)name retainPosition:(BOOL)retainpos
{
	// Ditto forks are only ever UTF-8.
	if(![name canDecodeWithEncodingName:XADUTF8StringEncodingName]) return NO;

	// Resource forks are at most 16 megabytes. Ignore larger files, as we will
	// be reading the whole file into memory.
	NSNumber *filesizenum=[dict objectForKey:XADFileSizeKey];
	if(!filesizenum) return NO;

	off_t filesize=[filesizenum longLongValue];
	if(filesize>16*1024*1024+65536) return NO;

	// Check the file name.
	NSString *first=[name firstPathComponentWithEncodingName:XADUTF8StringEncodingName];
	NSString *last=[name lastPathComponentWithEncodingName:XADUTF8StringEncodingName];
	XADPath *basepath=[name pathByDeletingLastPathComponentWithEncodingName:XADUTF8StringEncodingName];

	// Ditto forks are always prefixed with "._".
	if(![last hasPrefix:@"._"]) return NO;
	NSString *newlast=[last substringFromIndex:2];

	// Sometimes, they are stored in a root directory named "__MACOSX".
	// Get rid of this directory.
	if([first isEqual:@"__MACOSX"]) basepath=[basepath pathByDeletingFirstPathComponentWithEncodingName:XADUTF8StringEncodingName];

	// Recreate the original name and path.
	XADPath *origname=[basepath pathByAppendingXADStringComponent:[self XADStringWithString:newlast]];

	// Try to see if we can match this name against a previously encountered name.
	// If so, set flags to remember we found a name, and replace the name with that
	// of the earlier entry, to make isEqual: work right.
	BOOL matchfound=NO,isdir=NO;

	// Check if the name is canonically the same as the previous file unpacked.
	if(previousname && [origname isCanonicallyEqual:previousname encodingName:XADUTF8StringEncodingName])
	{
		origname=previousname;
		matchfound=YES;
	}

	// Pop deeper directories off the stack of directory names, and check if the
	// name is the same as the top directory on the stack.
	[self popDittoDirectoryStackUntilCanonicalPrefixFor:origname];
	XADPath *stackname=[self topOfDittoDirectoryStack];
	if(stackname && [origname isCanonicallyEqual:stackname encodingName:XADUTF8StringEncodingName])
	{
		origname=stackname;
		isdir=YES;
		matchfound=YES;
	}

	// Parse AppleDouble format.
	off_t rsrcoffs,rsrclen;
	NSDictionary *extattrs=nil;
	NSData *dittodata=nil;

	@try
	{
		CSHandle *fh=[self rawHandleForEntryWithDictionary:dict wantChecksum:YES];
		dittodata=[fh remainingFileContents];

		CSMemoryHandle *memhandle=[CSMemoryHandle memoryHandleForReadingData:dittodata];

		if(![XADAppleDouble parseAppleDoubleWithHandle:memhandle
		resourceForkOffset:&rsrcoffs resourceForkLength:&rsrclen
		extendedAttributes:&extattrs]) @throw @"Failed to read AppleDouble format";
	}
	@catch(id e)
	{
		// Reading or parsing failed, so add this as a regular entry with the
		// cached data, if any.
		[self addEntryWithDictionary:dict retainPosition:retainpos data:dittodata];
		return YES;
	}

	// Build a new entry dictionary for the fork.
	NSMutableDictionary *newdict=[NSMutableDictionary dictionaryWithDictionary:dict];

	[newdict setObject:dict forKey:@"MacOriginalDictionary"];
	[newdict setObject:[NSNumber numberWithLongLong:rsrcoffs] forKey:@"MacDataOffset"];
	[newdict setObject:[NSNumber numberWithLongLong:rsrclen] forKey:@"MacDataLength"];
	[newdict setObject:[NSNumber numberWithLongLong:rsrclen] forKey:XADFileSizeKey];
	[newdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsResourceForkKey];

	// Replace name, remove unused entries.
	[newdict setObject:origname forKey:XADFileNameKey];
	[newdict removeObjectsForKeys:[NSArray arrayWithObjects:
		XADDataLengthKey,XADDataOffsetKey,XADPosixPermissionsKey,
		XADPosixUserKey,XADPosixUserNameKey,XADPosixGroupKey,XADPosixGroupNameKey,
	nil]];

	// TODO: This replaces any existing attributes. None should
	// exist, but maybe just in case they should be merged if they do.
	if(extattrs) [newdict setObject:extattrs forKey:XADExtendedAttributesKey];

	if(isdir) [newdict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	if(matchfound)
	{
		// If we matched this entry with the name of an earlier one, it is done,
		// and we can output it.
		[self inspectEntryDictionary:newdict]; // This is probably not necessary.
		[self addEntryWithDictionary:newdict retainPosition:retainpos data:dittodata];
	}
	else
	{
		// If we didn't find the name for this entry from a previous entry, we will
		// need to keep it around until we can look at the next entry to see its name
		// matches.
		[self queueDittoDictionary:newdict data:dittodata];
	}

	return YES;
}



-(void)setPreviousFilename:(XADPath *)prevname
{
	[previousname autorelease];
	previousname=[prevname retain];
}

-(XADPath *)topOfDittoDirectoryStack
{
	if(![dittodirectorystack count]) return nil;
	return [dittodirectorystack lastObject];
}

-(void)pushDittoDirectory:(XADPath *)directory
{
	[dittodirectorystack addObject:directory];
}

-(void)popDittoDirectoryStackUntilCanonicalPrefixFor:(XADPath *)path
{
	while([dittodirectorystack count])
	{
		XADPath *dir=[dittodirectorystack lastObject];
		if([path hasPrefix:dir]) return;
		[dittodirectorystack removeLastObject];
	}
}




-(void)queueDittoDictionary:(NSMutableDictionary *)dict data:(NSData *)data
{
	[queueddittoentry autorelease];
	[queueddittodata autorelease];
	queueddittoentry=[dict retain];
	queueddittodata=[data retain];
}

-(void)addQueuedDittoDictionaryAndRetainPosition:(BOOL)retainpos
{
	[self addQueuedDittoDictionaryWithName:nil isDirectory:NO retainPosition:retainpos];
}

-(void)addQueuedDittoDictionaryWithName:(XADPath *)newname
isDirectory:(BOOL)isdir retainPosition:(BOOL)retainpos
{
	if(newname) [queueddittoentry setObject:newname forKey:XADFileNameKey];
	if(isdir) [queueddittoentry setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];

	[self inspectEntryDictionary:queueddittoentry];
	[self addEntryWithDictionary:queueddittoentry retainPosition:retainpos data:queueddittodata];

	[queueddittoentry release];
	queueddittoentry=nil;
	[queueddittodata release];
	queueddittodata=nil;
}




-(BOOL)parseMacBinaryWithDictionary:(NSMutableDictionary *)dict
name:(XADPath *)name retainPosition:(BOOL)retainpos
{
	NSNumber *isbinobj=[dict objectForKey:XADIsMacBinaryKey];
	BOOL isbin=isbinobj?[isbinobj boolValue]:NO;

	NSNumber *checkobj=[dict objectForKey:XADMightBeMacBinaryKey];
	BOOL check=checkobj?[checkobj boolValue]:NO;

	// Return if this file is not known or suspected to be MacBinary.
	if(!isbin&&!check) return NO;

	// Don't bother checking files inside unseekable streams unless known to be MacBinary.
	if(!isbin&&[[self handle] isKindOfClass:[CSStreamHandle class]]) return NO;

	CSHandle *fh=[self rawHandleForEntryWithDictionary:dict wantChecksum:YES];

	NSData *header=[fh readDataOfLengthAtMost:128];
	if([header length]!=128) return NO;

	// Check the file if it is not known to be MacBinary.
	if(!isbin&&[XADMacArchiveParser macBinaryVersionForHeader:header]==0) return NO;

	// TODO: should this be turned on or not? probably not.
	//[self setIsMacArchive:YES];

	const uint8_t *bytes=[header bytes];

	uint32_t datasize=CSUInt32BE(bytes+83);
	uint32_t rsrcsize=CSUInt32BE(bytes+87);
	int extsize=CSUInt16BE(bytes+120);

	XADPath *newpath;
	if(name)
	{
		XADPath *parent=[name pathByDeletingLastPathComponent];
		XADString *namepart=[self XADStringWithBytes:bytes+2 length:bytes[1]];
		newpath=[parent pathByAppendingXADStringComponent:namepart];
	}
	else
	{
		newpath=[self XADPathWithBytes:bytes+2 length:bytes[1] separators:XADNoPathSeparator];
	}

	NSMutableDictionary *template=[NSMutableDictionary dictionaryWithDictionary:dict];
	[template setObject:dict forKey:@"MacOriginalDictionary"];
	[template setObject:newpath forKey:XADFileNameKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+65)] forKey:XADFileTypeKey];
	[template setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+69)] forKey:XADFileCreatorKey];
	[template setObject:[NSNumber numberWithInt:bytes[101]+(bytes[73]<<8)] forKey:XADFinderFlagsKey];
	[template setObject:[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(bytes+91)] forKey:XADCreationDateKey];
	[template setObject:[NSDate XADDateWithTimeIntervalSince1904:CSUInt32BE(bytes+95)] forKey:XADLastModificationDateKey];
	[template removeObjectForKey:XADDataLengthKey];
	[template removeObjectForKey:XADDataOffsetKey];
	[template removeObjectForKey:XADIsMacBinaryKey];
	[template removeObjectForKey:XADMightBeMacBinaryKey];

	#define BlockSize(size) (((size)+127)&~127)
	if(datasize||!rsrcsize)
	{
		NSMutableDictionary *newdict=[NSMutableDictionary dictionaryWithDictionary:template];
		[newdict setObject:[NSNumber numberWithUnsignedInt:128+BlockSize(extsize)] forKey:@"MacDataOffset"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:datasize] forKey:@"MacDataLength"];
		[newdict setObject:[NSNumber numberWithUnsignedInt:datasize] forKey:XADFileSizeKey];
		[newdict setObject:[NSNumber numberWithUnsignedInt:BlockSize(datasize)] forKey:XADCompressedSizeKey];

		[self inspectEntryDictionary:newdict];
		[self addEntryWithDictionary:newdict retainPosition:retainpos handle:fh];
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
		[self addEntryWithDictionary:newdict retainPosition:retainpos handle:fh];
	}

	return YES;
}




-(void)addEntryWithDictionary:(NSMutableDictionary *)dict
retainPosition:(BOOL)retainpos data:(NSData *)data
{
	cachedentry=dict;
	cacheddata=data;
	cachedhandle=nil;
	[super addEntryWithDictionary:dict retainPosition:retainpos];
	cachedentry=nil;
	cacheddata=nil;
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict
retainPosition:(BOOL)retainpos handle:(CSHandle *)handle
{
	cachedentry=dict;
	cacheddata=nil;
	cachedhandle=handle;
	[super addEntryWithDictionary:dict retainPosition:retainpos];
	cachedentry=nil;
	cachedhandle=nil;
}




-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSDictionary *origdict=[dict objectForKey:@"MacOriginalDictionary"];
	if(origdict)
	{
		off_t offset=[[dict objectForKey:@"MacDataOffset"] longLongValue];
		off_t length=[[dict objectForKey:@"MacDataLength"] longLongValue];

		if(!length) return [self zeroLengthHandleWithChecksum:checksum];

		CSHandle *handle=nil;
		if(cachedentry==dict)
		{
			if(cachedhandle) handle=cachedhandle;
			else if(cacheddata) handle=[CSMemoryHandle memoryHandleForReadingData:cacheddata];
		}

		if(!handle) handle=[self rawHandleForEntryWithDictionary:origdict wantChecksum:checksum];

		return [handle nonCopiedSubHandleFrom:offset length:length];
	}
	else
	{
		return [self rawHandleForEntryWithDictionary:dict wantChecksum:checksum];
	}
}




-(NSString *)descriptionOfValueInDictionary:(NSDictionary *)dict key:(NSString *)key
{
	id object=[dict objectForKey:key];
	if(!object) return nil;

	if([key isEqual:@"MacOriginalDictionary"])
	{
		if(![object isKindOfClass:[NSDictionary class]]) return [object description];
		return XADHumanReadableEntryWithDictionary(object,self);
	}
	else if([key isEqual:XADMightBeMacBinaryKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return XADHumanReadableBoolean([object longLongValue]);
	}
	else
	{
		return [super descriptionOfValueInDictionary:dict key:key];
	}
}

-(NSString *)descriptionOfKey:(NSString *)key
{
	static NSDictionary *descriptions=nil;
	if(!descriptions) descriptions=[[NSDictionary alloc] initWithObjectsAndKeys:
		NSLocalizedString(@"Is an embedded MacBinary file",@""),XADIsMacBinaryKey,
		NSLocalizedString(@"Check for MacBinary",@""),XADMightBeMacBinaryKey,
		NSLocalizedString(@"Mac OS fork handling is disabled",@""),XADDisableMacForkExpansionKey,
		NSLocalizedString(@"Original archive entry",@""),@"MacOriginalDictionary",
		NSLocalizedString(@"Start of embedded data",@""),@"MacDataOffset",
		NSLocalizedString(@"Length of embedded data",@""),@"MacDataLength",
		nil];

	NSString *description=[descriptions objectForKey:key];
	if(description) return description;

	return [super descriptionOfKey:key];
}




-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	return nil;
}

-(void)inspectEntryDictionary:(NSMutableDictionary *)dict
{
}

@end

