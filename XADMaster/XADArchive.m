#define XAD_NO_DEPRECATED

#import "XADArchive.h"
#import "CSMemoryHandle.h"
#import "CSHandle.h"
#import "Progress.h"
#import "NSDateXAD.h"

#import <sys/stat.h>
#import <sys/time.h>


NSString *XADResourceDataKey=@"XADResourceData";
NSString *XADFinderFlags=@"XADFinderFlags";



@implementation XADArchive

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

+(NSArray *)volumesForFile:(NSString *)filename // deprecated
{
	return [NSArray arrayWithObject:filename];
}




-(id)init
{
	if((self=[super init]))
	{
		parser=nil;
		unarchiver=nil;
		delegate=nil;
		lasterror=XADNoError;
		immediatedestination=nil;
		immediatefailed=NO;
		immediatesize=0;
		parentarchive=nil;

		dataentries=[[NSMutableArray array] retain];
		resourceentries=[[NSMutableArray array] retain];
		namedict=nil;
 	}
	return self;
}

-(id)initWithFile:(NSString *)file { return [self initWithFile:file delegate:nil error:NULL]; }

-(id)initWithFile:(NSString *)file error:(XADError *)error { return [self initWithFile:file delegate:nil error:error]; }

-(id)initWithFile:(NSString *)file delegate:(id)del error:(XADError *)error
{
	if((self=[self init]))
	{
		delegate=del;

		parser=[[XADArchiveParser archiveParserForPath:file] retain];
		if(parser)
		{
			if([self _parseWithErrorPointer:error]) return self;
		}
		else if(error) *error=XADDataFormatError;

		[self release];
	}

	return nil;
}



-(id)initWithData:(NSData *)data { return [self initWithData:data delegate:nil error:NULL]; }

-(id)initWithData:(NSData *)data error:(XADError *)error { return [self initWithData:data delegate:nil error:error]; }

-(id)initWithData:(NSData *)data delegate:(id)del error:(XADError *)error
{
	if((self=[self init]))
	{
		delegate=del;

		parser=[[XADArchiveParser archiveParserForHandle:[CSMemoryHandle memoryHandleForReadingData:data] name:@""] retain];
		if(parser)
		{
			if([self _parseWithErrorPointer:error]) return self;
		}
		else if(error) *error=XADDataFormatError;

		[self release];
	}
	return nil;
}



-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n { return [self initWithArchive:otherarchive entry:n delegate:nil error:NULL]; }

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n error:(XADError *)error { return [self initWithArchive:otherarchive entry:n delegate:nil error:error]; }

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n delegate:(id)del error:(XADError *)error
{
	if((self=[self init]))
	{
		parentarchive=[otherarchive retain];
		delegate=del;

		CSHandle *handle=[otherarchive handleForEntry:n error:error];
		if(handle)
		{
			parser=[[XADArchiveParser archiveParserForHandle:handle name:[otherarchive nameOfEntry:n]] retain];
			if(parser)
			{
				if([self _parseWithErrorPointer:error]) return self;
			}
			else if(error) *error=XADDataFormatError;
		}

		[self release];
	}

	return nil;
}

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n
     immediateExtractionTo:(NSString *)destination error:(XADError *)error
{
	return [self initWithArchive:otherarchive entry:n immediateExtractionTo:destination
	subArchives:NO error:error];
}

-(id)initWithArchive:(XADArchive *)otherarchive entry:(int)n
     immediateExtractionTo:(NSString *)destination subArchives:(BOOL)sub error:(XADError *)error
{
	if((self=[self init]))
	{
		parentarchive=[otherarchive retain];
		immediatedestination=destination;
		immediatesubarchives=sub;
		delegate=otherarchive;

		immediatesize=[otherarchive representativeSizeOfEntry:n];

		parser=[[XADArchiveParser archiveParserForEntryWithDictionary:
		[otherarchive dataForkParserDictionaryForEntry:n]
		archiveParser:otherarchive->parser wantChecksum:YES error:error] retain];
		if(parser)
		{
			if([self _parseWithErrorPointer:error])
			{
				if(!immediatefailed)
				{
					XADError checksumerror=[parser testChecksumWithoutExceptions];
					if(checksumerror)
					{
						lasterror=checksumerror;
						if(error) *error=checksumerror;
						immediatefailed=YES;
					}
				}

				[self updateAttributesForDeferredDirectories];
				immediatedestination=nil;
				return self;
			}
		}
		else if(error) *error=XADSubArchiveError;

		[self release];
	}

	return nil;
}


