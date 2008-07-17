#include <unistd.h>
#include <sys/stat.h>
#include <dirent.h>
#include <fcntl.h>

#import <UniversalDetector/UniversalDetector.h>

#import "XADArchive.h"
#import "XADArchivePipe.h"
#import "XADRegex.h"
#import "ConvertE.c"


static xadUINT32 XADProgressFunc(struct Hook *hook,xadPTR object,struct xadProgressInfo *info);



@implementation XADArchive

-(id)init
{
	if(self=[super init])
	{
		filename=nil;
		volumes=nil;
		memdata=nil;
		parentarchive=nil;
		pipe=nil;

		delegate=nil;
		name_encoding=0;
		password=nil;
		update_interval=0.1;
		update_time=0;

		xmb=NULL;
		archive=NULL;
		progresshook.h_Entry=XADProgressFunc;
		progresshook.h_Data=(void *)self;

		fileinfos=[[NSMutableArray array] retain];
		dittoforks=[[NSMutableDictionary dictionary] retain];
		writeperms=[[NSMutableArray array] retain];

		extractsize=totalsize=0;
		currentry=0;
		immediatedestination=nil;
		immediatefailed=NO;

		detector=nil;
		detected_encoding=NSWindowsCP1252StringEncoding;
		detector_confidence=0;

		lasterror=XADERR_OK;

		if(xmb=xadOpenLibrary(12))
		{
			if(archive=xadAllocObjectA(xmb,XADOBJ_ARCHIVEINFO,NULL))
			{
				return self;
			}
		}
		[self release];
	}
	return nil;
}

-(id)initWithFile:(NSString *)file { return [self initWithFile:file delegate:nil error:NULL]; }

-(id)initWithFile:(NSString *)file error:(XADError *)error { return [self initWithFile:file delegate:nil error:error]; }

-(id)initWithFile:(NSString *)file delegate:(id)del error:(XADError *)error
{
	if(self=[self init])
	{
		volumes=[[XADArchive volumesForFile:file] retain];

		[self setDelegate:del];

		if(volumes)
		{
			filename=[[volumes objectAtIndex:0] retain];

			int n=[volumes count];
			struct xadSplitFile split[n];

			for(int i=0;i<n;i++)
			{
				if(i!=n-1) split[i].xsf_Next=&split[i+1];
				else split[i].xsf_Next=NULL;

				split[i].xsf_Type=XAD_INFILENAME;
				split[i].xsf_Data=(xadPTRINT)[[volumes objectAtIndex:i] fileSystemRepresentation];
				split[i].xsf_Size=0;
			}

			struct TagItem tags[]={
				XAD_INSPLITTED,(xadPTRINT)split,
			TAG_DONE};

			if([self _finishInit:tags error:error]) return self;
		}
		else
		{
			filename=[file retain];

			const char *fsname=[file fileSystemRepresentation];
			struct TagItem tags[]={
				XAD_INFILENAME,(xadPTRINT)fsname,
			TAG_DONE};

			if([self _finishInit:tags error:error]) return self;
		}

		[self release];
	}
	else if(error) *error=XADERR_NOMEMORY;

	return nil;
}

-(id)initWithData:(NSData *)data { return [self initWithData:data error:NULL]; }

-(id)initWithData:(NSData *)data error:(XADError *)error
{
	if(self=[self init])
	{
		memdata=[data retain];

		struct TagItem tags[]={
			XAD_INMEMORY,(xadPTRINT)[data bytes],
			XAD_INSIZE,[data length],
		TAG_DONE};

		if([self _finishInit:tags error:error]) return self;

		[self release];
	}
	else if(error) *error=XADERR_NOMEMORY;

	return nil;
}

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n { return [self initWithArchive:otherarchive entry:n error:NULL]; }

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n error:(XADError *)error
{
	if(error) *error=XADERR_NOMEMORY;

	if(self=[self init])
	{
		parentarchive=[otherarchive retain];
		filename=[[otherarchive nameOfEntry:n] retain];

		if(pipe=[[XADArchivePipe alloc] initWithArchive:otherarchive entry:n bufferSize:1024*1024])
		{
			struct TagItem tags[]={
				XAD_INHOOK,(xadPTRINT)[pipe inHook],
			TAG_DONE};

			if([self _finishInit:tags error:error]) return self;
		}
		else if(error) *error=XADERR_NOMEMORY;

		[self release];
	}
	else if(error) *error=XADERR_NOMEMORY;

	return nil;
}

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n
     immediateExtractionTo:(NSString *)destination error:(XADError *)error
{
	if(self=[self init])
	{
		parentarchive=[otherarchive retain];
		filename=[[otherarchive nameOfEntry:n] retain];
		immediatedestination=destination;

		[self setDelegate:otherarchive];

		if(pipe=[[XADArchivePipe alloc] initWithArchive:otherarchive entry:n bufferSize:1024*1024])
		{
			struct TagItem tags[]={
				XAD_INHOOK,(xadPTRINT)[pipe inHook],
				[otherarchive entryHasSize:n]?TAG_IGNORE:XAD_CLIENT,XADCID_TAR,
			TAG_DONE};

			if([self _finishInit:tags error:error])
			{
				[self fixWritePermissions];
				immediatedestination=nil;
				return self;
			}
		}
		else if(error) *error=XADERR_NOMEMORY;

		[self release];
	}
	else if(error) *error=XADERR_NOMEMORY;

	return nil;
}

-(void)dealloc
{
	xadFreeInfo(xmb,archive); // check?
	xadFreeObjectA(xmb,archive,NULL);

	[filename release];
	[volumes release];
	[memdata release];
	[parentarchive release];
	[pipe dismantle];
	[pipe release];
	[password release];
	[fileinfos release];
	[dittoforks release];
	[writeperms release];
	[detector release];

	[super dealloc];
}



-(BOOL)_finishInit:(xadTAGPTR)tags error:(XADError *)error
{
	struct TagItem alltags[]={ XAD_PROGRESSHOOK,(xadUINT32)&progresshook,TAG_MORE,(xadUINT32)tags,TAG_DONE };

	int err=xadGetInfoA(xmb,archive,alltags);
	if(!err&&archive->xai_DiskInfo)
	{
		xadFreeInfo(xmb,archive);
		err=xadGetDiskInfo(xmb,archive,
			XAD_INDISKARCHIVE,alltags,
		TAG_DONE);
	}
	else if(err==XADERR_FILETYPE) err=xadGetDiskInfoA(xmb,archive,tags);

	if(err)
	{
		if(error) *error=err;
		return NO;
	}

	if(![fileinfos count])
	{
		if(error) *error=XADERR_DATAFORMAT;
		return NO;
	}

	if(error) *error=XADERR_OK;

	return YES;
}

