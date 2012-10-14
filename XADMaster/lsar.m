#import "XADSimpleUnarchiver.h"
#import "XADArchiveParserDescriptions.h"
#import "NSStringPrinting.h"
#import "CSCommandLineParser.h"
#import "CSJSONPrinter.h"
#import "CommandLineCommon.h"

#define VERSION_STRING @"v1.3"

#define EntryDoesNotNeedTestingResult 0
#define EntryIsNotSupportedResult 1
#define EntryFailsWhileUnpackingResult 2
#define EntrySizeIsWrongResult 3
#define EntryHasNoChecksumResult 4
#define EntryChecksumIsIncorrectResult 5
#define EntryIsOkResult 6

static int TestEntry(XADSimpleUnarchiver *unarchiver,NSDictionary *dict);


@interface Lister:NSObject {}
@end

@interface JSONLister:NSObject {}
@end

int returncode;
CSJSONPrinter *printer;
BOOL longformat,verylongformat,test;
int passed,failed,unknown;

int main(int argc,const char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	CSCommandLineParser *cmdline=[[CSCommandLineParser new] autorelease];

	[cmdline setUsageHeader:
	@"lsar " VERSION_STRING @" (" @__DATE__ @"), a tool for listing the contents of archive files.\n"
	@"Usage: lsar [options] archive [files ...]\n"
	@"\n"
	@"Available options:\n"];

	[cmdline addSwitchOption:@"long" description:
	@"Print more information about each file in the archive."];
	[cmdline addAlias:@"l" forOption:@"long"];

	[cmdline addSwitchOption:@"verylong" description:
	@"Print all available information about each file in the archive."];
	[cmdline addAlias:@"L" forOption:@"verylong"];

	[cmdline addSwitchOption:@"test" description:
	@"Test the integrity of the files in the archive, if possible."];
	[cmdline addAlias:@"t" forOption:@"test"];

	[cmdline addStringOption:@"password" description:
	@"The password to use for decrypting protected archives."];
	[cmdline addAlias:@"p" forOption:@"password"];

	[cmdline addStringOption:@"encoding" description:
	@"The encoding to use for filenames in the archive, when it is not known. "
	@"If not specified, the program attempts to auto-detect the encoding used. "
	@"Use \"help\" or \"list\" as the argument to give a listing of all supported encodings."
	argumentDescription:@"encoding name"];
	[cmdline addAlias:@"e" forOption:@"encoding"];

	[cmdline addStringOption:@"password-encoding" description:
	@"The encoding to use for the password for the archive, when it is not known. "
	@"If not specified, then either the encoding given by the -encoding option "
	@"or the auto-detected encoding is used."
	argumentDescription:@"name"];
	[cmdline addAlias:@"E" forOption:@"password-encoding"];

	[cmdline addSwitchOption:@"print-encoding" description:
	@"Print the auto-detected encoding and the confidence factor after the file list"];
	[cmdline addAlias:@"pe" forOption:@"print-encoding"];

	[cmdline addSwitchOption:@"indexes" description:
	@"Instead of specifying the files to list as filenames or wildcard patterns, "
	@"specify them as indexes."];
	[cmdline addAlias:@"i" forOption:@"indexes"];

	[cmdline addSwitchOption:@"json" description:
	@"Print the listing in JSON format."];
	[cmdline addAlias:@"j" forOption:@"json"];

	[cmdline addSwitchOption:@"json-ascii" description:
	@"Print the listing in JSON format, encoded as pure ASCII text."];
	[cmdline addAlias:@"ja" forOption:@"json-ascii"];

	[cmdline addSwitchOption:@"no-recursion" description:
	@"Do not attempt to list archives contained in other archives. For instance, "
	@"when unpacking a .tar.gz file, only list the .gz file and not its contents."];
	[cmdline addAlias:@"nr" forOption:@"no-recursion"];

	[cmdline addHelpOption];

	if(![cmdline parseCommandLineWithArgc:argc argv:argv]) return 1;




	longformat=[cmdline boolValueForOption:@"long"];
	verylongformat=[cmdline boolValueForOption:@"verylong"];
	test=[cmdline boolValueForOption:@"test"];
	NSString *password=[cmdline stringValueForOption:@"password"];
	NSString *encoding=[cmdline stringValueForOption:@"encoding"];
	NSString *passwordencoding=[cmdline stringValueForOption:@"password-encoding"];
	BOOL printencoding=[cmdline boolValueForOption:@"print-encoding"];
	BOOL indexes=[cmdline boolValueForOption:@"indexes"];
	BOOL json=[cmdline boolValueForOption:@"json"];
	BOOL jsonascii=[cmdline boolValueForOption:@"json-ascii"];
	BOOL norecursion=[cmdline boolValueForOption:@"no-recursion"];

	// -json-ascii implies -json.
	if(jsonascii) json=YES;

	// -verylong and -long are exclusive.
	if(verylongformat) longformat=NO;

	if(IsListRequest(encoding)||IsListRequest(passwordencoding))
	{
		[@"Available encodings are:\n" print];
		PrintEncodingList();
		return 0;
	}

	NSArray *files=[cmdline remainingArguments];
	int numfiles=[files count];
	if(numfiles==0)
	{
		[cmdline printUsage];
		return 1;
	}

	NSString *filename=[files objectAtIndex:0];

	if(json)
	{
		printer=[CSJSONPrinter new];
		[printer setIndentString:@"  "];
		[printer setASCIIMode:jsonascii];

		[printer startPrintingDictionary];
		[printer printDictionaryKey:@"lsarFormatVersion"];
		[printer printDictionaryObject:[NSNumber numberWithInt:2]];

		XADError openerror;
		XADSimpleUnarchiver *unarchiver=[XADSimpleUnarchiver simpleUnarchiverForPath:filename error:&openerror];
		if(!unarchiver)
		{
			[printer printDictionaryKey:@"lsarError"];
			[printer printDictionaryObject:[NSNumber numberWithInt:openerror]];
			[printer endPrintingDictionary];
			[@"\n" print];
			return 1;
		}

		if(password) [unarchiver setPassword:password];
		if(encoding) [[unarchiver archiveParser] setEncodingName:encoding];
		if(passwordencoding) [[unarchiver archiveParser] setPasswordEncodingName:passwordencoding];
		[unarchiver setExtractsSubArchives:!norecursion];
		[unarchiver setAlwaysOverwritesFiles:YES]; // Disable collision checks.

		for(int i=1;i<numfiles;i++)
		{
			NSString *filter=[files objectAtIndex:i];
			if(indexes) [unarchiver addIndexFilter:[filter intValue]];
			else [unarchiver addGlobFilter:filter];
		}

		[unarchiver setDelegate:[[JSONLister new] autorelease]];

		[printer printDictionaryKey:@"lsarContents"];
		[printer startPrintingDictionaryObject];
		[printer startPrintingArray];

		returncode=0;

		XADError parseerror=[unarchiver parse];
		XADError unarchiveerror=[unarchiver unarchive];

		[printer endPrintingArray];
		[printer endPrintingDictionaryObject];

		if(parseerror||unarchiveerror)
		{
			[printer printDictionaryKey:@"lsarError"];
			if(parseerror) [printer printDictionaryObject:[NSNumber numberWithInt:parseerror]];
			else [printer printDictionaryObject:[NSNumber numberWithInt:unarchiveerror]];
			returncode=1;
		}

		if(test)
		{
			XADArchiveParser *subparser=[unarchiver innerArchiveParser];
			if(subparser)
			{
				[printer printDictionaryKey:@"lsarTestResult"];

				CSHandle *handle=[subparser handle];
				if([handle hasChecksum])
				{
					@try
					{
						[handle seekToEndOfFile];
						if([handle isChecksumCorrect]) [printer printDictionaryObject:@"ok"];
						else { [printer printDictionaryObject:@"wrong_checksum"]; returncode=1; }
					}
					@catch(id e) { [printer printDictionaryObject:@"unpacking_failed"]; returncode=1; }
				}
				else [printer printDictionaryObject:@"no_checksum"];
			}
		}

		XADArchiveParser *parser=[unarchiver archiveParser];
		[printer printDictionaryKey:@"lsarEncoding"];
		[printer printDictionaryObject:[parser encodingName]];
		[printer printDictionaryKey:@"lsarConfidence"];
		[printer printDictionaryObject:[NSNumber numberWithFloat:[parser encodingConfidence]]];

		XADArchiveParser *outerparser=[unarchiver outerArchiveParser];
		[printer printDictionaryKey:@"lsarFormatName"];
		[printer printObject:[outerparser formatName]];
		[printer printDictionaryKey:@"lsarProperties"];
		[printer startPrintingDictionary];
		[printer printDictionaryKeysAndObjects:[outerparser properties]];
		[printer endPrintingDictionary];

		XADArchiveParser *innerparser=[unarchiver innerArchiveParser];
		if(innerparser)
		{
			[printer printDictionaryKey:@"lsarInnerFormatName"];
			[printer printObject:[innerparser formatName]];
			[printer printDictionaryKey:@"lsarInnerProperties"];
			[printer startPrintingDictionary];
			[printer printDictionaryKeysAndObjects:[innerparser properties]];
			[printer endPrintingDictionary];
		}

		[printer endPrintingDictionary];

		[@"\n" print];
	}
	else
	{
		[filename print];
		[@": " print];
		fflush(stdout);

		XADError openerror;
		XADSimpleUnarchiver *unarchiver=[XADSimpleUnarchiver simpleUnarchiverForPath:filename error:&openerror];
		if(!unarchiver)
		{
			if(openerror)
			{
				[@"Couldn't open archive. (" print];
				[[XADException describeXADError:openerror] print];
				[@".)\n" print];
			}
			else
			{
				[@"Couldn't recognize the archive format.\n" print];
			}
			return 1;
		}

		if(password) [unarchiver setPassword:password];
		if(encoding) [[unarchiver archiveParser] setEncodingName:encoding];
		if(passwordencoding) [[unarchiver archiveParser] setPasswordEncodingName:passwordencoding];
		[unarchiver setExtractsSubArchives:!norecursion];
		[unarchiver setAlwaysOverwritesFiles:YES]; // Disable collision checks.

		for(int i=1;i<numfiles;i++)
		{
			NSString *filter=[files objectAtIndex:i];
			if(indexes) [unarchiver addIndexFilter:[filter intValue]];
			else [unarchiver addGlobFilter:filter];
		}

		[unarchiver setDelegate:[[[Lister alloc] init] autorelease]];

		XADError parseerror=[unarchiver parse];

		if([unarchiver innerArchiveParser])
		{
			[[[unarchiver innerArchiveParser] formatName] print];
			[@" in " print];
			[[[unarchiver outerArchiveParser] formatName] print];
		}
		else
		{
			[[[unarchiver outerArchiveParser] formatName] print];
		}

		NSArray *volumes=[[unarchiver outerArchiveParser] volumes];
		if([volumes count]>1) [[NSString stringWithFormat:@" (%d volumes)",[volumes count]] print];

		[@"\n" print];

		if(longformat)
		{
			[@"     Flags  File size   Ratio  Mode  Date       Time   Name\n" print];
			[@"     =====  ==========  =====  ====  ========== =====  ====\n" print];
		}

		returncode=0;
		passed=failed=unknown=0;

		XADError unarchiveerror=[unarchiver unarchive];

		if(parseerror)
		{
			[@"Archive parsing failed! (" print];
			[[XADException describeXADError:parseerror] print];
			[@".)\n" print];
			returncode=1;
		}

		if(unarchiveerror)
		{
			[@"Listing failed! (" print];
			[[XADException describeXADError:unarchiveerror] print];
			[@".)\n" print];
			returncode=1;
		}

		if(longformat)
		{
			[@"(Flags: D=Directory, R=Resource fork, L=Link, E=Encrypted, @=Extended attributes)\n" print];
			NSString *compkey=CompressionNameExplanationForLongInfo();
			if(compkey)
			{
				[@"(Mode: " print];
				[compkey print];
				[@")\n" print];
			}
		}

		if(longformat||verylongformat)
		{
			XADString *comment=[[[unarchiver archiveParser] properties] objectForKey:XADCommentKey];
			if(comment)
			{
				[@"Archive comment:\n" print];
				[[comment string] print];
				[@"\n" print];
			}
		}

		if(test)
		{
			if(unknown)
			{
				[[NSString stringWithFormat:@"%d passed, %d failed, %d unknown.",
				passed,failed,unknown] print];
			}
			else
			{
				[[NSString stringWithFormat:@"%d passed, %d failed.",
				passed,failed] print];
			}

			XADArchiveParser *subparser=[unarchiver innerArchiveParser];
			if(subparser)
			{
				CSHandle *handle=[subparser handle];
				if([handle hasChecksum])
				{
					@try
					{
						[handle seekToEndOfFile];
						if([handle isChecksumCorrect]) [@" Container file checksum is correct." print];
						else { [@" Container file checksum failed!" print]; returncode=1; }
					}
					@catch(id e) { [@" Container file failed while testing checksum!" print]; returncode=1; }
				}
				else [@" Container file has no checksum." print];
			}

			[@"\n" print];
		}

		if(printencoding)
		{
			XADArchiveParser *parser=[unarchiver archiveParser];
			[[NSString stringWithFormat:@"Encoding: %@ (%d%% confidence)\n",
			[parser encodingName],(int)([parser encodingConfidence]*100+0.5)] print];
		}
	}

	[pool release];

	return returncode;
}



