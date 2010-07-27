#import "XADUnarchiver.h"
#import "NSDateXAD.h"

#import <windows.h>
#import <sys/stat.h>

// TODO: Implement proper handling of Windows metadata.

@implementation XADUnarchiver (PlatformSpecific)

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asPlatformSpecificForkForFile:(NSString *)destpath
{
	return XADNotSupportedError;
}

-(XADError)_createPlatformSpecificLinkToPath:(NSString *)link from:(NSString *)path
{
	return XADNotSupportedError;
}

-(XADError)_updatePlatformSpecificFileAttributesAtPath:(NSString *)path forEntryWithDictionary:(NSDictionary *)dict
{
	const wchar_t *wpath=[path fileSystemRepresentationW];

	// If the file is read-only, change this temporarily and remember to change back.
	BOOL changedattributes=NO;
	DWORD oldattributes=GetFileAttributesW(wpath);
	if(oldattributes!=INVALID_FILE_ATTRIBUTES&&(oldattributes&FILE_ATTRIBUTE_READONLY))
	{
		SetFileAttributesW(wpath,oldattributes&~INVALID_FILE_ATTRIBUTES);
		changedattributes=YES;
	}

	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	NSDate *creation=[dict objectForKey:XADCreationDateKey];
	NSDate *access=[dict objectForKey:XADLastAccessDateKey];

	if(modification||creation||access)
	{
		HANDLE handle=CreateFileW(wpath,GENERIC_WRITE,FILE_SHARE_WRITE,NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,NULL);
		if(handle==INVALID_HANDLE_VALUE) return XADUnknownError; // TODO: better error

		FILETIME creationtime,lastaccesstime,lastwritetime;

		if(creation) creationtime=[creation FILETIME];
		if(access) lastaccesstime=[access FILETIME];
		if(modification) lastwritetime=[modification FILETIME];

		if(!SetFileTime(handle,
		creation?&creationtime:NULL,
		access?&lastaccesstime:NULL,
		modification?&lastwritetime:NULL))
		{
			CloseHandle(handle);
			return XADUnknownError; // TODO: better error
		}

		CloseHandle(handle);
	}

	NSNumber *attributes=[dict objectForKey:XADWindowsFileAttributesKey];
	if(!attributes) attributes=[dict objectForKey:XADDOSFileAttributesKey];
	if(attributes||changedattributes)
	{
		DWORD newattributes=oldattributes;
		if(attributes) newattributes=[attributes intValue];
		SetFileAttributesW(wpath,newattributes);
	}

	return XADNoError;
}

@end

double _XADUnarchiverGetTime()
{
	return (double)timeGetTime()/1000.0;
}
