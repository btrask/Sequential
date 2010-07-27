#import "XADUnarchiver.h"
#import "NSDateXAD.h"

#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <sys/time.h>

@implementation XADUnarchiver (PlatformSpecific)

-(XADError)_extractResourceForkEntryWithDictionary:(NSDictionary *)dict asPlatformSpecificForkForFile:(NSString *)destpath
{
	return XADNotSupportedError;
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

	struct stat st;
	if(stat(cpath,&st)!=0) return XADOpenFileError; // TODO: better error

	// If the file does not have write permissions, change this temporarily
	// and remember to change back.
	BOOL changedpermissions=NO;
	if(!(st.st_mode&S_IWUSR))
	{
		chmod(cpath,0700);
		changedpermissions=YES;
	}

	// Handle timestamps.
	NSDate *modification=[dict objectForKey:XADLastModificationDateKey];
	NSDate *access=[dict objectForKey:XADLastAccessDateKey];

	if(modification||access)
	{
		struct timeval times[2]={
			{st.st_atim.tv_sec,st.st_atim.tv_nsec/1000},
			{st.st_mtim.tv_sec,st.st_mtim.tv_nsec/1000},
		};

		if(access) times[0]=[access timevalStruct];
		if(modification) times[1]=[modification timevalStruct];

		if(utimes(cpath,times)!=0) return XADUnknownError; // TODO: better error
	}

	// Handle permissions (or change back to original permissions if they were changed).
	NSNumber *permissions=[dict objectForKey:XADPosixPermissionsKey];
	if(permissions||changedpermissions)
	{
		mode_t mode=st.st_mode;

		if(permissions)
		{
			mode=[permissions unsignedShortValue];
			if(!preservepermissions)
			{
				mode_t mask=umask(022);
				umask(mask); // This is stupid. Is there no sane way to just READ the umask?
				mode&=~(mask|S_ISUID|S_ISGID);
			}
		}

		if(chmod(cpath,mode&~S_IFMT)!=0) return XADUnknownError; // TODO: bette error
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
