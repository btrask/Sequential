#import <XADMaster/XADArchiveParser.h>

@interface ArchiveTester:NSObject
{
	int indent;
	int successcount,unknowncount,dircount,linkcount;
}
@end

@implementation ArchiveTester

-(id)initWithIndentLevel:(int)indentlevel
{
	if(self=[super init])
	{
		indent=indentlevel;
		successcount=unknowncount=dircount=linkcount=0;
	}
	return self;
}

-(void)done:(XADArchiveParser *)parser
{
	for(int i=0;i<indent;i++) printf(" ");
	printf("%s (%s): %d successful files, %d unknown files, %d directories, %d links\n",
	[[parser name] UTF8String],[[parser formatName] UTF8String],successcount,unknowncount,dircount,linkcount);
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSNumber *link=[dict objectForKey:XADIsLinkKey];
	CSHandle *fh=nil;

	if(dir&&[dir boolValue]) { dircount++; }
	else if(link&&[link boolValue]) { linkcount++; }
	else
	{
		fh=[parser handleForEntryWithDictionary:dict wantChecksum:YES];

		if(!fh)
		{
			NSLog(@"Could not obtain handle for entry: %@",dict);
			exit(1);
		}
		else if([fh hasChecksum])
		{
			[fh seekToEndOfFile];
			if([fh isChecksumCorrect]) successcount++;
			else
			{
				NSLog(@"Checksum failure for entry: %@",dict);
				exit(1);
			}
		}
		else unknowncount++;
	}

	NSNumber *arch=[dict objectForKey:XADIsArchiveKey];
	if(arch&&[arch boolValue])
	{
		[fh seekToFileOffset:0];

		XADArchiveParser *parser=[XADArchiveParser archiveParserForHandle:fh name:[[dict objectForKey:XADFileNameKey] string]];
		ArchiveTester *tester=[[[ArchiveTester alloc] initWithIndentLevel:indent+2] autorelease];
		[parser setDelegate:tester];
		[parser parse];
		[tester done:parser];
	}

	[pool release];
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return NO;
}

@end

int main(int argc,char **argv)
{
	for(int i=1;i<argc;i++)
	{
		NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

		printf("Testing %s...\n",argv[i]);

		NSString *filename=[NSString stringWithUTF8String:argv[i]];
		XADArchiveParser *parser=[XADArchiveParser archiveParserForPath:filename];
		ArchiveTester *tester=[[[ArchiveTester alloc] initWithIndentLevel:2] autorelease];
		[parser setDelegate:tester];

		char *pass=getenv("XADTestPassword");
		if(pass) [parser setPassword:[NSString stringWithUTF8String:pass]];

		[parser parse];
		[tester done:parser];

		[pool release];
	}
	return 0;
}