-(void)dealloc
{
	[parser release];
	[unarchiver release];
	[dataentries release];
	[resourceentries release];
	[namedict release];
	[parentarchive release];

	[super dealloc];
}



-(BOOL)_parseWithErrorPointer:(XADError *)error
{
	unarchiver=[[XADUnarchiver unarchiverForArchiveParser:parser] retain];

	[parser setDelegate:self];
	[unarchiver setDelegate:self];

	namedict=[[NSMutableDictionary dictionary] retain];

	XADError parseerror=[parser parseWithoutExceptions];
	if(parseerror)
	{
		lasterror=parseerror;
		if(error) *error=parseerror;
	}

	if(immediatefailed&&error) *error=lasterror;

	[namedict release];
	namedict=nil;

	return lasterror==XADNoError||[dataentries count]!=0;
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	if(immediatefailed) return; // ignore anything after a failure

	NSNumber *resnum=[dict objectForKey:XADIsResourceForkKey];
	BOOL isres=resnum&&[resnum boolValue];

	XADPath *name=[dict objectForKey:XADFileNameKey];

	NSNumber *index=[namedict objectForKey:name];
	if(index) // Try to update an existing entry
	{
		int n=[index intValue];
		if(isres) // Adding a resource fork to an earlier data fork
		{
			if([resourceentries objectAtIndex:n]==[NSNull null])
			{
				[resourceentries replaceObjectAtIndex:n withObject:dict];

				if(immediatedestination)
				{
					if(![self extractEntry:n to:immediatedestination
					deferDirectories:YES dataFork:NO resourceFork:YES])
					immediatefailed=YES;
				}

				return;
			}
		}
		else // Adding a data fork to an earlier resource fork
		{
			if([dataentries objectAtIndex:n]==[NSNull null])
			{
				[dataentries replaceObjectAtIndex:n withObject:dict];

				if(immediatedestination)
				{
					if(immediatesubarchives&&[self entryIsArchive:n])
					{
						// Try to extract as archive, if the format is unknown, extract as regular file
						BOOL res;
						@try { res=[self extractArchiveEntry:n to:immediatedestination]; }
						@catch(id e) { res=NO; }

						if(!res&&lasterror==XADDataFormatError)
						{
							if(![self extractEntry:n to:immediatedestination
							deferDirectories:YES dataFork:YES resourceFork:NO])
							immediatefailed=YES;
						}
						else immediatefailed=YES;
					}
					else
					{
						if(![self extractEntry:n to:immediatedestination
						deferDirectories:YES dataFork:YES resourceFork:NO])
						immediatefailed=YES;
					}
				}

				return;
			}
		}
	}

	// Create a new entry instead

	if(isres)
	{
		[dataentries addObject:[NSNull null]];
		[resourceentries addObject:dict];
	}
	else
	{
		[dataentries addObject:dict];
		[resourceentries addObject:[NSNull null]];
	}

	[namedict setObject:[NSNumber numberWithInt:[dataentries count]-1] forKey:name];

	if(immediatedestination)
	{
		int n=[dataentries count]-1;
		if(immediatesubarchives&&[self entryIsArchive:n])
		{
			// Try to extract as archive, if the format is unknown, extract as regular file
			BOOL res;
			@try { res=[self extractArchiveEntry:n to:immediatedestination]; }
			@catch(id e) { res=NO; }

			if(!res)
			{
				if(lasterror==XADDataFormatError)
				{
					if(![self extractEntry:n to:immediatedestination
					deferDirectories:YES dataFork:YES resourceFork:YES])
					immediatefailed=YES;
				}
				else immediatefailed=YES;
			}
		}
		else
		{
			if(![self extractEntry:n to:immediatedestination
			deferDirectories:YES dataFork:YES resourceFork:YES])
			immediatefailed=YES;
		}
	}
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return immediatefailed;
}

-(void)archiveParserNeedsPassword:(XADArchiveParser *)parser
{
	[delegate archiveNeedsPassword:self];
}



-(NSString *)filename
{
	return [parser filename];
}

-(NSArray *)allFilenames
{
	return [parser allFilenames];
}

-(NSString *)formatName
{
	if(parentarchive) return [NSString stringWithFormat:@"%@ in %@",[parser formatName],[parentarchive formatName]];
	else return [parser formatName];
}

-(BOOL)isEncrypted { return [parser isEncrypted]; }