-(xadUINT32)_newEntryCallback:(struct xadProgressInfo *)proginfo
{
	struct xadFileInfo *info=proginfo->xpi_FileInfo;

	// Feed filename to the character set detector
	[self _runDetectorOn:info->xfi_FileName];

	// Skip normal resource forks (except lonely ones)
	if((info->xfi_Flags&XADFIF_MACRESOURCE)&&info->xfi_MacFork)
	{
		// Was this file already extracted without attributes?
		int n=[self _entryIndexOfFileInfo:info->xfi_MacFork];
		if(n!=NSNotFound)
		{
			NSDictionary *attrs=[self attributesOfEntry:n withResourceFork:YES];
			if(attrs) [self _changeAllAttributes:attrs atPath:[immediatedestination stringByAppendingPathComponent:[self nameOfEntry:n]] overrideWritePermissions:YES];
		}
		return XADPIF_OK;
	}

	// Resource forks in ditto archives
	if([self _canHaveDittoResourceForks]&&[self _fileInfoIsDittoResourceFork:info])
	{
//		detected_encoding=NSUTF8StringEncoding;
//		detector_confidence=1;

		NSString *dataname=[self _nameOfDataForkForDittoResourceFork:info];
		if(dataname)
		{
			[dittoforks setObject:[NSValue valueWithPointer:info] forKey:dataname];

			// Doing immediate extraction?
			if(immediatedestination)
			{
				// Was this file already extracted without attributes?
				int n=[self _entryIndexOfName:dataname];
				if(n!=NSNotFound)
				{
					NSDictionary *attrs=[self attributesOfEntry:n withResourceFork:YES];
					if(attrs) [self _changeAllAttributes:attrs atPath:[immediatedestination stringByAppendingPathComponent:dataname] overrideWritePermissions:YES];
				}
			}
		}

		return XADPIF_OK;
	}

	int newindex=[fileinfos count];

	// Check if a resource fork for this file was already erroneously added to the list
	if((info->xfi_Flags&XADFIF_MACDATA)&&info->xfi_MacFork)
	{
		int len=strlen(info->xfi_FileName);
		for(int i=newindex-1;i>=0;i--)
		{
			struct xadFileInfo *other=[[fileinfos objectAtIndex:i] pointerValue];
			int otherlen=strlen(other->xfi_FileName);

			if(strncmp(info->xfi_FileName,other->xfi_FileName,len)==0)
			if(otherlen==len||(otherlen==len+5&&strcmp(other->xfi_FileName+len,".rsrc")==0))
			{
				newindex=i;
				[fileinfos replaceObjectAtIndex:newindex withObject:[NSValue valueWithPointer:info]];
				goto skip;
			}
		}
		// Not found, add entry to the list normally
		[fileinfos addObject:[NSValue valueWithPointer:info]];
	}
	else
	{
		// Add entry to the list
		[fileinfos addObject:[NSValue valueWithPointer:info]];
	}
	skip:

	// Extract the file immediately if requested
	if(immediatedestination)
	{
		if(info->xfi_Flags&(XADFIF_EXTRACTONBUILD|XADFIF_DIRECTORY|XADFIF_LINK))
		{
			if(![self extractEntry:newindex to:immediatedestination overrideWritePermissions:YES])
			{
				immediatefailed=YES;
				return 0;
			}
		}
		else lasterror=XADERR_NOTSUPPORTED;
	}

	return XADPIF_OK;
}



-(NSString *)filename { return filename; }

-(NSArray *)allFilenames
{
	if(volumes) return volumes;
	else return [NSArray arrayWithObject:filename];
}

-(NSString *)formatName
{
	NSString *format=[[[NSString alloc] initWithBytes:archive->xai_Client->xc_ArchiverName
	length:strlen(archive->xai_Client->xc_ArchiverName) encoding:NSISOLatin1StringEncoding] autorelease];
	if(parentarchive) return [NSString stringWithFormat:@"%@ in %@",format,[parentarchive formatName]];
	else return format;
}

-(BOOL)isEncrypted { return archive->xai_Flags&XADAIF_CRYPTED?YES:NO; }

-(BOOL)isCorrupted { return archive->xai_Flags&XADAIF_FILECORRUPT?YES:NO; }

-(BOOL)immediateExtractionFailed { return immediatefailed; }



-(int)numberOfEntries { return [fileinfos count]; }

-(NSString *)nameOfEntry:(int)n
{
	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	char *cname=info->xfi_FileName;
	NSString *name=nil;

/*	if(info->xfi_Flags&XADFIF_XADSTRFILENAME)
	{
//		xadSTRPTR ucsstring=xadConvertName(xmb,CHARSET_UNICODE_UCS2_BIGENDIAN,XAD_XADSTRING,cname,TAG_DONE);
		xadSTRPTR ucsstring=xadConvertName(xmb,CHARSET_ISO_8859_1,XAD_XADSTRING,cname,TAG_DONE);
		if(!ucsstring) return nil;

//		name=[NSString stringWithCString:ucsstring encoding:CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingUTF16LE)];
		name=[NSString stringWithCString:ucsstring encoding:NSISOLatin1StringEncoding];

		xadFreeObjectA(xmb,ucsstring,NULL);
	}
	else*/
	{
		NSStringEncoding encoding=[self encodingForString:cname];
		if(!encoding) return nil;

		// Kludge to use Mac encodings instead of the similar Windows encodings for Mac archives
		if(info->xfi_Flags&(XADFIF_MACDATA|XADFIF_MACRESOURCE))
		{
			NSStringEncoding macjapanese=CFStringConvertEncodingToNSStringEncoding(kCFStringEncodingMacJapanese);
			if(encoding==NSShiftJISStringEncoding) encoding=macjapanese;
			//else if(encoding!=NSUTF8StringEncoding&&encoding!=macjapanese) encoding=NSMacOSRomanStringEncoding;
		}

		// Create a mutable string
		NSMutableString *mutablename=[[[NSMutableString alloc] initWithBytes:cname length:strlen(cname) encoding:encoding] autorelease];
		if(!mutablename) return nil;

		// Changes backslashes to forward slashes
		NSString *separator=[[[NSString alloc] initWithBytes:"\\" length:1 encoding:encoding] autorelease];
		[mutablename replaceOccurrencesOfString:separator withString:@"/" options:0 range:NSMakeRange(0,[mutablename length])];

		// Change the string back to immutable
		name=[NSString stringWithString:mutablename];
	}

	// Clean up path
	NSMutableArray *components=[NSMutableArray arrayWithArray:[name pathComponents]];

	// Drop . anywhere in the path
	for(int i=0;i<[components count];)
	{
		NSString *comp=[components objectAtIndex:i];
		if([comp isEqual:@"."]) [components removeObjectAtIndex:i];
		else i++;
	}

	// Drop all .. that can be dropped
	for(int i=1;i<[components count];)
	{
		NSString *comp1=[components objectAtIndex:i-1];
		NSString *comp2=[components objectAtIndex:i];
		if(![comp1 isEqual:@".."]&&[comp2 isEqual:@".."])
		{
			[components removeObjectAtIndex:i];
			[components removeObjectAtIndex:i-1];
			if(i>1) i--;
		}
		else i++;
	}

	// Drop slashes and .. at the start of the path
	while([components count])
	{
		NSString *first=[components objectAtIndex:0];
		if([first isEqual:@"/"]||[first isEqual:@".."]) [components removeObjectAtIndex:0];
		else break;
	}

	name=[NSString pathWithComponents:components];

	// Strip any possible .rsrc extenstion off resource forks
	if([self _entryIsLonelyResourceFork:n])
	{
		NSString *ext=[name pathExtension];
		if(ext&&[ext isEqual:@"rsrc"]) name=[name stringByDeletingPathExtension];
	}

	return name;
}