@implementation Lister

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver
{
	// Ask for a password from the user if called in interactive mode,
	// otherwise just print an error on stderr and exit.
 	if(IsInteractive())
	{
		NSString *password=AskForPassword(@"This archive requires a password to list.\n");
		if(!password) exit(2);
		[unarchiver setPassword:password];
	}
	else
	{
		[@"This archive requires a password to unpack. Use the -p option to provide one.\n" printToFile:stderr];
		exit(2);
	}
}

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	if(longformat)
	{
		NSString *infoline=LongInfoLineForEntryWithDictionary(dict,[unarchiver archiveParser]);
		[infoline print];
	}
	else // Short or very long format.
	{
		NSString *infoline=ShortInfoLineForEntryWithDictionary(dict);
		[infoline print];
	}

	if(test)
	{
		[@"... " print];
		fflush(stdout);

		switch(TestEntry(unarchiver,dict))
		{
			case EntryDoesNotNeedTestingResult: passed++; break;
			case EntryIsNotSupportedResult: [@"Unsupported!" print]; failed++; break;
			case EntryFailsWhileUnpackingResult: [@"Unpacking failed!" print]; failed++; break;
			case EntrySizeIsWrongResult: [@"Wrong size!" print]; failed++; break;
			case EntryHasNoChecksumResult: [@"Unknown." print]; unknown++; break;
			case EntryChecksumIsIncorrectResult: [@"Checksum failed!" print]; failed++; break;
			case EntryIsOkResult: [@"OK." print]; passed++; break;
		}
	}
	else if(verylongformat)
	{
		[@": " print];
	}

	[@"\n" print];

	if(verylongformat)
	{
		[@"  " print];
		NSString *description=XADHumanReadableEntryWithDictionary(dict,[unarchiver archiveParser]);
		[XADIndentTextWithSpaces(description,2) print];
		[@"\n" print];
	}
	if(longformat)
	{
		XADString *comment=[dict objectForKey:XADCommentKey];
		if(comment)
		{
			[@"     File comment: " print];
			[[comment string] print];
			[@"\n" print];
		}
	}

	[pool release];

	return NO;
}

