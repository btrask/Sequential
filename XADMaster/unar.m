#import "XADUnarchiver.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CommandLineCommon.h"

#define VERSION_STRING @"v0.2"


BOOL recurse;



@interface Unarchiver:NSObject
{
	int indent;
}
@end

@implementation Unarchiver

-(id)init
{
	if(self=[super init])
	{
		indent=1;
	}
	return self;
}

-(void)printIndention
{
	for(int i=0;i<indent;i++) [@"  " print];
}

-(void)unarchiverNeedsPassword:(XADUnarchiver *)unarchiver
{
	[@"This archive requires a password to unpack. Use the -p option to provide one.\n" print];
	exit(1);
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver pathForExtractingEntryWithDictionary:(NSDictionary *)dict
{
	return nil;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	return YES;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	[self printIndention];

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
//	NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];
	NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];

	NSString *name=[[[dict objectForKey:XADFileNameKey] string] stringByEscapingControlCharacters];
	[name print];
	[@" (" print];

	if(dir&&[dir boolValue])
	{
		[@"dir" print];
	}
	else if(link&&[link boolValue]) [@"link" print];
	else
	{
		if(size) [[NSString stringWithFormat:@"%lld",[size longLongValue]] print];
		else [@"?" print];
	}

	if(rsrc&&[rsrc boolValue]) [@", rsrc" print];

	[@")... " print];
	fflush(stdout);
}

-(void)unarchiver:(XADUnarchiver *)unarchiver finishedExtractingEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path error:(XADError)error
{
	if(!error) [@"OK.\n" print];
	else
	{
		[@"Failed! (" print];
		[[XADException describeXADError:error] print];
		[@")\n" print];
	}
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldCreateDirectory:(NSString *)directory
{
	return YES;
}

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldExtractArchiveEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	return recurse;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver willExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path
{
	indent++;
	[@"\n" print];
}

-(void)unarchiver:(XADUnarchiver *)unarchiver didExtractArchiveEntryWithDictionary:(NSDictionary *)dict withUnarchiver:(XADUnarchiver *)subunarchiver to:(NSString *)path error:(XADError)error
{
	indent--;
	[self printIndention];
}

-(NSString *)unarchiver:(XADUnarchiver *)unarchiver linkDestinationForEntryWithDictionary:(NSDictionary *)dict from:(NSString *)path
{
	return nil;
}

-(BOOL)extractionShouldStopForUnarchiver:(XADUnarchiver *)unarchiver
{
	return NO;
}

-(void)unarchiver:(XADUnarchiver *)unarchiver extractionProgressForEntryWithDictionary:(NSDictionary *)dict
fileFraction:(double)fileprogress estimatedTotalFraction:(double)totalprogress
{
}

@end




int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	CSCommandLineParser *cmdline=[[CSCommandLineParser new] autorelease];

	[cmdline setUsageHeader:
	@"unar " VERSION_STRING @" (" @__DATE__ @"), a tool for extracting the contents of archive files.\n"
	@"Usage: unar [options] archive... [destination]\n"
	@"\n"
	@"Available options:\n"];

	[cmdline addStringOption:@"password" description:
	@"The password to use for decrypting protected archives."];
	[cmdline addAlias:@"p" forOption:@"password"];

	[cmdline addStringOption:@"encoding" description:
	@"The encoding to use for filenames in the archive, when it is not known. "
	@"Use \"help\" or \"list\" as the argument to give a listing of all supported encodings."
	argumentDescription:@"encoding name"];
	[cmdline addAlias:@"e" forOption:@"encoding"];

	[cmdline addSwitchOption:@"no-recursion" description:
	@"Do not attempt to extract archives contained in other archives. For instance, "
	@"when unpacking a .tar.gz file, only unpack the .tar file and not its contents."];
	[cmdline addAlias:@"nr" forOption:@"no-recursion"];

/*	[cmdline addSwitchOption:@"no-directory" description:
	@"Do not automatically create a directory for the contents of the unpacked archive."];
	[cmdline addAlias:@"nd" forOption:@"no-directory"];*/

	[cmdline addMultipleChoiceOption:@"forks"
	#ifdef __APPLE__
	allowedValues:[NSArray arrayWithObjects:@"fork",@"visible",@"hidden",@"skip",nil] defaultValue:@"fork"
	description:@"How to handle Mac OS resource forks. "
	@"\"fork\" creates regular resource forks, "
	@"\"visible\" creates AppleDouble files with the extension \".rsrc\", "
	@"\"hidden\" creates AppleDouble files with the prefix \"._\", "
	@"and \"skip\" discards all resource forks."];
	#else
	allowedValues:[NSArray arrayWithObjects:@"visible",@"hidden",@"skip",nil] defaultValue:@"visible"
	description:@"How to handle Mac OS resource forks. "
	@"\"visible\" creates AppleDouble files with the extension \".rsrc\", "
	@"\"hidden\" creates AppleDouble files with the prefix \"._\", "
	@"and \"skip\" discards all resource forks."];
	#endif
 	[cmdline addAlias:@"f" forOption:@"forks"];

	#ifdef __APPLE__
	int forkvalues[]={XADMacOSXForkStyle,XADVisibleAppleDoubleForkStyle,XADHiddenAppleDoubleForkStyle,XADIgnoredForkStyle};
	#else
	int forkvalues[]={XADVisibleAppleDoubleForkStyle,XADHiddenAppleDoubleForkStyle,XADIgnoredForkStyle};
	#endif



	[cmdline addHelpOption];

	if(![cmdline parseCommandLineWithArgc:argc argv:argv]) exit(1);



	recurse=![cmdline boolValueForOption:@"no-recursion"];

	NSString *password=[cmdline stringValueForOption:@"password"];
	NSString *encoding=[cmdline stringValueForOption:@"encoding"];
	int forkstyle=forkvalues[[cmdline intValueForOption:@"forks"]];

	if(encoding&&([encoding caseInsensitiveCompare:@"list"]==NSOrderedSame||[encoding caseInsensitiveCompare:@"help"]==NSOrderedSame))
	{
		[@"Available encodings are:\n" print];
		PrintEncodingList();
		return 0;
	}



