#import "XADUnarchiver.h"
#import "CSFileHandle.h"
#import "NSDateXAD.h"

#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <sys/time.h>

@implementation XADUnarchiver (PlatformSpecific)

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asPlatformSpecificForkForFile:(NSString *)destpath
{
	// Make sure a plain file exists at this path before proceeding.
	const char *cpath=[destpath fileSystemRepresentation];
	struct stat st;
	if(lstat(cpath,&st)==0)
	{
		// If something exists that is not a regular file, try deleting it.
		if((st.st_mode&S_IFMT)!=S_IFREG)
		{
			if(unlink(cpath)!=0) return XADOpenFileError; // TODO: better error
		}
	}
	else
	{
		// If nothing exists, create an empty file.
		int fh=open(cpath,O_WRONLY|O_CREAT|O_TRUNC,0666);
		if(fh==-1) return XADOpenFileError;
		close(fh);
	}

	// Then, unpack to resource fork.
	NSString *forkpath=[destpath stringByAppendingPathComponent:@"..namedfork/rsrc"];
	int originalpermissions=-1;
	CSHandle *fh=nil;

	@try { fh=[CSFileHandle fileHandleForWritingAtPath:forkpath]; }
	@catch(id e) {}

	// If opening the resource fork failed, change permissions on the file and try again.
	if(!fh)
	{
		struct stat st;
		stat(cpath,&st);
		originalpermissions=st.st_mode;

		chmod(cpath,0700);

		@try { fh=[CSFileHandle fileHandleForWritingAtPath:forkpath]; }
		@catch(id e) { return XADOpenFileError; }
	}

	XADError error=[self _extractEntryWithDictionary:dict toHandle:fh];

	[fh close];

	if(originalpermissions!=-1) chmod(cpath,originalpermissions);

	return error;
}

-(XADError)_createPlatformSpecificLinkToPath:(NSString *)link from:(NSString *)path
{
	struct stat st;
	const char *destcstr=[path fileSystemRepresentation];
	if(lstat(destcstr,&st)==0) unlink(destcstr);
	if(symlink([link fileSystemRepresentation],destcstr)!=0) return XADOutputError;

	return XADNoError;
}

-(XADError)_updatePlatformSpecificFileAttributesAtPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict
{
	const char *cpath=[path fileSystemRepresentation];

	FSRef ref;
	FSCatalogInfo info;
	if(FSPathMakeRefWithOptions((const UInt8 *)cpath,
	kFSPathMakeRefDoNotFollowLeafSymlink,&ref,NULL)!=noErr) return NO;
	if(FSGetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod|kFSCatInfoAccessDate,&info,NULL,NULL,NULL)!=noErr) return NO;

	NSNumber *permissions=[dict objectForKey:XADPosixPermissionsKey];
	FSPermissionInfo *pinfo=(FSPermissionInfo *)&info.permissions;
	if(permissions)
	{
		mode_t mask=umask(022);
		umask(mask); // This is stupid. Is there no sane way to just READ the umask?
		pinfo->mode=[permissions unsignedShortValue]&~(mask|S_ISUID|S_ISGID);
	}

	NSDate *creation=[dict objectForKey:XADCreationDateKey];
	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	NSDate *access=[dict objectForKey:XADLastAccessDateKey];

	if(creation) info.createDate=[creation UTCDateTime];
	if(modification) info.contentModDate=[modification UTCDateTime];
	if(access) info.accessDate=[access UTCDateTime];

	// TODO: Handle FinderInfo structure
	NSNumber *type=[dict objectForKey:XADFileTypeKey];
	NSNumber *creator=[dict objectForKey:XADFileCreatorKey];
	NSNumber *finderflags=[dict objectForKey:XADFinderFlagsKey];
	FileInfo *finfo=(FileInfo *)&info.finderInfo;

	if(type) finfo->fileType=[type unsignedLongValue];
	if(creator) finfo->fileCreator=[creator unsignedLongValue];
	if(finderflags) finfo->finderFlags=[finderflags unsignedShortValue];

	if(FSSetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod|kFSCatInfoAccessDate,&info)!=noErr)
	{
		chmod(cpath,0700);
		if(FSSetCatalogInfo(&ref,kFSCatInfoFinderInfo|kFSCatInfoPermissions|kFSCatInfoCreateDate|kFSCatInfoContentMod|kFSCatInfoAccessDate,&info)!=noErr)
		return XADUnknownError; // TODO: better error
	}

	return XADNoError;
}

@end

double _XADUnarchiverGetTime()
{
	struct timeval tv;
	gettimeofday(&tv,NULL);
	return (double)tv.tv_sec+(double)tv.tv_usec/1000000.0;
}