@end

@implementation JSONLister

-(void)simpleUnarchiverNeedsPassword:(XADSimpleUnarchiver *)unarchiver
{
	// Just print an error to stderr and return 2 to indicate a password is needed.
	// TODO: This breaks the JSON output, should this be fixed?
	[@"This archive requires a password to unpack. Use the -p option to provide one.\n" printToFile:stderr];
	exit(2);
}

-(BOOL)simpleUnarchiver:(XADSimpleUnarchiver *)unarchiver shouldExtractEntryWithDictionary:(NSDictionary *)dict to:(NSString *)path
{
	[printer startPrintingArrayObject];
	[printer startPrintingDictionary];

	[printer printDictionaryKeysAndObjects:dict];

	if(test)
	{
		[printer printDictionaryKey:@"lsarTestResult"];
		switch(TestEntry(unarchiver,dict))
		{
			case EntryDoesNotNeedTestingResult: [printer printDictionaryObject:@"not_tested"]; break;
			case EntryIsNotSupportedResult: [printer printDictionaryObject:@"not_supported"]; break;
			case EntryFailsWhileUnpackingResult: [printer printDictionaryObject:@"unpacking_failed"]; break;
			case EntrySizeIsWrongResult: [printer printDictionaryObject:@"wrong_size"]; break;
			case EntryHasNoChecksumResult: [printer printDictionaryObject:@"no_checksum"]; break;
			case EntryChecksumIsIncorrectResult: [printer printDictionaryObject:@"wrong_checksum"]; break;
			case EntryIsOkResult: [printer printDictionaryObject:@"ok"]; break;
		}
	}

	[printer endPrintingDictionary];
	[printer endPrintingArrayObject];

	return NO;
}

