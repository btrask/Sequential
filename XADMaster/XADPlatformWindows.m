#import "XADPlatform.h"
#import "NSDateXAD.h"

#import <windows.h>
#import <sys/stat.h>




// TODO: Implement proper handling of Windows metadata.

@implementation XADPlatform

//
// Archive entry extraction.
//

+(XADError)extractResourceForkEntryWithDictionary:(NSDictionary *)dict
unarchiver:(XADUnarchiver *)unarchiver toPath:(NSString *)destpath
{
	return XADNotSupportedError;
}

+(XADError)updateFileAttributesAtPath:(NSString *)path
forEntryWithDictionary:(NSDictionary *)dict parser:(XADArchiveParser *)parser
preservePermissions:(BOOL)preservepermissions
{
	#if defined(__COCOTRON__)
	const wchar_t *wpath=[path fileSystemRepresentationW];
	#else
	const wchar_t *wpath=(const wchar_t *)[path fileSystemRepresentation];
	#endif
	
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
		HANDLE handle=CreateFileW(wpath,GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,
		NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,NULL);
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

+(XADError)createLinkAtPath:(NSString *)path withDestinationPath:(NSString *)link
{
	return XADNotSupportedError;
}




//
// Archive post-processing.
//

+(id)readCloneableMetadataFromPath:(NSString *)path { return nil; }
+(void)writeCloneableMetadata:(id)metadata toPath:(NSString *)path {}

+(BOOL)copyDateFromPath:(NSString *)src toPath:(NSString *)dest
{
	#if defined(__COCOTRON__)
	const wchar_t *wsrc=[src fileSystemRepresentationW];
	#else
	const wchar_t *wsrc=(const wchar_t *)[src fileSystemRepresentation];
	#endif

    HANDLE srchandle=CreateFileW(wsrc,GENERIC_READ,FILE_SHARE_READ|FILE_SHARE_WRITE, 
	NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,NULL);
	if(srchandle==INVALID_HANDLE_VALUE) return NO;

	FILETIME time;
	if(!GetFileTime(srchandle,NULL,NULL,&time)) { CloseHandle(srchandle); return NO; }

	CloseHandle(srchandle);

	#if defined(__COCOTRON__)
	const wchar_t *wdest=[dest fileSystemRepresentationW];
	#else
	const wchar_t *wdest=(const wchar_t *)[dest fileSystemRepresentation];
	#endif

	HANDLE desthandle=CreateFileW(wdest,GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,
	NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,NULL);
	if(desthandle==INVALID_HANDLE_VALUE) return NO;

	if(!SetFileTime(desthandle,NULL,NULL,&time)) { CloseHandle(desthandle); return NO; }

	CloseHandle(desthandle);

	return YES;
}

+(BOOL)resetDateAtPath:(NSString *)path
{
	SYSTEMTIME now;
	GetSystemTime(&now);

	FILETIME time;
	if(!SystemTimeToFileTime(&now,&time)) return NO;

	#if defined(__COCOTRON__)
	const wchar_t *wpath=[path fileSystemRepresentationW];
	#else
	const wchar_t *wpath=(const wchar_t *)[path fileSystemRepresentation];
	#endif

	HANDLE handle=CreateFileW(wpath,GENERIC_WRITE,FILE_SHARE_READ|FILE_SHARE_WRITE,
	NULL,OPEN_EXISTING,FILE_FLAG_BACKUP_SEMANTICS,NULL);
	if(handle==INVALID_HANDLE_VALUE) return NO;

	if(!SetFileTime(handle,NULL,NULL,&time)) { CloseHandle(handle); return NO; }

	CloseHandle(handle);

	return YES;
}




//
// Path functions.
//

+(BOOL)fileExistsAtPath:(NSString *)path { return [self fileExistsAtPath:path isDirectory:NULL]; }

+(BOOL)fileExistsAtPath:(NSString *)path isDirectory:(BOOL *)isdirptr
{
	#if defined(__COCOTRON__)
	const wchar_t *wpath=[path fileSystemRepresentationW];
	#else
	const wchar_t *wpath=(const wchar_t *)[path fileSystemRepresentation];
	#endif

	struct _stat st;
	if(_wstat(wpath,&st)!=0) return NO;

	if(isdirptr)
	{
		if((st.st_mode&S_IFMT)==S_IFDIR) *isdirptr=YES;
		else *isdirptr=NO;
	}

	return YES;
}

+(NSString *)uniqueDirectoryPathWithParentDirectory:(NSString *)parent
{
	NSDate *now=[NSDate date];
	int64_t t=[now timeIntervalSinceReferenceDate]*1000000000;

	NSString *dirname=[NSString stringWithFormat:@"XADTemp%qd",t];

	if(parent) return [parent stringByAppendingPathComponent:dirname];
	else return dirname;
}

+(NSString *)sanitizedPathComponent:(NSString *)component
{
	static NSCharacterSet *charset=nil;
	if(!charset) charset=[[NSCharacterSet characterSetWithCharactersInString:
	@"\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017"
	@"\020\021\022\023\024\025\026\027\030\031\032\033\034\035\036\037"
	@"\"*:<>?\\/|\000"] retain];

	static XADRegex *regex1=nil;
	if(!regex1) regex1=[[XADRegex regexWithPattern:
	@"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])$" options:REG_ICASE] retain];

	static XADRegex *regex2=nil;
	if(!regex2) regex2=[[XADRegex regexWithPattern:
	@"^(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(\\..*)$" options:REG_ICASE] retain];

	if([component rangeOfCharacterFromSet:charset].location!=NSNotFound)
	{
		NSMutableString *newstring=[NSMutableString stringWithString:component];
		int length=[newstring length];
		for(int i=0;i<length;i++)
		{
			unichar c=[newstring characterAtIndex:i];
			if([charset characterIsMember:c])
			[newstring replaceCharactersInRange:NSMakeRange(i,1) withString:@"_"];
		}
		component=newstring;
	}

	if([regex1 matchesString:component])
	{
		return [component stringByAppendingString:@"_"];
	}

	if([regex2 matchesString:component])
	{
		NSArray *matches=[regex2 capturedSubstringsOfString:component];
		return [NSString stringWithFormat:@"%@_%@",
		[matches objectAtIndex:1],[matches objectAtIndex:2]];
	}

	return component;
}

+(NSArray *)contentsOfDirectoryAtPath:(NSString *)path
{
	return [[NSFileManager defaultManager] directoryContentsAtPath:path];
}

+(BOOL)moveItemAtPath:(NSString *)src toPath:(NSString *)dest
{
	return [[NSFileManager defaultManager] movePath:src toPath:dest handler:nil];
}

+(BOOL)removeItemAtPath:(NSString *)path
{
	return [[NSFileManager defaultManager] removeFileAtPath:path handler:nil];
}




//
// Time functions.
//

+(double)currentTimeInSeconds
{
	return (double)timeGetTime()/1000.0;
}

@end