-(BOOL)isSolid
{
	NSNumber *issolid=[[parser properties] objectForKey:XADIsSolidKey];
	if(!issolid) return NO;
	return [issolid boolValue];
}

-(BOOL)isCorrupted
{
	NSNumber *iscorrupted=[[parser properties] objectForKey:XADIsCorruptedKey];
	if(!iscorrupted) return NO;
	return [iscorrupted boolValue];
}

-(int)numberOfEntries { return [dataentries count]; }

-(BOOL)immediateExtractionFailed { return immediatefailed; }

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

-(NSString *)comment
{
	return [[parser properties] objectForKey:XADCommentKey];
}



-(void)setDelegate:(id)newdelegate { delegate=newdelegate; }

-(id)delegate { return delegate; }



-(NSString *)password { return [parser password]; }

-(void)setPassword:(NSString *)newpassword { [parser setPassword:newpassword]; }



-(NSStringEncoding)nameEncoding { return [[parser stringSource] encoding]; }

-(void)setNameEncoding:(NSStringEncoding)encoding { [[parser stringSource] setFixedEncoding:encoding]; }




-(XADError)lastError { return lasterror; }

-(void)clearLastError { lasterror=XADNoError; }

-(NSString *)describeLastError { return [XADException describeXADError:lasterror]; }

-(NSString *)describeError:(XADError)error { return [XADException describeXADError:error]; }



-(NSString *)description
{
	return [NSString stringWithFormat:@"XADArchive: %@ (%@, %d entries)",[self filename],[self formatName],[self numberOfEntries]];
}



-(NSDictionary *)dataForkParserDictionaryForEntry:(int)n
{
	id obj=[dataentries objectAtIndex:n];
	if(obj==[NSNull null]) return nil;
	else return obj;
}

-(NSDictionary *)resourceForkParserDictionaryForEntry:(int)n
{
	id obj=[resourceentries objectAtIndex:n];
	if(obj==[NSNull null]) return nil;
	else return obj;
}

-(NSDictionary *)combinedParserDictionaryForEntry:(int)n
{
	NSDictionary *data=[dataentries objectAtIndex:n];
	NSDictionary *resource=[resourceentries objectAtIndex:n];

	if((id)data==[NSNull null]) return resource;
	if((id)resource==[NSNull null]) return data;

	NSMutableDictionary *new=[NSMutableDictionary dictionaryWithDictionary:data];

	id obj;

	obj=[resource objectForKey:XADFileTypeKey];
	if(obj) [new setObject:obj forKey:XADFileTypeKey];
	obj=[resource objectForKey:XADFileCreatorKey];
	if(obj) [new setObject:obj forKey:XADFileCreatorKey];
	obj=[resource objectForKey:XADFinderFlagsKey];
	if(obj) [new setObject:obj forKey:XADFinderFlagsKey];
	obj=[resource objectForKey:XADFinderInfoKey];
	if(obj) [new setObject:obj forKey:XADFinderInfoKey];

	return new;
}

-(NSString *)nameOfEntry:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) dict=[self resourceForkParserDictionaryForEntry:n];

	XADPath *xadname=[dict objectForKey:XADFileNameKey];
	if(!xadname) return nil;

	if(![xadname encodingIsKnown]&&delegate)
	{
		NSStringEncoding encoding=[delegate archive:self encodingForData:[xadname data]
		guess:[xadname encoding] confidence:[xadname confidence]];
		return [xadname sanitizedPathStringWithEncoding:encoding];
	}
	else
	{
		return [xadname sanitizedPathString];
	}
}

-(BOOL)entryHasSize:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	return [dict objectForKey:XADFileSizeKey]?YES:NO;
}

-(off_t)uncompressedSizeOfEntry:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) return 0; // Special case for resource forks without data forks
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	if(!size) return CSHandleMaxLength;
	return [size longLongValue];
}

-(off_t)compressedSizeOfEntry:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) return 0; // Special case for resource forks without data forks
	NSNumber *size=[dict objectForKey:XADCompressedSizeKey];
	if(!size) return CSHandleMaxLength;
	return [size longLongValue];
}

-(off_t)representativeSizeOfEntry:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) return 0; // Special case for resource forks without data forks
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	if(!size) size=[dict objectForKey:XADCompressedSizeKey];
	if(!size) return 1000;
	return [size longLongValue];
}

-(BOOL)entryIsDirectory:(int)n
{
	NSDictionary *dict=[self combinedParserDictionaryForEntry:n];
	NSNumber *isdir=[dict objectForKey:XADIsDirectoryKey];

	return isdir&&[isdir boolValue];
}

