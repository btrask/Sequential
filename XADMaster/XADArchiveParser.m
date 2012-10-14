#import "XADArchiveParser.h"
#import "CSFileHandle.h"
#import "CSMultiHandle.h"
#import "CSMemoryHandle.h"
#import "XADCRCHandle.h"

#import "XADZipParser.h"
#import "XADZipSFXParsers.h"
#import "XADRARParser.h"
#import "XAD7ZipParser.h"
#import "XADPPMdParser.h"
#import "XADStuffItParser.h"
#import "XADStuffIt5Parser.h"
#import "XADStuffItXParser.h"
#import "XADCompactProParser.h"
#import "XADDiskDoublerParser.h"
#import "XADBinHexParser.h"
#import "XADMacBinaryParser.h"
#import "XADPackItParser.h"
#import "XADNowCompressParser.h"
#import "XADGzipParser.h"
#import "XADBzip2Parser.h"
#import "XADLZMAAloneParser.h"
#import "XADXZParser.h"
#import "XADCompressParser.h"
#import "XADTarParser.h"
#import "XADCpioParser.h"
#import "XADXARParser.h"
#import "XADRPMParser.h"
#import "XADLZXParser.h"
#import "XADPowerPackerParser.h"
#import "XADLZHParser.h"
#import "XADLZHSFXParsers.h"
#import "XADARJParser.h"
#import "XADNSISParser.h"
#import "XADCABParser.h"
#import "XADCFBFParser.h"
#import "XADALZipParser.h"
#import "XADNDSParser.h"
#import "XADNSAParser.h"
#import "XADSARParser.h"
#import "XADSplitFileParser.h"
#import "XADLibXADParser.h"

#include <dirent.h>

NSString *XADFileNameKey=@"XADFileName";
NSString *XADFileSizeKey=@"XADFileSize";
NSString *XADCompressedSizeKey=@"XADCompressedSize";
NSString *XADLastModificationDateKey=@"XADLastModificationDate";
NSString *XADLastAccessDateKey=@"XADLastAccessDate";
NSString *XADCreationDateKey=@"XADCreationDate";
NSString *XADFileTypeKey=@"XADFileType";
NSString *XADFileCreatorKey=@"XADFileCreator";
NSString *XADFinderFlagsKey=@"XADFinderFlags";
NSString *XADFinderInfoKey=@"XADFinderInfo";
NSString *XADPosixPermissionsKey=@"XADPosixPermissions";
NSString *XADPosixUserKey=@"XADPosixUser";
NSString *XADPosixGroupKey=@"XADPosixGroup";
NSString *XADPosixUserNameKey=@"XADPosixUserName";
NSString *XADPosixGroupNameKey=@"XADPosixGroupName";
NSString *XADDOSFileAttributesKey=@"XADDOSFileAttributes";
NSString *XADWindowsFileAttributesKey=@"XADWindowsFileAttributes";

NSString *XADIsEncryptedKey=@"XADIsEncrypted";
NSString *XADIsCorruptedKey=@"XADIsCorrupted";
NSString *XADIsDirectoryKey=@"XADIsDirectory";
NSString *XADIsResourceForkKey=@"XADIsResourceFork";
NSString *XADIsArchiveKey=@"XADIsArchive";
NSString *XADIsLinkKey=@"XADIsLink";
NSString *XADIsHardLinkKey=@"XADIsHardLink";
NSString *XADLinkDestinationKey=@"XADLinkDestination";
NSString *XADIsCharacterDeviceKey=@"XADIsCharacterDevice";
NSString *XADIsBlockDeviceKey=@"XADIsBlockDevice";
NSString *XADDeviceMajorKey=@"XADDeviceMajor";
NSString *XADDeviceMinorKey=@"XADDeviceMinor";
NSString *XADIsFIFOKey=@"XADIsFIFO";

NSString *XADCommentKey=@"XADComment";
NSString *XADDataOffsetKey=@"XADDataOffset";
NSString *XADDataLengthKey=@"XADDataLength";
NSString *XADSkipOffsetKey=@"XADSkipOffset";
NSString *XADSkipLengthKey=@"XADSkipLength";
NSString *XADCompressionNameKey=@"XADCompressionName";

NSString *XADIsSolidKey=@"XADIsSolid";
NSString *XADFirstSolidEntryKey=@"XADFirstSolidEntry";
NSString *XADNextSolidEntryKey=@"XADNextSolidEntry";
NSString *XADSolidObjectKey=@"XADSolidObject";
NSString *XADSolidOffsetKey=@"XADSolidOffset";
NSString *XADSolidLengthKey=@"XADSolidLength";