-(BOOL)entryHasSize:(int)n
{
	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	return info->xfi_Flags&XADFIF_NOUNCRUNCHSIZE?NO:YES;
}

-(int)sizeOfEntry:(int)n
{
	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	if([self _entryIsLonelyResourceFork:n]) return 0; // Special case for resource forks without data forks
	if(info->xfi_Flags&XADFIF_NOUNCRUNCHSIZE) return info->xfi_CrunchSize; // Return crunched size for files lacking an uncrunched size
	return info->xfi_Size;
}

-(BOOL)entryIsDirectory:(int)n
{
	return [self xadFileInfoForEntry:n]->xfi_Flags&XADFIF_DIRECTORY?YES:NO;
}

-(BOOL)entryIsLink:(int)n
{
	return [self xadFileInfoForEntry:n]->xfi_Flags&XADFIF_LINK?YES:NO;
}

-(BOOL)entryIsEncrypted:(int)n
{
	return [self xadFileInfoForEntry:n]->xfi_Flags&XADFIF_CRYPTED?YES:NO;
}

-(BOOL)entryIsArchive:(int)n
{
	if([self numberOfEntries]==1)
	{
		NSString *ext=[[[self nameOfEntry:0] pathExtension] lowercaseString];
		if(
			[ext isEqual:@"tar"]||
			[ext isEqual:@"sit"]||
			[ext isEqual:@"sea"]||
			[ext isEqual:@"pax"]||
			[ext isEqual:@"cpio"]
		) return YES;
	}

	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	if(info->xfi_Flags&XADFIF_MACBINARY) return YES;

	return NO;
}


#define PARSE_HEX(ptr) (*(ptr)>='0'&&*(ptr)<='9'?*(ptr)-'0':(*(ptr)>='A'&&*(ptr)<='F'?*(ptr)-'A'+10:(*(ptr)>='a'&&*(ptr)<='f'?*(ptr)-'a'-10:0)))

-(NSDictionary *)attributesOfEntry:(int)n { return [self attributesOfEntry:n withResourceFork:NO]; }

-(NSDictionary *)attributesOfEntry:(int)n withResourceFork:(BOOL)resfork
{
	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	NSMutableDictionary *attrs=[NSMutableDictionary dictionary];

	if(info->xfi_Flags&XADFIF_UNIXPROTECTION)
	{
		[attrs setObject:[NSNumber numberWithUnsignedShort:info->xfi_UnixProtect] forKey:NSFilePosixPermissions];
	}
	else if([[self nameOfEntry:n] rangeOfString:@".app/Contents/MacOS/"].location!=NSNotFound)
	{
		// Kludge to make executables in bad app bundles without permission information executable.
		mode_t mask=umask(0); umask(mask);
		[attrs setObject:[NSNumber numberWithUnsignedShort:0777&~mask] forKey:NSFilePosixPermissions];
	}

	if(!(info->xfi_Flags&XADFIF_NODATE))
	{
		xadUINT32 timestamp;
		xadConvertDates(xmb,XAD_DATEXADDATE,&info->xfi_Date,XAD_GETDATEUNIX,&timestamp,TAG_DONE);

		NSDate *date=[NSDate dateWithTimeIntervalSince1970:timestamp];
		[attrs setObject:date forKey:NSFileCreationDate];
		[attrs setObject:date forKey:NSFileModificationDate];
	}

	if(info->xfi_UserName)
	{
		NSString *username=[[[NSString alloc] initWithBytes:info->xfi_UserName length:strlen(info->xfi_UserName)
		encoding:[self encodingForString:info->xfi_UserName]] autorelease];
		if(username) [attrs setObject:username forKey:NSFileOwnerAccountName];
	}

	if(info->xfi_GroupName)
	{
		NSString *groupname=[[[NSString alloc] initWithBytes:info->xfi_GroupName length:strlen(info->xfi_GroupName)
		encoding:[self encodingForString:info->xfi_GroupName]] autorelease];
		if(groupname) [attrs setObject:groupname forKey:NSFileGroupOwnerAccountName];
	}

	if(info->xfi_Comment)
	{
		int len=strlen(info->xfi_Comment);
		xadUINT8 *com=(xadUINT8 *)info->xfi_Comment;

		if(len>=9&&
			((info->xfi_Flags&(XADFIF_MACDATA|XADFIF_MACRESOURCE))
			||((info->xfi_Flags&XADFIF_DIRECTORY)&&com[4]=='/'))
		)
		{
			xadUINT32 type=(com[0]<<24)|(com[1]<<16)|(com[2]<<8)|com[3];
			xadUINT32 creator=(com[5]<<24)|(com[6]<<16)|(com[7]<<8)|com[8];
			xadUINT32 unknown=('?'<<24)|('?'<<16)|('?'<<8)|'?';

			if(type!=unknown) [attrs setObject:[NSNumber numberWithUnsignedLong:type] forKey:NSFileHFSTypeCode];
			if(creator!=unknown) [attrs setObject:[NSNumber numberWithUnsignedLong:creator] forKey:NSFileHFSCreatorCode];

			if(len>=14)
			{
				int num=(PARSE_HEX(com+10)<<12)|(PARSE_HEX(com+11)<<8)|(PARSE_HEX(com+12)<<4)|PARSE_HEX(com+13);
				[attrs setObject:[NSNumber numberWithUnsignedShort:num] forKey:XADFinderFlags];
			}
		}
	}

	struct xadFileInfo *fork=NULL;
	if(info->xfi_Flags&XADFIF_MACRESOURCE) fork=info;
	else if(info->xfi_MacFork) fork=info->xfi_MacFork;

	if(fork&&resfork)
	{
		NSData *forkdata;

		while(!(forkdata=[self _contentsOfFileInfo:fork]))
		{
			if(delegate)
			{
				XADAction action=[delegate archive:self extractionOfResourceForkForEntryDidFail:n error:lasterror];
				if(action==XADSkip) break;
				else if(lasterror!=XADRetry) return nil;
			}
			else return nil;
		}

		if(forkdata) [attrs setObject:forkdata forKey:XADResourceForkData];
	}

	NSValue *val=[dittoforks objectForKey:[self nameOfEntry:n]];
	if(val) [self _parseDittoResourceFork:[val pointerValue] intoAttributes:attrs];

	return [NSDictionary dictionaryWithDictionary:attrs];
}