-(BOOL)entryIsLink:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	NSNumber *islink=[dict objectForKey:XADIsLinkKey];

	return islink&&[islink boolValue];
}

-(BOOL)entryIsEncrypted:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	NSNumber *isenc=[dict objectForKey:XADIsEncryptedKey];

	return isenc&&[isenc boolValue];
}

-(BOOL)entryIsArchive:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	NSNumber *isarc=[dict objectForKey:XADIsArchiveKey];

	return isarc&&[isarc boolValue];
}

-(BOOL)entryHasResourceFork:(int)n
{
	NSDictionary *resdict=[self resourceForkParserDictionaryForEntry:n];
	if(!resdict) return NO;
	NSNumber *num=[resdict objectForKey:XADFileSizeKey];
	if(!num) return NO;

	return [num intValue]!=0;
}

-(NSString *)commentForEntry:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n]; // TODO: combined or data?
	return [dict objectForKey:XADCommentKey];
}

-(NSDictionary *)attributesOfEntry:(int)n { return [self attributesOfEntry:n withResourceFork:NO]; }

-(NSDictionary *)attributesOfEntry:(int)n withResourceFork:(BOOL)resfork
{
	NSDictionary *dict=[self combinedParserDictionaryForEntry:n];
	NSMutableDictionary *attrs=[NSMutableDictionary dictionary];

	NSDate *creation=[dict objectForKey:XADCreationDateKey];
	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	if(modification) [attrs setObject:modification forKey:NSFileModificationDate];
	if(creation) [attrs setObject:creation forKey:NSFileCreationDate];

	NSNumber *type=[dict objectForKey:XADFileTypeKey];
	if(type) [attrs setObject:type forKey:NSFileHFSTypeCode];

	NSNumber *creator=[dict objectForKey:XADFileCreatorKey];
	if(creator) [attrs setObject:creator forKey:NSFileHFSCreatorCode];

	NSNumber *flags=[dict objectForKey:XADFinderFlagsKey];
	if(flags) [attrs setObject:flags forKey:XADFinderFlagsKey];

	NSNumber *perm=[dict objectForKey:XADPosixPermissionsKey];
	if(perm) [attrs setObject:perm forKey:NSFilePosixPermissions];

	XADString *user=[dict objectForKey:XADPosixUserNameKey];
	if(user)
	{
		NSString *username=[user string];
		if(username) [attrs setObject:username forKey:NSFileOwnerAccountName];
	}

	XADString *group=[dict objectForKey:XADPosixGroupNameKey];
	if(group)
	{
		NSString *groupname=[group string];
		if(groupname) [attrs setObject:groupname forKey:NSFileGroupOwnerAccountName];
	}

	if(resfork)
	{
		NSDictionary *resdict=[self resourceForkParserDictionaryForEntry:n];
		if(resdict)
		{
			for(;;)
			{
				@try
				{
					CSHandle *handle=[parser handleForEntryWithDictionary:resdict wantChecksum:YES];
					if(!handle) [XADException raiseDecrunchException];
					NSData *forkdata=[handle remainingFileContents];
					if([handle hasChecksum]&&![handle isChecksumCorrect]) [XADException raiseChecksumException];

					[attrs setObject:forkdata forKey:XADResourceDataKey];
					break;
				}
				@catch(id e)
				{
					lasterror=[XADException parseException:e];
					XADAction action=[delegate archive:self extractionOfResourceForkForEntryDidFail:n error:lasterror];
					if(action==XADSkipAction) break;
					else if(action!=XADRetryAction) return nil;
				}
			}
		}
	}

	return [NSDictionary dictionaryWithDictionary:attrs];
}

-(CSHandle *)handleForEntry:(int)n
{
	return [self handleForEntry:n error:NULL];
}

-(CSHandle *)handleForEntry:(int)n error:(XADError *)error
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) return [CSMemoryHandle memoryHandleForReadingData:[NSData data]]; // Special case for files with only a resource fork

	@try
	{ return [parser handleForEntryWithDictionary:dict wantChecksum:YES]; }
	@catch(id e)
	{
		lasterror=[XADException parseException:e];
		if(error) *error=lasterror;
	}
	return nil;
}

-(CSHandle *)resourceHandleForEntry:(int)n
{
	return [self resourceHandleForEntry:n error:NULL];
}