NSString *XADArchiveNameKey=@"XADArchiveName";
NSString *XADVolumesKey=@"XADVolumes";


@implementation XADArchiveParser

static NSMutableArray *parserclasses=nil;
static int maxheader=0;

+(void)initialize
{
	static BOOL hasinitialized=NO;
	if(hasinitialized) return;
	hasinitialized=YES;

	parserclasses=[[NSMutableArray arrayWithObjects:
		// Common formats
		[XADZipParser class],
		[XADRARParser class],
		[XAD7ZipParser class],
		[XADGzipParser class],
		[XADBzip2Parser class],
		[XADTarParser class],

		// Mac formats
		[XADStuffItParser class],
		[XADStuffIt5Parser class],
		[XADStuffIt5ExeParser class],
		[XADStuffItXParser class],
		[XADBinHexParser class],
		[XADMacBinaryParser class],
		[XADDiskDoublerParser class],
		[XADPackItParser class],
		[XADNowCompressParser class],

		// Less common formats
		[XADPPMdParser class],
		[XADXARParser class],
		[XADCompressParser class],
		[XADRPMParser class],
		[XADXZParser class],
		[XADALZipParser class],
		[XADCABParser class],
		[XADCFBFParser class],
		[XADCABSFXParser class],
		[XADLZHParser class],
		[XADLZHAmigaSFXParser class],
		[XADLZHCommodore64SFXParser class],
		[XADLZHSFXParser class],
		[XADLZXParser class],
		[XADPowerPackerParser class],
		[XADNDSParser class],
		[XADNSAParser class],
		[XADSARParser class],

		// Detectors that require lots of work
		[XADWinZipSFXParser class],
		[XADZipItSEAParser class],
		[XADZipSFXParser class],
		[XADEmbeddedRARParser class],
		[XADNSISParser class],
		[XADGzipSFXParser class],
		[XADCompactProParser class],
		[XADARJParser class],

		// Over-eager detectors
		[XADLZMAAloneParser class],
		[XADCpioParser class],
		[XADSplitFileParser class],

		// LibXAD
		[XADLibXADParser class],
	nil] retain];

	NSEnumerator *enumerator=[parserclasses objectEnumerator];
	Class class;
	while(class=[enumerator nextObject])
	{
		int header=[class requiredHeaderSize];
		if(header>maxheader) maxheader=header;
	}
}

+(Class)archiveParserClassForHandle:(CSHandle *)handle firstBytes:(NSData *)header name:(NSString *)name
{
	NSEnumerator *enumerator=[parserclasses objectEnumerator];
	Class parserclass;
	while(parserclass=[enumerator nextObject])
	{
		[handle seekToFileOffset:0];
		@try {
			if([parserclass recognizeFileWithHandle:handle firstBytes:header name:name])
			{
				[handle seekToFileOffset:0];
				return parserclass;
			}
		} @catch(id e) {} // ignore parsers that throw errors on recognition or init
	}
	return nil;
}

+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle name:(NSString *)name
{
	NSData *header=[handle readDataOfLengthAtMost:maxheader];
	return [self archiveParserForHandle:handle firstBytes:header name:name];
}

+(XADArchiveParser *)archiveParserForHandle:(CSHandle *)handle firstBytes:(NSData *)header name:(NSString *)name
{
	Class parserclass=[self archiveParserClassForHandle:handle firstBytes:header name:name];
	return [[[parserclass alloc] initWithHandle:handle name:name] autorelease];
}

+(XADArchiveParser *)archiveParserForPath:(NSString *)filename
{
	CSHandle *handle;

	@try {
		handle=[CSFileHandle fileHandleForReadingAtPath:filename];
	} @catch(id e) { return nil; }

	NSData *header=[handle readDataOfLengthAtMost:maxheader];

	Class parserclass=[self archiveParserClassForHandle:handle firstBytes:header name:filename];
	if(!parserclass) return nil;

	@try
	{
		NSArray *volumes=[parserclass volumesForHandle:handle firstBytes:header name:filename];
		if(volumes&&[volumes count]>1)
		{
			NSMutableArray *handles=[NSMutableArray array];
			NSEnumerator *enumerator=[volumes objectEnumerator];
			NSString *volume;

			while(volume=[enumerator nextObject])
			[handles addObject:[CSFileHandle fileHandleForReadingAtPath:volume]];

			CSMultiHandle *multihandle=[CSMultiHandle multiHandleWithHandleArray:handles];

			return [[[parserclass alloc] initWithHandle:multihandle name:filename
			volumes:volumes] autorelease];
		}
	}
	@catch(id e) { } // Fall through to a single file instead.

	return [[[parserclass alloc] initWithHandle:handle name:filename] autorelease];
}