-(NSData *)contentsOfEntry:(int)n
{
	if([self _entryIsLonelyResourceFork:n]) return [NSData dataWithBytes:"" length:0];
	return [self _contentsOfFileInfo:[self xadFileInfoForEntry:n]];
}

-(NSData *)_contentsOfFileInfo:(struct xadFileInfo *)info
{
	if(info->xfi_Flags&XADFIF_NOUNCRUNCHSIZE) return nil;

	xadSize size=info->xfi_Size;
	void *buffer=malloc(size);

	if(buffer)
	{
		struct TagItem tags[]={
			XAD_OUTMEMORY,(xadPTRINT)buffer,
			XAD_OUTSIZE,size,
		TAG_DONE};

		int err=[self _extractFileInfo:info tags:tags reportProgress:NO];

		if(!err) return [NSData dataWithBytesNoCopy:buffer length:size freeWhenDone:YES];

		lasterror=err;
		free(buffer);
	}
	else lasterror=XADERR_NOMEMORY;

	return nil;
}

-(BOOL)_entryIsLonelyResourceFork:(int)n
{
	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	if(info->xfi_Flags&XADFIF_MACRESOURCE) return YES;
	else return NO;
}

-(int)_entryIndexOfName:(NSString *)name
{
	int numentries=[self numberOfEntries];
	for(int i=0;i<numentries;i++) if([name isEqual:[self nameOfEntry:i]]) return i;
	return NSNotFound;
}

-(int)_entryIndexOfFileInfo:(struct xadFileInfo *)info
{
	int numentries=[self numberOfEntries];
	for(int i=0;i<numentries;i++) if([self xadFileInfoForEntry:i]==info) return i;
	return NSNotFound;
}

-(const char *)_undecodedNameOfEntry:(int)n
{
	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	return info->xfi_FileName;
}


-(BOOL)extractTo:(NSString *)destination
{
	return [self extractEntries:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[self numberOfEntries])] to:destination subArchives:NO];
}

-(BOOL)extractTo:(NSString *)destination subArchives:(BOOL)sub
{
	return [self extractEntries:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[self numberOfEntries])] to:destination subArchives:sub];
}

-(BOOL)extractEntries:(NSIndexSet *)entries to:(NSString *)destination
{
	return [self extractEntries:entries to:destination subArchives:NO];
}

-(BOOL)extractEntries:(NSIndexSet *)entries to:(NSString *)destination subArchives:(BOOL)sub
{
	extractsize=0;
	totalsize=0;

	for(int i=[entries firstIndex];i!=NSNotFound;i=[entries indexGreaterThanIndex:i])
	totalsize+=[self sizeOfEntry:i];

	int numentries=[entries count];
	[delegate archive:self extractionProgressFiles:0 of:numentries];
	[delegate archive:self extractionProgressBytes:0 of:totalsize];

	for(int i=[entries firstIndex];i!=NSNotFound;i=[entries indexGreaterThanIndex:i])
	{
		BOOL res;

		if(sub&&[self entryIsArchive:i]) res=[self extractArchiveEntry:i to:destination];
		else res=[self extractEntry:i to:destination overrideWritePermissions:YES];

		if(!res)
		{
			totalsize=0;
			return NO;
		}

		extractsize+=[self sizeOfEntry:i];

		[delegate archive:self extractionProgressFiles:i+1 of:numentries];
		[delegate archive:self extractionProgressBytes:extractsize of:totalsize];
	}

	[self fixWritePermissions];

	totalsize=0;
	return YES;
}

-(BOOL)extractEntry:(int)n to:(NSString *)destination { return [self extractEntry:n to:destination overrideWritePermissions:NO]; }

-(BOOL)extractEntry:(int)n to:(NSString *)destination overrideWritePermissions:(BOOL)override
{
	[delegate archive:self extractionOfEntryWillStart:n];

	NSString *name;

	while(!(name=[self nameOfEntry:n]))
	{
		if(delegate)
		{
			XADAction action=[delegate archive:self nameDecodingDidFailForEntry:n bytes:[self _undecodedNameOfEntry:n]];
			if(action==XADSkip) return YES;
			else if(action!=XADRetry)
			{
				lasterror=XADERR_BREAK;
				return NO;
			}
		}
		else
		{
			lasterror=XADERR_ENCODING;
			return NO;
		}
	}

	if(![name length]) return YES; // Silently ignore unnamed files (or more likely, directories).

	NSDictionary *attrs=[self attributesOfEntry:n withResourceFork:YES];
	NSString *destfile=[destination stringByAppendingPathComponent:name];

	while(![self _extractEntry:n as:destfile])
	{
		if(lasterror==XADERR_BREAK) return NO;
		else if(delegate)
		{
			XADAction action=[delegate archive:self extractionOfEntryDidFail:n error:lasterror];

			if(action==XADSkip) return YES;
			else if(action!=XADRetry) return NO;
		}
		else return NO;
	}

	if(!attrs) return NO;
	[self _changeAllAttributes:attrs atPath:destfile overrideWritePermissions:override&&[self entryIsDirectory:n]];

	[delegate archive:self extractionOfEntryDidSucceed:n];

	return YES;
}