-(CSHandle *)resourceHandleForEntry:(int)n error:(XADError *)error
{
	NSDictionary *resdict=[self resourceForkParserDictionaryForEntry:n];
	if(!resdict) return nil;
	NSNumber *isdir=[resdict objectForKey:XADIsDirectoryKey];
	if(isdir&&[isdir boolValue]) return nil;

	@try
	{ return [parser handleForEntryWithDictionary:resdict wantChecksum:YES]; }
	@catch(id e)
	{
		lasterror=[XADException parseException:e];
		if(error) *error=lasterror;
	}
	return nil;
}

-(NSData *)contentsOfEntry:(int)n
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) return [NSData data]; // Special case for files with only a resource fork

	@try
	{
		CSHandle *handle=[parser handleForEntryWithDictionary:dict wantChecksum:YES];
		if(!handle) [XADException raiseDecrunchException];
		NSData *data=[handle remainingFileContents];
		if([handle hasChecksum]&&![handle isChecksumCorrect]) [XADException raiseChecksumException];

		return data;
	}
	@catch(id e)
	{
		lasterror=[XADException parseException:e];
	}
	return nil;
}




// Extraction functions

-(BOOL)extractTo:(NSString *)destination
{
	return [self extractEntries:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[self numberOfEntries])] to:destination subArchives:NO];
}

-(BOOL)extractTo:(NSString *)destination subArchives:(BOOL)sub
{
	return [self extractEntries:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0,[self numberOfEntries])] to:destination subArchives:sub];
}

-(BOOL)extractEntries:(NSIndexSet *)entryset to:(NSString *)destination
{
	return [self extractEntries:entryset to:destination subArchives:NO];
}

-(BOOL)extractEntries:(NSIndexSet *)entryset to:(NSString *)destination subArchives:(BOOL)sub
{
	extractsize=0;
	totalsize=0;

	for(NSUInteger i=[entryset firstIndex];i!=NSNotFound;i=[entryset indexGreaterThanIndex:i])
	totalsize+=[self representativeSizeOfEntry:i];

	int numentries=[entryset count];
	[delegate archive:self extractionProgressFiles:0 of:numentries];
	[delegate archive:self extractionProgressBytes:0 of:totalsize];

	for(NSUInteger i=[entryset firstIndex];i!=NSNotFound;i=[entryset indexGreaterThanIndex:i])
	{
		BOOL res;

		if(sub&&[self entryIsArchive:i])
		{
			@try { res=[self extractArchiveEntry:i to:destination]; }
			@catch(id e) { res=NO; }

			if(!res&&lasterror==XADDataFormatError) // Retry as regular file if the archive format was not known
			{
				res=[self extractEntry:i to:destination deferDirectories:YES];
			}
		}
		else res=[self extractEntry:i to:destination deferDirectories:YES];

		if(!res)
		{
			totalsize=0;
			return NO;
		}

		extractsize+=[self representativeSizeOfEntry:i];

		[delegate archive:self extractionProgressFiles:i+1 of:numentries];
		[delegate archive:self extractionProgressBytes:extractsize of:totalsize];
	}

	[self updateAttributesForDeferredDirectories];

	totalsize=0;
	return YES;
}

-(BOOL)extractEntry:(int)n to:(NSString *)destination
{ return [self extractEntry:n to:destination deferDirectories:NO dataFork:YES resourceFork:YES]; }

-(BOOL)extractEntry:(int)n to:(NSString *)destination deferDirectories:(BOOL)defer
{ return [self extractEntry:n to:destination deferDirectories:defer dataFork:YES resourceFork:YES]; }

-(BOOL)extractEntry:(int)n to:(NSString *)destination deferDirectories:(BOOL)defer
resourceFork:(BOOL)resfork
{ return [self extractEntry:n to:destination deferDirectories:defer dataFork:YES resourceFork:resfork]; }

-(BOOL)extractEntry:(int)n to:(NSString *)destination deferDirectories:(BOOL)defer
dataFork:(BOOL)datafork resourceFork:(BOOL)resfork
{
	if(datafork) [delegate archive:self extractionOfEntryWillStart:n];

	NSString *name;

	while(!(name=[self nameOfEntry:n]))
	{
		if(delegate)
		{
			XADAction action=[delegate archive:self nameDecodingDidFailForEntry:n
			data:[[[self dataForkParserDictionaryForEntry:n] objectForKey:XADFileNameKey] data]];
			if(action==XADSkipAction) return YES;
			else if(action!=XADRetryAction)
			{
				lasterror=XADBreakError;
				return NO;
			}
		}
		else
		{
			lasterror=XADEncodingError;
			return NO;
		}
	}

	if(![name length]) return YES; // Silently ignore unnamed files (or more likely, directories).

	NSString *destfile=[destination stringByAppendingPathComponent:name];
	while(![self _extractEntry:n as:destfile deferDirectories:defer dataFork:datafork resourceFork:resfork])
	{
		if(lasterror==XADBreakError) return NO;
		else if(delegate&&datafork)
		{
			XADAction action=[delegate archive:self extractionOfEntryDidFail:n error:lasterror];

			if(action==XADSkipAction) return YES;
			else if(action!=XADRetryAction) return NO;
		}
		else return NO;
	}

	if(datafork) [delegate archive:self extractionOfEntryDidSucceed:n];

	return YES;
}