@end

static int TestEntry(XADSimpleUnarchiver *unarchiver,NSDictionary *dict)
{
	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
	NSNumber *size=[dict objectForKey:XADFileSizeKey];

	BOOL isdir=dir&&[dir boolValue];
	BOOL islink=link&&[link boolValue];

	if(isdir||islink) return EntryDoesNotNeedTestingResult;

	XADArchiveParser *parser=[unarchiver archiveParser];
	CSHandle *handle=[parser handleForEntryWithDictionary:dict wantChecksum:YES error:NULL];

	if(!handle)
	{
		returncode=1;
		return EntryIsNotSupportedResult;
	}

	@try
	{
		[handle seekToEndOfFile];
	}
	@catch(id exception)
	{
		returncode=1;
		return EntryFailsWhileUnpackingResult;
	}

	if(![handle hasChecksum])
	{
		if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			returncode=1;
			return EntrySizeIsWrongResult;
		}
		else
		{
			return EntryHasNoChecksumResult;
		}
	}
	else
	{
		if(![handle isChecksumCorrect])
		{
			returncode=1;
			return EntryChecksumIsIncorrectResult;
		}
		else if(size&&[size longLongValue]!=[handle offsetInFile])
		{
			returncode=1;
			return EntrySizeIsWrongResult; // Unlikely to happen
		}
		else
		{
			return EntryIsOkResult;
		}
	}
}