-(BOOL)extractArchiveEntry:(int)n to:(NSString *)destination
{
	NSString *path=[destination stringByAppendingPathComponent:
	[[self nameOfEntry:n] stringByDeletingLastPathComponent]];

	XADError err;
	XADArchive *subarchive=[[XADArchive alloc] initWithArchive:self entry:n
	immediateExtractionTo:path error:&err];

	if(!subarchive)
	{
		lasterror=err;
		return NO;
	}

	err=[subarchive lastError];
	if(err) lasterror=err;

	BOOL res=![subarchive immediateExtractionFailed];

	[subarchive release];

	return res;
}

-(void)fixWritePermissions
{
	NSEnumerator *enumerator=[writeperms reverseObjectEnumerator];
	for(;;)
	{
		NSString *path=[enumerator nextObject];
		NSNumber *permissions=[enumerator nextObject];
		if(!path||!permissions) break;

		FSRef ref;
		FSCatalogInfo info;
		if(FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation],&ref,NULL)!=noErr) continue;
		if(FSGetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod,&info,NULL,NULL,NULL)!=noErr) continue;

		FSPermissionInfo *pinfo=(FSPermissionInfo *)&info.permissions;
		pinfo->mode=[permissions unsignedShortValue];

		FSSetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod,&info);
	}
}



-(BOOL)_extractEntry:(int)n as:(NSString *)destfile
{
	while(![self _ensureDirectoryExists:[destfile stringByDeletingLastPathComponent]])
	{
		if(delegate)
		{
			XADAction action=[delegate archive:self creatingDirectoryDidFailForEntry:n];
			if(action==XADSkip) return YES;
			else if(action!=XADRetry)
			{
				lasterror=XADERR_BREAK;
				return NO;
			}
		}
		else
		{
			lasterror=XADERR_MAKEDIR;
			return NO;
		}
	}

	struct stat st;
	BOOL isdir=[self entryIsDirectory:n];
	BOOL islink=[self entryIsLink:n];

	if(delegate)
	while(lstat([destfile fileSystemRepresentation],&st)==0)
	{
		BOOL dir=(st.st_mode&S_IFMT)==S_IFDIR;
		NSString *newname=nil;
		XADAction action;

		if(dir)
		{
			if(isdir) return YES;
			else action=[delegate archive:self entry:n collidesWithDirectory:destfile newFilename:&newname];
		}
		else action=[delegate archive:self entry:n collidesWithFile:destfile newFilename:&newname];

		if(action==XADOverwrite&&!dir) break;
		else if(action==XADSkip) return YES;
		else if(action==XADRename) destfile=[[destfile stringByDeletingLastPathComponent] stringByAppendingPathComponent:newname];
		else if(action!=XADRetry)
		{
			lasterror=XADERR_BREAK;
			return NO;
		}
	}

	if(isdir) return [self _extractDirectoryEntry:n as:destfile];
	else if(islink) return [self _extractLinkEntry:n as:destfile];
	else return [self _extractFileEntry:n as:destfile];
}

-(BOOL)_extractFileEntry:(int)n as:(NSString *)destfile
{
	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	XADError err=XADERR_OK;

	currentry=n;

	int fh=open([destfile fileSystemRepresentation],O_WRONLY|O_CREAT|O_TRUNC,0666);

	if(fh>=0)
	{
		if(![self _entryIsLonelyResourceFork:n])
		{
			struct TagItem tags[]={
				XAD_OUTFILEHANDLE,fh,
				XAD_NOKILLPARTIAL,1,
			TAG_DONE};
			err=[self _extractFileInfo:info tags:tags reportProgress:YES];
		}

		close(fh);
	}
	else err=XADERR_OPENFILE;

	currentry=-1;

	if(err)
	{
		lasterror=err;
		return NO;
	}
	return YES;
}

-(BOOL)_extractDirectoryEntry:(int)n as:(NSString *)destfile
{
	return [self _ensureDirectoryExists:destfile];
}

-(BOOL)_extractLinkEntry:(int)n as:(NSString *)destfile
{
	struct xadFileInfo *info=[self xadFileInfoForEntry:n];
	XADError err=XADERR_OK;

	char *clink=info->xfi_LinkName;
	NSString *link=[[[NSString alloc] initWithBytes:clink length:strlen(clink) encoding:[self encodingForString:clink]] autorelease];

	if(link)
	{
/*		if([[NSFileManager defaultManager] fileExistsAtPath:destfile])
		[[NSFileManager defaultManager] removeFileAtPath:destfile handler:nil];

		if(![[NSFileManager defaultManager] createSymbolicLinkAtPath:destfile pathContent:link])
		err=XADERR_OUTPUT;*/

		struct stat st;
		const char *deststr=[destfile fileSystemRepresentation];
		if(lstat(deststr,&st)==0) unlink(deststr);
		if(symlink([link fileSystemRepresentation],deststr)!=0) err=XADERR_OUTPUT;
	}
	else err=XADERR_BADPARAMS;

	if(err)
	{
		lasterror=err;
		return NO;
	}
	return YES;
}

-(xadERROR)_extractFileInfo:(struct xadFileInfo *)info tags:(xadTAGPTR)tags reportProgress:(BOOL)report
{
	const char *pass=[self _encodedPassword];
	return xadFileUnArc(xmb,archive,
		XAD_ENTRYNUMBER,info->xfi_EntryNumber,
		report?XAD_PROGRESSHOOK:TAG_IGNORE,&progresshook,
		pass?XAD_PASSWORD:TAG_IGNORE,pass,
		TAG_MORE,tags,
	TAG_DONE);
}

-(BOOL)_ensureDirectoryExists:(NSString *)directory
{
	if([directory length]==0) return YES;

	struct stat st;
	if(lstat([directory fileSystemRepresentation],&st)==0)
	{
		if((st.st_mode&S_IFMT)==S_IFDIR) return YES;
		else lasterror=XADERR_MAKEDIR;
	}
	else
	{
		if([self _ensureDirectoryExists:[directory stringByDeletingLastPathComponent]])
		{
			if(!delegate||[delegate archive:self shouldCreateDirectory:directory])
			{
				if(mkdir([directory fileSystemRepresentation],0777)==0) return YES;
				else lasterror=XADERR_MAKEDIR;
			}
			else lasterror=XADERR_BREAK;
		}
	}


	return NO;
}

static NSDate *dateForJan1904()
{
	static NSDate *jan1904=nil;
	if(!jan1904) jan1904=[[NSDate dateWithString:@"1904-01-01 00:00:00 +0000"] retain];
	return jan1904;
}