-(BOOL)extractArchiveEntry:(int)n to:(NSString *)destination
{
	NSString *path=[destination stringByAppendingPathComponent:
	[[self nameOfEntry:n] stringByDeletingLastPathComponent]];

	for(;;)
	{
		XADError err;
		XADArchive *subarchive=[[XADArchive alloc] initWithArchive:self entry:n
		immediateExtractionTo:path subArchives:YES error:&err];

		if(!subarchive)
		{
			lasterror=err;
		}
		else
		{
			err=[subarchive lastError];
			if(err) lasterror=err;
		}

		BOOL res=subarchive&&![subarchive immediateExtractionFailed];

		[subarchive release];

		if(res) return YES;
		else if(err==XADBreakError||err==XADDataFormatError) return NO;
		else if(delegate)
		{
			XADAction action=[delegate archive:self extractionOfEntryDidFail:n error:err];

			if(action==XADSkipAction) return YES;
			else if(action!=XADRetryAction) return NO;
		}
		else return NO;
	}
}



-(BOOL)_extractEntry:(int)n as:(NSString *)destfile deferDirectories:(BOOL)defer
dataFork:(BOOL)datafork resourceFork:(BOOL)resfork
{
	for(;;)
	{
		XADError error=[unarchiver _ensureDirectoryExists:[destfile stringByDeletingLastPathComponent]];

		if(error==XADNoError)
		{
			break;
		}
		else if(delegate)
		{
			XADAction action=[delegate archive:self creatingDirectoryDidFailForEntry:n];
			if(action==XADSkipAction) return YES;
			else if(action!=XADRetryAction)
			{
				lasterror=XADBreakError;
				return NO;
			}
		}
		else
		{
			lasterror=error;
			return NO;
		}
	}

	struct stat st;
	BOOL isdir=[self entryIsDirectory:n];

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

		if(action==XADOverwriteAction&&!dir) break;
		else if(action==XADSkipAction) return YES;
		else if(action==XADRenameAction) destfile=[[destfile stringByDeletingLastPathComponent] stringByAppendingPathComponent:newname];
		else if(action!=XADRetryAction)
		{
			lasterror=XADBreakError;
			return NO;
		}
	}

	NSDictionary *datadict=[self dataForkParserDictionaryForEntry:n];
	NSDictionary *resdict=[self resourceForkParserDictionaryForEntry:n];

	//extractEntryWithDictionary:(NSDictionary *)dict as:(NSString *)path forceDirectories:(BOOL)force

	if(datafork&&datadict)
	{
		extractingentry=n;
		extractingresource=NO;
		XADError error=[unarchiver extractEntryWithDictionary:datadict as:destfile forceDirectories:!defer];
		if(error) { lasterror=error; return NO; }
	}

	if(resfork&&resdict)
	{
		extractingentry=n;
		extractingresource=YES;
		XADError error=[unarchiver extractEntryWithDictionary:resdict as:destfile forceDirectories:!defer];
		if(error) { lasterror=error; return NO; }
	}

	return YES;
}

-(void)updateAttributesForDeferredDirectories
{
	[unarchiver finishExtractions];
}



