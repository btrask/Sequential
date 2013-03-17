#import "XADArchiveParser.h"
#import "CSFileHandle.h"
#import "XADRegex.h"



CSHandle *HandleForLocators(NSArray *locators,NSString **nameptr);

@interface EntryFinder:NSObject
{
	int count,entrynum;
	XADRegex *regex;
	NSDictionary *entry;
}
-(id)initWithLocator:(NSString *)string;
@end





@interface XADTest:NSObject {}
+(void)testByte:(uint8_t)byte atOffset:(off_t)offset;
@end
//[NSClassFromString(@"XADTest") testByte:byte atOffset:pos];



const char *cstr1,*cstr2;
CSHandle *correcthandle;
off_t correctoffset;
const uint8_t *correctbytes;
off_t correctlength;



int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[NSAutoreleasePool new];

	if(argc==2)
	{
		cstr1=argv[1];

		NSString *filename=[NSString stringWithUTF8String:cstr1];
		NSArray *locators=[filename componentsSeparatedByString:@":"];
		CSHandle *fh=HandleForLocators(locators,NULL);
		if(!fh)
		{
			fprintf(stderr,"Failed to open %s.\n",cstr1);
			exit(1);
		}

		off_t size=0;
		while(![fh atEndOfFile])
		{
			uint8_t b=[fh readUInt8];
			putc(b,stdout);
			size++;
		}
		fflush(stdout);

		fprintf(stderr,"\nRead %lld bytes from %s.\n",size,cstr1);
	}
	else if(argc==3)
	{
		cstr1=argv[1];
		cstr2=argv[2];

		NSString *filename1=[NSString stringWithUTF8String:cstr1];
		NSArray *locators1=[filename1 componentsSeparatedByString:@":"];
		CSHandle *fh=HandleForLocators(locators1,NULL);
		if(!fh)
		{
			fprintf(stderr,"Failed to open %s.\n",cstr1);
			exit(1);
		}

		NSString *filename2=[NSString stringWithUTF8String:cstr2];
		NSArray *locators2=[filename2 componentsSeparatedByString:@":"];
		if([locators2 count]>1)
		{
			correctbytes=NULL;
			correcthandle=HandleForLocators(locators2,NULL);
			if(!correcthandle)
			{
				fprintf(stderr,"Failed to open %s.\n",cstr2);
				exit(1);
			}
		}
		else
		{
			correcthandle=nil;
			NSData *data=[NSData dataWithContentsOfMappedFile:filename2];
			correctbytes=[data bytes];
			correctlength=[data length];
		}

		if([fh isKindOfClass:[CSSubHandle class]])
		{
			correctoffset=[(CSSubHandle *)fh startOffsetInParent];
		}
		else
		{
			correctoffset=0;
		}

		off_t size=0;
		while(![fh atEndOfFile])
		{
			uint8_t b=[fh readUInt8];
			[XADTest testByte:b atOffset:size];
			size++;
		}

		if(correcthandle && ![correcthandle atEndOfFile])
		{
			fprintf(stderr,"%s ended before %s, after %lld bytes.\n",cstr1,cstr2,size);
			exit(1);
		}

		fprintf(stderr,"Read %lld bytes from %s and %s, which are identical.\n",
		size,cstr1,cstr2);
	}
	else
	{
		printf("Usage: %s file[:archiveentry[:...]] [comparefile[:archiveentry[:...]]]\n",argv[0]);
		exit(1);
	}

	[pool release];
	
	return 0;
}




@implementation XADTest

+(void)testByte:(uint8_t)byte atOffset:(off_t)offset
{
	offset-=correctoffset;
	if(offset<0) [NSException raise:NSInvalidArgumentException format:@"Offset before start of solid segment"];

	if(correctbytes)
	{
		if(offset>=correctlength)
		{
			fprintf(stderr,"%s ended before %s, after %lld bytes.\n",cstr2,cstr1,offset);
			exit(1);
		}

		uint8_t correctbyte=correctbytes[offset];
		if(byte!=correctbyte)
		{
			fprintf(stderr,"Mismatch between %s and %s, starting at byte "
			"%lld (%02x vs. %02x).\n",cstr1,cstr2,offset,byte,correctbyte);
			exit(1);
		}
	}
	else
	{
		[correcthandle seekToFileOffset:offset];
		if([correcthandle atEndOfFile])
		{
			fprintf(stderr,"%s ended before %s, after %lld bytes.\n",cstr2,cstr1,offset);
			exit(1);
		}

		uint8_t correctbyte=[correcthandle readUInt8];
		if(byte!=correctbyte)
		{
			fprintf(stderr,"Mismatch between %s and %s, starting at byte "
			"%lld (%02x vs. %02x).\n",cstr1,cstr2,offset,byte,correctbyte);
			exit(1);
		}
	}
}

@end




@implementation EntryFinder

CSHandle *HandleForLocators(NSArray *locators,NSString **nameptr)
{
	if([locators count]==1)
	{
		NSString *filename=[locators lastObject];
		if(nameptr) *nameptr=filename;

		return [CSFileHandle fileHandleForReadingAtPath:filename];
	}
	else
	{
		NSString *locator=[locators lastObject];
		NSArray *parentlocators=[locators subarrayWithRange:NSMakeRange(0,[locators count]-1)];

		NSString *parentname;
		CSHandle *parenthandle=HandleForLocators(parentlocators,&parentname);
		if(!parenthandle) return nil;

		XADArchiveParser *parser=[XADArchiveParser archiveParserForHandle:parenthandle name:parentname];

		char *pass=getenv("XADTestPassword");
		if(pass) [parser setPassword:[NSString stringWithUTF8String:pass]];

		EntryFinder *finder=[[[EntryFinder alloc] initWithLocator:locator] autorelease];
		[parser setDelegate:finder];

		[parser parse];

		if(!finder->entry) return nil;

		if(nameptr) *nameptr=[[finder->entry objectForKey:XADFileNameKey] string];
		return [parser handleForEntryWithDictionary:finder->entry wantChecksum:NO];
	}
}

-(id)initWithLocator:(NSString *)locator
{
	if((self=[super init]))
	{
		count=-1;
		entrynum=-1;
		regex=nil;
		entry=nil;

		NSArray *matches=[locator substringsCapturedByPattern:@"^#([0-9]+)$"];
		if(matches)
		{
			entrynum=[[matches objectAtIndex:1] intValue];
		}
		else
		{
			regex=[[XADRegex regexWithPattern:[XADRegex patternForGlob:locator]] retain];
		}
	}
	return self;
}

-(void)dealloc
{
	[regex release];
	[entry release];
	[super dealloc];
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	count++;

	NSNumber *dir=[dict objectForKey:XADIsDirectoryKey];

	if(entrynum>=0 && entrynum==count)
	{
		entry=[dict retain];
		return;
	}

	if(dir&&[dir boolValue]) return;

	if(regex && [regex matchesString:[[dict objectForKey:XADFileNameKey] string]])
	{
		entry=[dict retain];
		return;
	}
}

-(BOOL)archiveParsingShouldStop:(XADArchiveParser *)parser
{
	return entry!=nil;
}

@end