static UTCDateTime NSDateToUTCDateTime(NSDate *date)
{
	NSTimeInterval seconds=[date timeIntervalSinceDate:dateForJan1904()];
	UTCDateTime utc={
		(UInt16)(seconds/4294967296.0),
		(UInt32)seconds,
		(UInt16)(seconds*65536.0)
	};
	return utc;
}

-(BOOL)_changeAllAttributes:(NSDictionary *)attrs atPath:(NSString *)path overrideWritePermissions:(BOOL)override
{
	BOOL res=YES;

	NSData *rsrcfork=[attrs objectForKey:XADResourceForkData];
	if(rsrcfork) res=[rsrcfork writeToFile:[path stringByAppendingString:@"/..namedfork/rsrc"] atomically:NO]&&res;

	FSRef ref;
	FSCatalogInfo info;
	if(FSPathMakeRef((const UInt8 *)[path fileSystemRepresentation],&ref,NULL)!=noErr) return NO;
	if(FSGetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod,&info,NULL,NULL,NULL)!=noErr) return NO;

	NSNumber *permissions=[attrs objectForKey:NSFilePosixPermissions];
	FSPermissionInfo *pinfo=(FSPermissionInfo *)&info.permissions;
	if(permissions)
	{
		pinfo->mode=[permissions unsignedShortValue];

		if(override&&!(pinfo->mode&0700))
		{
			pinfo->mode|=0700;
			[writeperms addObject:permissions];
			[writeperms addObject:path];
		}
	}

	NSDate *creation=[attrs objectForKey:NSFileCreationDate];
	NSDate *modification=[attrs objectForKey:NSFileModificationDate];

	if(creation) info.createDate=NSDateToUTCDateTime(creation);
	if(modification) info.contentModDate=NSDateToUTCDateTime(modification);

	NSNumber *type=[attrs objectForKey:NSFileHFSTypeCode];
	NSNumber *creator=[attrs objectForKey:NSFileHFSCreatorCode];
	NSNumber *finderflags=[attrs objectForKey:XADFinderFlags];
	FileInfo *finfo=(FileInfo *)&info.finderInfo;

	if(type) finfo->fileType=[type unsignedLongValue];
	if(creator) finfo->fileCreator=[creator unsignedLongValue];
	if(finderflags) finfo->finderFlags=[finderflags unsignedShortValue];

	if(FSSetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod,&info)!=noErr) return NO;

	return res;
}



-(NSString *)commonTopDirectory
{
	NSString *firstname=[self nameOfEntry:0];
	NSRange slash=[firstname rangeOfString:@"/"];

	NSString *directory;
	if(slash.location!=NSNotFound) directory=[firstname substringToIndex:slash.location];
	else if([self entryIsDirectory:0]) directory=firstname;
	else return nil;

	NSString *dirprefix=[directory stringByAppendingString:@"/"];

	int numentries=[self numberOfEntries];
	for(int i=1;i<numentries;i++)
	if(![[self nameOfEntry:i] hasPrefix:dirprefix]) return nil;

	return directory;
}



-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(id)delegate { return delegate; }




-(NSStringEncoding)nameEncoding { return name_encoding?name_encoding:detected_encoding; }

-(void)setNameEncoding:(NSStringEncoding)encoding { name_encoding=encoding; }

-(NSStringEncoding)encodingForString:(const char *)cstr
{
	if(name_encoding) return name_encoding;
	else
	{
		if([self _stringIsASCII:cstr]) return NSASCIIStringEncoding;

		if(delegate) return [delegate archive:self encodingForName:cstr guess:detected_encoding confidence:detector_confidence];
		else return detected_encoding;
	}
}

-(BOOL)_stringIsASCII:(const char *)cstr
{
	for(int i=0;cstr[i];i++) if(cstr[i]&0x80) return NO;
	return YES;
}

-(void)_runDetectorOn:(const char *)cstr
{
	if(!detector)
	{
		if([UniversalDetector class]) detector=[[UniversalDetector alloc] init];
	}

	if(detector)
	{
		[detector analyzeBytes:cstr length:strlen(cstr)];
		detected_encoding=[detector encoding];
		detector_confidence=[detector confidence];
		if(detected_encoding) return;
	}

	detected_encoding=NSWindowsCP1252StringEncoding;
	detector_confidence=0;
}



-(NSString *)password { return password; }

-(void)setPassword:(NSString *)newpassword
{
	[password autorelease];
	password=[newpassword retain];
}

-(const char *)_encodedPassword
{
	NSStringEncoding encoding;
	if(name_encoding) encoding=name_encoding;
	else if(detected_encoding) encoding=detected_encoding;
	else encoding=NSWindowsCP1252StringEncoding;

	NSMutableData *encoded=[[password dataUsingEncoding:encoding] mutableCopy];
	[encoded increaseLengthBy:1]; // add a single byte, which will be initialized as 0
	return [encoded bytes];

//	return [password cStringUsingEncoding:encoding];
}


-(void)setProgressInterval:(NSTimeInterval)interval
{
	update_interval=interval;
}

-(xadUINT32)_progressCallback:(struct xadProgressInfo *)info
{
	struct timeval tv;
	gettimeofday(&tv,NULL);
	double currtime=(double)tv.tv_sec+(double)tv.tv_usec/1000000.0;

	if(currtime-update_time<update_interval) return XADPIF_OK;
	update_time=currtime;

	int progress,filesize;
	if(info->xpi_FileInfo->xfi_Flags&XADFIF_NOUNCRUNCHSIZE)
	{
		progress=archive->xai_InPos-info->xpi_FileInfo->xfi_DataPos;
		filesize=info->xpi_FileInfo->xfi_CrunchSize;
	}
	else
	{
		progress=info->xpi_CurrentSize;
		filesize=info->xpi_FileInfo->xfi_Size;
	}

	[delegate archive:self extractionProgressForEntry:currentry bytes:progress of:filesize];

	if(totalsize)
	[delegate archive:self extractionProgressBytes:extractsize+progress of:totalsize];

	return XADPIF_OK;
}



-(BOOL)_canHaveDittoResourceForks
{
	if(!strcmp(archive->xai_Client->xc_ArchiverName,"Zip")) return YES;
	if(!strcmp(archive->xai_Client->xc_ArchiverName,"Tar")) return YES;
	if(!strcmp(archive->xai_Client->xc_ArchiverName,"Cpio")) return YES;
	return NO;
}

