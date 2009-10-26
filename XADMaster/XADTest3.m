#import <XADMaster/XADArchiveParser.h>

NSString *EscapeString(NSString *str)
{
	NSMutableString *res=[NSMutableString string];
	int length=[str length];
	for(int i=0;i<length;i++)
	{
		unichar c=[str characterAtIndex:i];
		if(c<32) [res appendFormat:@"^%c",c+64];
		else [res appendFormat:@"%C",c];
	}
	return res;
}

@interface ArchiveTester:NSObject
{
	int indent;
}
@end

@implementation ArchiveTester

-(id)initWithIndentLevel:(int)indentlevel
{
	if(self=[super init])
	{
		indent=indentlevel;
	}
	return self;
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	for(int i=0;i<indent;i++) printf(" ");

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];
	NSString *link=[[parser linkDestinationForDictionary:dict] string];
	CSHandle *fh;

	if(dir&&[dir boolValue]) printf("- ");
	else if(link) printf("- ");
	else
	{
		fh=[parser handleForEntryWithDictionary:dict wantChecksum:YES];
		[fh seekToEndOfFile];

		if(!fh) printf("! ");
		else if([fh hasChecksum]) printf("%c ",[fh isChecksumCorrect]?'o':'x');
		else printf("? ");
	}

	NSString *name=EscapeString([[dict objectForKey:XADFileNameKey] string]);
	printf("%s (",[name UTF8String]);

	if(dir&&[dir boolValue]) printf("dir");
	else if(link) printf("-> %s",[link UTF8String]);
	else
	{
		NSNumber *compsize=[dict objectForKey:XADCompressedSizeKey];
		if(compsize) printf("%lld",[compsize longLongValue]);
		else printf("?");

		printf("/");

		NSNumber *size=[dict objectForKey:XADFileSizeKey];
		if(size) printf("%lld",[size longLongValue]);
		else printf("?");

		XADString *compname=[dict objectForKey:XADCompressionNameKey];
		if(compname) printf(", %s",[[compname string] UTF8String]);

		NSNumber *rsrc=[dict objectForKey:XADIsResourceForkKey];
		if(rsrc&&[rsrc boolValue]) printf(", rsrc");

		if(!fh) printf(", unsupported");
	}

	printf(")\n");

	NSNumber *arch=[dict objectForKey:XADIsArchiveKey];
	if(arch&&[arch boolValue])
	{
		[fh seekToFileOffset:0];
NSLog(@"what");
		XADArchiveParser *parser=[XADArchiveParser archiveParserForHandle:fh name:name];
NSLog(@"what2 %@",parser);
		[parser setDelegate:[[[ArchiveTester alloc] initWithIndentLevel:indent+2] autorelease]];
		[parser parse];
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

		[parser setDelegate:[[[ArchiveTester alloc] initWithIndentLevel:2] autorelease]];

		char *pass=getenv("XADTestPassword");
		if(pass) [parser setPassword:[NSString stringWithUTF8String:pass]];

		//@try {
			[parser parse];
		//} @catch(id e) {
		//	printf("*** Exception: %s\n",[[e description] UTF8String]);
		//}

		[pool release];
	}
	return 0;
}