//	NSArray *files=[cmdline stringArrayValueForOption:@"files"];
	NSArray *files=[cmdline remainingArguments];
	int numfiles=[files count];

	if(numfiles==0)
	{
		[cmdline printUsage];
		exit(1);
	}

	NSString *destination=nil;
	if(numfiles>1)
	{
		NSString *path=[files lastObject];
		BOOL isdir;
		if(![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isdir]||isdir)
		{
			destination=path;
			numfiles--;
		}
	}



	for(int i=0;i<numfiles;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		NSString *filename=[files objectAtIndex:i];

		[@"Extracting " print];
		[filename print];
		[@"..." print];

		fflush(stdout);

		XADUnarchiver *unarchiver=[XADUnarchiver unarchiverForPath:filename];

		if(unarchiver)
		{
			if(destination) [unarchiver setDestination:destination];
			if(password) [[unarchiver archiveParser] setPassword:password];
			if(encoding) [[[unarchiver archiveParser] stringSource] setFixedEncodingName:encoding];
			[unarchiver setMacResourceForkStyle:forkstyle];

			[unarchiver setDelegate:[[[Unarchiver alloc] init] autorelease]];
			
			[@"\n" print];

			XADError parseerror=[unarchiver parseAndUnarchive];
			if(parseerror)
			{
				[@"Failed! (" print];
				[[XADException describeXADError:parseerror] print];
				[@")\n" print];
			}
		}
		else
		{
			[@" Couldn't open archive.\n" print];
		}

		[pool release];
	}

	[pool release];

	return 0;
}