-(id)_initWithHandle:(CSHandle *)handle
{
	if(self=[super init])
	{
		sourcehandle=[handle retain];

		skiphandle=nil;
		delegate=nil;
		password=nil;

		stringsource=[XADStringSource new];

		properties=[[NSMutableDictionary alloc] init];

		currsolidobj=nil;
		currsolidhandle=nil;

		parsersolidobj=nil;
		firstsoliddict=prevsoliddict=nil;

		shouldstop=NO;

		autopool=nil;
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name
{
	if((self=[self _initWithHandle:handle]))
	{
		[self setObject:[name lastPathComponent] forPropertyKey:XADArchiveNameKey];
		[self setObject:[NSArray arrayWithObject:name] forPropertyKey:XADVolumesKey];
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle name:(NSString *)name volumes:(NSArray *)volumes
{
	if((self=[self _initWithHandle:handle]))
	{
		[self setObject:[name lastPathComponent] forPropertyKey:XADArchiveNameKey];
		[self setObject:volumes forPropertyKey:XADVolumesKey];
	}
	return self;
}

-(void)dealloc
{
	[sourcehandle release];
	[skiphandle release];
	[stringsource release];
	[properties release];
	[currsolidobj release];
	[currsolidhandle release];
	[firstsoliddict release];
	[prevsoliddict release];
	[super dealloc];
}



-(NSDictionary *)properties { return properties; }

-(NSString *)name { return [properties objectForKey:XADArchiveNameKey]; }

-(NSString *)filename { return [[properties objectForKey:XADVolumesKey] objectAtIndex:0]; }

-(NSArray *)allFilenames { return [properties objectForKey:XADVolumesKey]; }

-(BOOL)isEncrypted
{
	NSNumber *isencrypted=[properties objectForKey:XADIsEncryptedKey];
	return isencrypted&&[isencrypted boolValue];
}




-(id)delegate { return delegate; }

-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(NSString *)password
{
	if(!password)
	{
		[delegate archiveParserNeedsPassword:self];
		if(!password) return @"";
	}
	return password;
}

-(void)setPassword:(NSString *)newpassword
{
	[password autorelease];
	password=[newpassword retain];
}

-(XADStringSource *)stringSource { return stringsource; }



-(XADString *)linkDestinationForDictionary:(NSDictionary *)dict
{
	// Return the destination path for a link.

	// Check if this entry actually is a link.
	NSNumber *islink=[dict objectForKey:XADIsLinkKey];
	if(!islink||![islink boolValue]) return nil;

	// If the destination is stored in the dictionary, return it directly.
	XADString *linkdest=[dict objectForKey:XADLinkDestinationKey];
	if(linkdest) return linkdest;

	// If not, return the contents of the data stream as the destination (for Zip files and the like).
	CSHandle *handle=[self handleForEntryWithDictionary:dict wantChecksum:YES];
	NSData *linkdata=[handle remainingFileContents];
	if([handle hasChecksum]&&![handle isChecksumCorrect]) return nil; // TODO: do something else here?

	return [self XADStringWithData:linkdata];
}

-(NSData *)finderInfoForDictionary:(NSDictionary *)dict
{
	// Return a FinderInfo struct with extended info (32 bytes in size).

	NSData *finderinfo=[dict objectForKey:XADFinderInfoKey];
	if(finderinfo)
	{
		// If a FinderInfo struct already exists, return it. Extend it to 32 bytes if needed.

		if([finderinfo length]>=32) return finderinfo;
		NSMutableData *extendedinfo=[NSMutableData dataWithData:finderinfo];
		[extendedinfo setLength:32];
		return extendedinfo;
	}
	else
	{
		// If a FinderInfo struct doesn't exist, make one.

		uint8_t finderinfo[32]={ 0x00 };

		NSNumber *dirnum=[dict objectForKey:XADIsDirectoryKey];
		BOOL isdir=dirnum&&[dirnum boolValue];
		if(!isdir)
		{
			NSNumber *typenum=[dict objectForKey:XADFinderFlagsKey];
			NSNumber *creatornum=[dict objectForKey:XADFinderFlagsKey];

			if(typenum) CSSetUInt32BE(&finderinfo[0],[typenum unsignedIntValue]);
			if(creatornum) CSSetUInt32BE(&finderinfo[4],[creatornum unsignedIntValue]);
		}

		NSNumber *flagsnum=[dict objectForKey:XADFinderFlagsKey];
		if(flagsnum) CSSetUInt16BE(&finderinfo[8],[flagsnum unsignedShortValue]);

		return [NSData dataWithBytes:finderinfo length:32];
	}
}



// Internal functions

static NSInteger XADVolumeSort(id entry1,id entry2,void *extptr)
{
	NSString *str1=entry1;
	NSString *str2=entry2;
	NSString *firstext=(NSString *)extptr;
	BOOL isfirst1=firstext&&[str1 rangeOfString:firstext options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound;
	BOOL isfirst2=firstext&&[str2 rangeOfString:firstext options:NSAnchoredSearch|NSCaseInsensitiveSearch|NSBackwardsSearch].location!=NSNotFound;

	if(isfirst1&&!isfirst2) return NSOrderedAscending;
	else if(!isfirst1&&isfirst2) return NSOrderedDescending;
//	else return [str1 compare:str2 options:NSCaseInsensitiveSearch|NSNumericSearch];
	else return [str1 compare:str2 options:NSCaseInsensitiveSearch];
}

+(NSArray *)scanForVolumesWithFilename:(NSString *)filename
regex:(XADRegex *)regex firstFileExtension:(NSString *)firstext
{
	NSMutableArray *volumes=[NSMutableArray array];

	NSString *dirname=[filename stringByDeletingLastPathComponent];
	if(!dirname||[dirname length]==0) dirname=@".";

	NSEnumerator *enumerator=[[[NSFileManager defaultManager] contentsOfDirectoryAtPath:dirname error:NULL] objectEnumerator];
	if(!enumerator) return nil;

	NSString *direntry;
	while(direntry=[enumerator nextObject])
	{
		NSString *filename=[dirname stringByAppendingPathComponent:direntry];
		if([regex matchesString:filename]) [volumes addObject:filename];
	}

	[volumes sortUsingFunction:XADVolumeSort context:firstext];

	return volumes;
}



-(BOOL)shouldKeepParsing
{
	if(!delegate) return YES;
	if(shouldstop) return NO;

	shouldstop=[delegate archiveParsingShouldStop:self];
	return !shouldstop;
}



-(CSHandle *)handle { return sourcehandle; }

-(CSHandle *)handleAtDataOffsetForDictionary:(NSDictionary *)dict
{
	NSNumber *skipoffs=[dict objectForKey:XADSkipOffsetKey];
	if(skipoffs)
	{
		[skiphandle seekToFileOffset:[skipoffs longLongValue]];

		NSNumber *length=[dict objectForKey:XADSkipLengthKey];
		if(length) return [skiphandle nonCopiedSubHandleOfLength:[length longLongValue]];
		else return skiphandle;
	}
	else
	{
		[sourcehandle seekToFileOffset:[[dict objectForKey:XADDataOffsetKey] longLongValue]];

		NSNumber *length=[dict objectForKey:XADDataLengthKey];
		if(length) return [sourcehandle nonCopiedSubHandleOfLength:[length longLongValue]];
		else return sourcehandle;
	}
}

-(XADSkipHandle *)skipHandle
{
	if(!skiphandle) skiphandle=[[XADSkipHandle alloc] initWithHandle:sourcehandle];
	return skiphandle;
}

-(CSHandle *)zeroLengthHandleWithChecksum:(BOOL)checksum
{
	CSHandle *zero=[CSMemoryHandle memoryHandleForReadingData:[NSData data]];
	if(checksum) zero=[XADCRCHandle IEEECRC32HandleWithHandle:zero length:0 correctCRC:0 conditioned:NO];
	return zero;
}

-(CSHandle *)subHandleFromSolidStreamForEntryWithDictionary:(NSDictionary *)dict
{
	id solidobj=[dict objectForKey:XADSolidObjectKey];

	if(solidobj!=currsolidobj)
	{
		[currsolidobj release];
		currsolidobj=[solidobj retain];
		[currsolidhandle release];
		currsolidhandle=[[self handleForSolidStreamWithObject:solidobj wantChecksum:YES] retain];
	}

	if(!currsolidhandle) return nil;

	off_t start=[[dict objectForKey:XADSolidOffsetKey] longLongValue];
	off_t size=[[dict objectForKey:XADSolidLengthKey] longLongValue];
	return [currsolidhandle nonCopiedSubHandleFrom:start length:size];
}



-(NSArray *)volumes
{
	if([sourcehandle respondsToSelector:@selector(handles)]) return [(id)sourcehandle handles];
	else return nil;
}

-(off_t)offsetForVolume:(int)disk offset:(off_t)offset
{
	if([sourcehandle respondsToSelector:@selector(handles)])
	{
		NSArray *handles=[(id)sourcehandle handles];
		int count=[handles count];
		for(int i=0;i<count&&i<disk;i++) offset+=[(CSHandle *)[handles objectAtIndex:i] fileSize];
	}

	return offset;
}



-(void)setObject:(id)object forPropertyKey:(NSString *)key { [properties setObject:object forKey:key]; }

-(void)setIsMacArchive:(BOOL)ismac { [stringsource setPrefersMacEncodings:ismac]; }



-(void)addEntryWithDictionary:(NSMutableDictionary *)dict
{
	[self addEntryWithDictionary:dict retainPosition:NO cyclePools:NO];
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos
{
	[self addEntryWithDictionary:dict retainPosition:retainpos cyclePools:NO];
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict cyclePools:(BOOL)cyclepools
{
	[self addEntryWithDictionary:dict retainPosition:NO cyclePools:cyclepools];
}

-(void)addEntryWithDictionary:(NSMutableDictionary *)dict retainPosition:(BOOL)retainpos cyclePools:(BOOL)cyclepools
{
	// If an encrypted file is added, set the global encryption flag
	NSNumber *enc=[dict objectForKey:XADIsEncryptedKey];
	if(enc&&[enc boolValue]) [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsEncryptedKey];

	// Same for the corrupted flag
	NSNumber *cor=[dict objectForKey:XADIsCorruptedKey];
	if(cor&&[cor boolValue]) [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsCorruptedKey];

	// LinkDestination implies IsLink
	XADString *linkdest=[dict objectForKey:XADLinkDestinationKey];
	if(linkdest) [dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsLinkKey];

	// Extract type, creator and finderflags from finderinfo
	NSData *finderinfo=[dict objectForKey:XADFinderInfoKey];
	if(finderinfo&&[finderinfo length]>=10)
	{
		const uint8_t *bytes=[finderinfo bytes];
		NSNumber *isdir=[dict objectForKey:XADIsDirectoryKey];

		if(!isdir||![isdir boolValue])
		{
			[dict setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+0)] forKey:XADFileTypeKey];
			[dict setObject:[NSNumber numberWithUnsignedInt:CSUInt32BE(bytes+4)] forKey:XADFileCreatorKey];
		}

		[dict setObject:[NSNumber numberWithInt:CSUInt16BE(bytes+8)] forKey:XADFinderFlagsKey];
	}

	// Handle solidness - set FirstSolid, NextSolid and IsSolid depending on SolidObject.
	id solidobj=[dict objectForKey:XADSolidObjectKey];
	if(solidobj)
	{
		if(solidobj==parsersolidobj)
		{
			[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsSolidKey];
			[dict setObject:[NSValue valueWithNonretainedObject:firstsoliddict] forKey:XADFirstSolidEntryKey];
			[prevsoliddict setObject:[NSValue valueWithNonretainedObject:dict] forKey:XADNextSolidEntryKey];

			[prevsoliddict release];
			prevsoliddict=[dict retain];
		}
		else
		{
			parsersolidobj=solidobj;

			[firstsoliddict release];
			[prevsoliddict release];
			firstsoliddict=prevsoliddict=[[dict retain] retain];
		}
	}
	else if(parsersolidobj)
	{
		parsersolidobj=nil;
		[firstsoliddict release];
		firstsoliddict=nil;
		[prevsoliddict release];
		prevsoliddict=nil;
	}

	// If a solid file is added, set the global solid flag
	NSNumber *solid=[dict objectForKey:XADIsSolidKey];
	if(solid&&[solid boolValue]) [self setObject:[NSNumber numberWithBool:YES] forPropertyKey:XADIsSolidKey];

	NSAutoreleasePool *delegatepool=[NSAutoreleasePool new];

	if(retainpos)
	{
		off_t pos=[sourcehandle offsetInFile];
		[delegate archiveParser:self foundEntryWithDictionary:dict];
		[sourcehandle seekToFileOffset:pos];
	}
	else [delegate archiveParser:self foundEntryWithDictionary:dict];

	[delegatepool release];

	if(cyclepools)
	{
		[autopool release];
		autopool=[NSAutoreleasePool new];
	}
}



-(XADString *)XADStringWithString:(NSString *)string
{
	return [[[XADString alloc] initWithString:string] autorelease];
}

-(XADString *)XADStringWithData:(NSData *)data
{
	return [[[XADString alloc] initWithData:data source:stringsource] autorelease];
}

-(XADString *)XADStringWithData:(NSData *)data encodingName:(NSString *)encoding
{
	return [[[XADString alloc] initWithData:data encodingName:encoding] autorelease];
}

-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length
{
	NSData *data=[NSData dataWithBytes:bytes length:length];
	return [[[XADString alloc] initWithData:data source:stringsource] autorelease];
}

-(XADString *)XADStringWithBytes:(const void *)bytes length:(int)length encodingName:(NSString *)encoding
{
	NSData *data=[NSData dataWithBytes:bytes length:length];
	return [[[XADString alloc] initWithData:data encodingName:encoding] autorelease];
}

-(XADString *)XADStringWithCString:(const char *)cstring
{
	NSData *data=[NSData dataWithBytes:cstring length:strlen(cstring)];
	return [[[XADString alloc] initWithData:data source:stringsource] autorelease];
}

-(XADString *)XADStringWithCString:(const char *)cstring encodingName:(NSString *)encoding
{
	NSData *data=[NSData dataWithBytes:cstring length:strlen(cstring)];
	return [[[XADString alloc] initWithData:data encodingName:encoding] autorelease];
}



-(XADPath *)XADPath
{
	return [[XADPath new] autorelease];
}

-(XADPath *)XADPathWithString:(NSString *)string
{
	return [[[XADPath alloc] initWithString:string] autorelease];
}

-(XADPath *)XADPathWithUnseparatedString:(NSString *)string
{
	return [[[XADPath alloc] initWithComponents:[NSArray arrayWithObject:[self XADStringWithString:string]]] autorelease];
}

-(XADPath *)XADPathWithData:(NSData *)data separators:(const char *)separators
{
	return [[[XADPath alloc] initWithBytes:[data bytes] length:[data length]
	separators:separators source:stringsource] autorelease];
}

-(XADPath *)XADPathWithData:(NSData *)data encodingName:(NSString *)encoding separators:(const char *)separators
{
	return [[[XADPath alloc] initWithBytes:[data bytes] length:[data length]
	encodingName:encoding separators:separators] autorelease];
}

-(XADPath *)XADPathWithBytes:(const void *)bytes length:(int)length separators:(const char *)separators
{
	return [[[XADPath alloc] initWithBytes:bytes length:length separators:separators source:stringsource] autorelease];
}

-(XADPath *)XADPathWithBytes:(const void *)bytes length:(int)length encodingName:(NSString *)encoding separators:(const char *)separators
{
	return [[[XADPath alloc] initWithBytes:bytes length:length encodingName:encoding separators:separators] autorelease];
}

-(XADPath *)XADPathWithCString:(const char *)cstring separators:(const char *)separators
{
	return [[[XADPath alloc] initWithBytes:cstring length:strlen(cstring)
	separators:separators source:stringsource] autorelease];
}

-(XADPath *)XADPathWithCString:(const char *)cstring encodingName:(NSString *)encoding separators:(const char *)separators
{
	return [[[XADPath alloc] initWithBytes:cstring length:strlen(cstring)
	encodingName:encoding separators:separators] autorelease];
}



-(NSData *)encodedPassword
{
	return [XADString dataForString:[self password] encodingName:[stringsource encodingName]];
}

-(const char *)encodedCStringPassword
{
	NSMutableData *data=[NSMutableData dataWithData:[self encodedPassword]];
	[data increaseLengthBy:1];
	return [data bytes];
}



+(int)requiredHeaderSize { return 0; }
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name { return NO; }
+(NSArray *)volumesForHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name { return nil; }

-(void)parse {}
-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum { return nil; }
-(NSString *)formatName { return nil; } // TODO: combine names for nested archives

-(CSHandle *)handleForSolidStreamWithObject:(id)obj wantChecksum:(BOOL)checksum { return nil; }


@end


@implementation NSObject (XADArchiveParserDelegate)

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict {}
-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser { return NO; }
-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser { }

@end