-(BOOL)_fileInfoIsDittoResourceFork:(struct xadFileInfo *)info
{
//	NSString *name=[NSString stringWithUTF8String:info->xfi_FileName];
//	if(!name) return NO;
//	return [name isEqual:@"__MACOSX"]||[name hasPrefix:@"__MACOSX/"]||[[name lastPathComponent] hasPrefix:@"._"];
	if(strcmp(info->xfi_FileName,"__MACOSX")==0) return YES;
	if(strncmp(info->xfi_FileName,"__MACOSX/",9)==0) return YES;
	xadSTRPTR last=strrchr(info->xfi_FileName,'/');
	if(last)
	{
		if(strncmp(last,"/._",3)==0) return YES;
	}
	else
	{
		if(strncmp(info->xfi_FileName,"._",2)==0) return YES;
	}

	return NO;
}

-(NSString *)_nameOfDataForkForDittoResourceFork:(struct xadFileInfo *)info
{
	if(![self _fileInfoIsDittoResourceFork:info]) return nil;
	if(info->xfi_Flags&XADFIF_DIRECTORY) return nil; // Skip directories under __MACOS/

	NSString *name=[NSString stringWithUTF8String:info->xfi_FileName];

	if([name hasPrefix:@"__MACOSX/"]) name=[name substringFromIndex:9];
	else if([name hasPrefix:@"./"]) name=[name substringFromIndex:2];
	NSString *filepart=[name lastPathComponent];
	NSString *pathpart=[name stringByDeletingLastPathComponent];
	if([filepart hasPrefix:@"._"]) filepart=[filepart substringFromIndex:2];
	NSString *dataname=[pathpart stringByAppendingPathComponent:filepart];

	return dataname;
}


-(void)_parseDittoResourceFork:(struct xadFileInfo *)info intoAttributes:(NSMutableDictionary *)attrs
{
	NSData *apple=[self _contentsOfFileInfo:info];
	if(apple)
	{
		int len=[apple length];
		const void *bytes=[apple bytes];

		if(len>=26&&EndGetM32(bytes)==0x00051607&&EndGetM32(bytes+4)==0x00020000)
		{
			int num=EndGetM16(bytes+24);
			if(len>=26+num*12)
			{
				for(int i=0;i<num;i++)
				{
					unsigned long entryid=EndGetM32(bytes+26+i*12+0);
					unsigned long entryoffs=EndGetM32(bytes+26+i*12+4);
					unsigned long entrylen=EndGetM32(bytes+26+i*12+8);

					if(entryoffs+entrylen<=len)
					switch(entryid)
					{
						case 2: // resource fork
							[attrs setObject:[apple subdataWithRange:NSMakeRange(entryoffs,entrylen)] forKey:XADResourceForkData];
						break;
						case 9: // finder
							[attrs setObject:[NSNumber numberWithUnsignedLong:EndGetM32(bytes+entryoffs)] forKey:NSFileHFSTypeCode];
							[attrs setObject:[NSNumber numberWithUnsignedLong:EndGetM32(bytes+entryoffs+4)] forKey:NSFileHFSCreatorCode];
							[attrs setObject:[NSNumber numberWithUnsignedShort:EndGetM16(bytes+entryoffs+8)] forKey:XADFinderFlags];
						break;
					}
				}
			}
		}
	}
}



-(XADError)lastError { return lasterror; }

-(void)clearLastError { lasterror=XADERR_OK; }

-(NSString *)describeLastError { return [self describeError:lasterror]; }

-(NSString *)describeError:(XADError)error
{
	switch(error)
	{
		case XADERR_OK:				return nil;
		case XADERR_UNKNOWN:		return @"Unknown error";
		case XADERR_INPUT:			return @"Input data buffers border exceeded";
		case XADERR_OUTPUT:			return @"Output data buffers border exceeded";
		case XADERR_BADPARAMS:		return @"Function called with illegal parameters";
		case XADERR_NOMEMORY:		return @"Not enough memory available";
		case XADERR_ILLEGALDATA:	return @"Data is corrupted";
		case XADERR_NOTSUPPORTED:	return @"Command is not supported";
		case XADERR_RESOURCE:		return @"Required resource missing";
		case XADERR_DECRUNCH:		return @"Error on decrunching";
		case XADERR_FILETYPE:		return @"Unknown file type";
		case XADERR_OPENFILE:		return @"Opening file failed";
		case XADERR_SKIP:			return @"File, disk has been skipped";
		case XADERR_BREAK:			return @"User break in progress hook";
		case XADERR_FILEEXISTS:		return @"File already exists";
		case XADERR_PASSWORD:		return @"Missing or wrong password";
		case XADERR_MAKEDIR:		return @"Could not create directory";
		case XADERR_CHECKSUM:		return @"Wrong checksum";
		case XADERR_VERIFY:			return @"Verify failed (disk hook)";
		case XADERR_GEOMETRY:		return @"Wrong drive geometry";
		case XADERR_DATAFORMAT:		return @"Unknown data format";
		case XADERR_EMPTY:			return @"Source contains no files";
		case XADERR_FILESYSTEM:		return @"Unknown filesystem";
		case XADERR_FILEDIR:		return @"Name of file exists as directory";
		case XADERR_SHORTBUFFER:	return @"Buffer was too short";
		case XADERR_ENCODING:		return @"Text encoding was defective";
	}
	return nil;
}



-(struct xadMasterBase *)xadMasterBase { return xmb; }

-(struct xadArchiveInfo *)xadArchiveInfo { return archive; }

-(struct xadFileInfo *)xadFileInfoForEntry:(int)n { return (struct xadFileInfo *)[[fileinfos objectAtIndex:n] pointerValue]; }




-(NSString *)description
{
	return [NSString stringWithFormat:@"XADArchive: %@ (%@, %d entries)",filename,[self formatName],[self numberOfEntries]];
}



+(XADArchive *)archiveForFile:(NSString *)filename
{
	return [[[XADArchive alloc] initWithFile:filename] autorelease];
}

+(XADArchive *)recursiveArchiveForFile:(NSString *)filename
{
	XADArchive *archive=[self archiveForFile:filename];

	while([archive numberOfEntries]==1)
	{
		XADArchive *subarchive=[[XADArchive alloc] initWithArchive:archive entry:0];
		if(subarchive) archive=[subarchive autorelease];
		else
		{
			[subarchive release];
			break;
		}
	}

	return archive;
}

static int XADVolumeSort(NSString *str1,NSString *str2,void *dummy)
{
	BOOL israr1=[[str1 lowercaseString] hasSuffix:@".rar"];
	BOOL israr2=[[str2 lowercaseString] hasSuffix:@".rar"];

	if(israr1&&!israr2) return NSOrderedAscending;
	else if(!israr1&&israr2) return NSOrderedDescending;
	else return [str1 compare:str2 options:NSCaseInsensitiveSearch|NSNumericSearch];
}