-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver;
{
	return delegate&&[delegate archiveExtractionShouldStop:self];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress
{
	if(extractingresource) return;

	off_t size=[self representativeSizeOfEntry:extractingentry];
	off_t progress=fileprogress*size;
	[delegate archive:self extractionProgressForEntry:extractingentry bytes:progress of:size];

	if(totalsize)
	{
		[delegate archive:self extractionProgressBytes:extractsize+progress of:totalsize];
	}
	else if(immediatedestination)
	{
		[delegate archive:self extractionProgressBytes:totalprogress*immediatesize of:immediatesize];
	}
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver destinationForLink:(XADString *)link from:(NSString *)path
{
	NSString *linkstring;
	if(![link encodingIsKnown]&&delegate)
	{
		// TODO: should there be a better way to deal with encodings?
		NSStringEncoding encoding=[delegate archive:self encodingForData:[link data]
		guess:[link encoding] confidence:[link confidence]];
		linkstring=[link stringWithEncoding:encoding];
	}
	else linkstring=[link string];

	return linkstring;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory
{
	if(!delegate||[delegate archive:self shouldCreateDirectory:directory]) return YES;
	else return NO;
}





//
// Deprecated
//

-(int)sizeOfEntry:(int)n // deprecated and broken
{
	NSDictionary *dict=[self dataForkParserDictionaryForEntry:n];
	if(!dict) return 0; // Special case for resource forks without data forks
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	if(!size) return INT_MAX;
	return [size intValue];
}

// Ugly hack to support old versions of Xee.
-(void *)xadFileInfoForEntry:(int)n
{
	struct xadFileInfo
	{
		void *xfi_Next;
		uint32_t xfi_EntryNumber;/* number of entry */
		char *xfi_EntryInfo;  /* additional archiver text */
		void *xfi_PrivateInfo;/* client private, see XAD_OBJPRIVINFOSIZE */
		uint32_t xfi_Flags;      /* see XADFIF_xxx defines */
		char *xfi_FileName;   /* see XAD_OBJNAMESIZE tag */
		char *xfi_Comment;    /* see XAD_OBJCOMMENTSIZE tag */
		uint32_t xfi_Protection; /* AmigaOS3 bits (including multiuser) */
		uint32_t xfi_OwnerUID;   /* user ID */
		uint32_t xfi_OwnerGID;   /* group ID */
		char *xfi_UserName;   /* user name */
		char *xfi_GroupName;  /* group name */
		uint64_t xfi_Size;       /* size of this file */
		uint64_t xfi_GroupCrSize;/* crunched size of group */
		uint64_t xfi_CrunchSize; /* crunched size */
		char *xfi_LinkName;   /* name and path of link */
		struct xadDate {
			uint32_t xd_Micros;  /* values 0 to 999999     */
			int32_t xd_Year;    /* values 1 to 2147483648 */
			uint8_t xd_Month;   /* values 1 to 12         */
			uint8_t xd_WeekDay; /* values 1 to 7          */
			uint8_t xd_Day;     /* values 1 to 31         */
			uint8_t xd_Hour;    /* values 0 to 23         */
			uint8_t xd_Minute;  /* values 0 to 59         */
			uint8_t xd_Second;  /* values 0 to 59         */
		} xfi_Date;
		uint16_t xfi_Generation; /* File Generation [0...0xFFFF] (V3) */
		uint64_t xfi_DataPos;    /* crunched data position (V3) */
		void *xfi_MacFork;    /* pointer to 2nd fork for Mac (V7) */
		uint16_t xfi_UnixProtect;/* protection bits for Unix (V11) */
		uint8_t xfi_DosProtect; /* protection bits for MS-DOS (V11) */
		uint8_t xfi_FileType;   /* XADFILETYPE to define type of exe files (V11) */
		void *xfi_Special;    /* pointer to special data (V11) */
	};

	NSDictionary *dict=[self combinedParserDictionaryForEntry:n];
	NSDate *mod=[dict objectForKey:XADLastModificationDateKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];

	NSMutableData *data=[NSMutableData dataWithLength:sizeof(struct xadFileInfo)];
	struct xadFileInfo *fi=[data mutableBytes];

	if(mod)
	{
		NSCalendarDate *cal=[mod dateWithCalendarFormat:nil timeZone:[NSTimeZone defaultTimeZone]];
		fi->xfi_Date.xd_Year=[cal yearOfCommonEra];
		fi->xfi_Date.xd_Month=[cal monthOfYear];
		fi->xfi_Date.xd_Day=[cal dayOfMonth];
		fi->xfi_Date.xd_Hour=[cal hourOfDay];
		fi->xfi_Date.xd_Minute=[cal minuteOfHour];
		fi->xfi_Date.xd_Second=[cal secondOfMinute];
	}
	else fi->xfi_Flags|=1<<6;

	if(size) fi->xfi_Size=[size longLongValue];
	else fi->xfi_Size=0;

	return fi;
}

-(BOOL)extractEntry:(int)n to:(NSString *)destination overrideWritePermissions:(BOOL)override
{ return [self extractEntry:n to:destination deferDirectories:override resourceFork:YES]; }

-(BOOL)extractEntry:(int)n to:(NSString *)destination overrideWritePermissions:(BOOL)override resourceFork:(BOOL)resfork
{ return [self extractEntry:n to:destination deferDirectories:override resourceFork:resfork]; }

-(void)fixWritePermissions { [self updateAttributesForDeferredDirectories]; }





-(NSStringEncoding)archive:(XADArchive *)archive encodingForData:(NSData *)data guess:(NSStringEncoding)guess confidence:(float)confidence
{ return [delegate archive:archive encodingForData:data guess:guess confidence:confidence]; }

-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n data:(NSData *)data
{ return [delegate archive:archive nameDecodingDidFailForEntry:n data:data]; }

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

-(void)archiveNeedsPassword:(XADArchive *)arc
{ [delegate archiveNeedsPassword:arc]; }

-(void)archive:(XADArchive *)arc extractionOfEntryWillStart:(int)n
{ [delegate archive:arc extractionOfEntryWillStart:n]; }

-(void)archive:(XADArchive *)arc extractionProgressForEntry:(int)n bytes:(off_t)bytes of:(off_t)total
{ [delegate archive:arc extractionProgressForEntry:n bytes:bytes of:total]; }

-(void)archive:(XADArchive *)arc extractionOfEntryDidSucceed:(int)n
{ [delegate archive:arc extractionOfEntryDidSucceed:n]; }

-(XADAction)archive:(XADArchive *)arc extractionOfEntryDidFail:(int)n error:(XADError)error
{ return [delegate archive:arc extractionOfEntryDidFail:n error:error]; }

-(XADAction)archive:(XADArchive *)arc extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error
{ return [delegate archive:arc extractionOfResourceForkForEntryDidFail:n error:error]; }

-(void)archive:(XADArchive *)arc extractionProgressBytes:(off_t)bytes of:(off_t)total
{ [delegate archive:arc extractionProgressBytes:bytes of:total]; }

//-(void)archive:(XADArchive *)arc extractionProgressFiles:(int)files of:(int)total;
//{}

@end



@implementation NSObject (XADArchiveDelegate)

-(NSStringEncoding)archive:(XADArchive *)archive encodingForData:(NSData *)data guess:(NSStringEncoding)guess confidence:(float)confidence
{
	// Default implementation calls old method
	NSMutableData *terminateddata=[[NSMutableData alloc] initWithData:data];
	[terminateddata increaseLengthBy:1]; // append a 0 byte
	NSStringEncoding enc=[self archive:archive encodingForName:[terminateddata bytes] guess:guess confidence:confidence];
	[terminateddata release];
	return enc;
}

-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n data:(NSData *)data
{
	// Default implementation calls old method
	NSMutableData *terminateddata=[[NSMutableData alloc] initWithData:data];
	XADAction action=[self archive:archive nameDecodingDidFailForEntry:n bytes:[terminateddata bytes]];
	[terminateddata release];
	return action;
}

-(BOOL)archiveExtractionShouldStop:(XADArchive *)archive { return NO; }
-(BOOL)archive:(XADArchive *)archive shouldCreateDirectory:(NSString *)directory { return YES; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname { return XADOverwriteAction; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname { return XADSkipAction; }
-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n { return XADAbortAction; }

-(void)archiveNeedsPassword:(XADArchive *)archive {}

-(void)archive:(XADArchive *)archive extractionOfEntryWillStart:(int)n {}
-(void)archive:(XADArchive *)archive extractionProgressForEntry:(int)n bytes:(off_t)bytes of:(off_t)total {}
-(void)archive:(XADArchive *)archive extractionOfEntryDidSucceed:(int)n {}
-(XADAction)archive:(XADArchive *)archive extractionOfEntryDidFail:(int)n error:(XADError)error { return XADAbortAction; }
-(XADAction)archive:(XADArchive *)archive extractionOfResourceForkForEntryDidFail:(int)n error:(XADError)error { return XADAbortAction; }

-(void)archive:(XADArchive *)archive extractionProgressBytes:(off_t)bytes of:(off_t)total {}
-(void)archive:(XADArchive *)archive extractionProgressFiles:(int)files of:(int)total {}

// Deprecated
-(NSStringEncoding)archive:(XADArchive *)archive encodingForName:(const char *)bytes guess:(NSStringEncoding)guess confidence:(float)confidence { return guess; }
-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n bytes:(const char *)bytes { return XADAbortAction; }

@end