+(NSArray *)volumesForFile:(NSString *)filename
{
	NSString *namepart=[filename lastPathComponent];
	NSString *dirpart=[filename stringByDeletingLastPathComponent];
	NSArray *matches;
	NSString *pattern;

	if(matches=[namepart substringsCapturedByPattern:@"^(.*)\\.part[0-9]+\\.rar$" options:REG_ICASE])
	{
		pattern=[NSString stringWithFormat:@"^%@\\.part[0-9]+\\.rar$",[[matches objectAtIndex:1] escapedPattern]];
	}
	else if(matches=[namepart substringsCapturedByPattern:@"^(.*)\\.(rar|r[0-9]{2}|s[0-9]{2})$" options:REG_ICASE])
	{
		pattern=[NSString stringWithFormat:@"^%@\\.(rar|r[0-9]{2}|s[0-9]{2})$",[[matches objectAtIndex:1] escapedPattern]];
	}
	else if(matches=[namepart substringsCapturedByPattern:@"^(.*)\\.[0-9]+$"])
	{
		pattern=[NSString stringWithFormat:@"^%@\\.[0-9]+$",[[matches objectAtIndex:1] escapedPattern]];
	}
	else return nil;

	XADRegex *regex=[XADRegex regexWithPattern:pattern options:REG_ICASE];
	NSMutableArray *files=[NSMutableArray array];

	DIR *dir=opendir([dirpart fileSystemRepresentation]);

	struct dirent *ent;
	while(ent=readdir(dir))
	{
		NSString *entname=[NSString stringWithUTF8String:ent->d_name];
		if([regex matchesString:entname]) [files addObject:
		[dirpart stringByAppendingPathComponent:entname]];
	}

	if([files count]<=1) return nil;

	return [files sortedArrayUsingFunction:XADVolumeSort context:NULL];
}



-(NSStringEncoding)archive:(XADArchive *)arc encodingForName:(const char *)bytes guess:(NSStringEncoding)guess confidence:(float)confidence
{ return  [self encodingForString:bytes]; }

-(XADAction)archive:(XADArchive *)arc nameDecodingDidFailForEntry:(int)n bytes:(const char *)bytes
{ return [delegate archive:arc nameDecodingDidFailForEntry:n bytes:bytes]; }

-(BOOL)archiveExtractionShouldStop:(XADArchive *)arc
{ return [delegate archiveExtractionShouldStop:arc]; }

-(BOOL)archive:(XADArchive *)arc shouldCreateDirectory:(NSString *)directory
{ return [delegate archive:arc shouldCreateDirectory:directory]; }

-(XADAction)archive:(XADArchive *)arc entry:(int)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname
{ return [delegate archive:arc entry:n collidesWithFile:file newFilename:newname]; }

-(XADAction)archive:(XADArchive *)arc entry:(int)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname
{ return [delegate archive:arc entry:n collidesWithDirectory:file newFilename:newname]; }

-(XADAction)archive:(XADArchive *)arc creatingDirectoryDidFailForEntry:(int)n
{ return [delegate archive:arc creatingDirectoryDidFailForEntry:n]; }

-(void)archive:(XADArchive *)arc extractionOfEntryWillStart:(int)n
{ [delegate archive:arc extractionOfEntryWillStart:n]; }

-(void)archive:(XADArchive *)arc extractionProgressForEntry:(int)n bytes:(xadSize)bytes of:(xadSize)total
{ [delegate archive:arc extractionProgressForEntry:n bytes:bytes of:total]; }

-(void)archive:(XADArchive *)arc extractionOfEntryDidSucceed:(int)n
{ [delegate archive:arc extractionOfEntryDidSucceed:n]; }

-(XADAction)archive:(XADArchive *)arc extractionOfEntryDidFail:(int)n error:(XADError)error
{ return [delegate archive:arc extractionOfEntryDidFail:n error:error]; }

-(XADAction)archive:(XADArchive *)arc extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error
{ return [delegate archive:arc extractionOfResourceForkForEntryDidFail:n error:error]; }

//-(void)archive:(XADArchive *)arc extractionProgressBytes:(xadSize)bytes of:(xadSize)total
//{}

//-(void)archive:(XADArchive *)arc extractionProgressFiles:(int)files of:(int)total;
//{}

@end



@implementation NSObject (XADArchiveDelegate)

-(NSStringEncoding)archive:(XADArchive *)archive encodingForName:(const char *)bytes guess:(NSStringEncoding)guess confidence:(float)confidence { return guess; }
-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n bytes:(const char *)bytes { return XADAbort; }

-(BOOL)archiveExtractionShouldStop:(XADArchive *)archive { return NO; }
-(BOOL)archive:(XADArchive *)archive shouldCreateDirectory:(NSString *)directory { return YES; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname { return XADOverwrite; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname { return XADSkip; }
-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n { return XADAbort; }

-(void)archive:(XADArchive *)archive extractionOfEntryWillStart:(int)n {}
-(void)archive:(XADArchive *)archive extractionProgressForEntry:(int)n bytes:(xadSize)bytes of:(xadSize)total {}
-(void)archive:(XADArchive *)archive extractionOfEntryDidSucceed:(int)n {}
-(XADAction)archive:(XADArchive *)archive extractionOfEntryDidFail:(int)n error:(XADError)error { return XADAbort; }
-(XADAction)archive:(XADArchive *)archive extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error { return XADAbort; }

-(void)archive:(XADArchive *)archive extractionProgressBytes:(xadSize)bytes of:(xadSize)total {}
-(void)archive:(XADArchive *)archive extractionProgressFiles:(int)files of:(int)total {}

@end



static xadUINT32 XADProgressFunc(struct Hook *hook,xadPTR object,struct xadProgressInfo *info)
{
	XADArchive *archive=(XADArchive *)hook->h_Data;
	id delegate=[archive delegate];

	if(delegate&&[delegate archiveExtractionShouldStop:archive]) return 0;

	switch(info->xpi_Mode)
	{
		case XADPMODE_PROGRESS:
			return [archive _progressCallback:info];
		break;

		case XADPMODE_NEWENTRY:
			return [archive _newEntryCallback:info];
		break;

		case XADPMODE_END: // handled in class
		case XADPMODE_ERROR: // handled in class
		case XADPMODE_GETINFOEND: // handled in class
		default:
		break;
	}

	return XADPIF_OK;
}
