#import "XADXARParser.h"
#import "CSZlibHandle.h"
#import "CSBzip2Handle.h"
#import "XADLZMAHandle.h"
#import "XADDigestHandle.h"
#import "XADLZMAParser.h"
#import "XADRegex.h"

#define GroundState 0
#define XarState 1
#define TocState 2
#define FileState 3
#define DataState 4
#define ExtendedAttributeState 5
#define ResourceForkState 6
#define FinderInfoState 7

static const NSString *StringFormat=@"String";
static const NSString *XADStringFormat=@"XADString";
static const NSString *DecimalFormat=@"Decimal";
static const NSString *OctalFormat=@"Octal";
static const NSString *HexFormat=@"Hex";
static const NSString *DateFormat=@"Date";

@implementation XADXARParser

+(int)requiredHeaderSize { return 4; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	return length>=4&&bytes[0]=='x'&&bytes[1]=='a'&&bytes[2]=='r'&&bytes[3]=='!';
}

-(void)parse
{
	CSHandle *fh=[self handle];

	[fh skipBytes:4];
	int headsize=[fh readUInt16BE];
	[fh skipBytes:2];
	uint64_t tablecompsize=[fh readUInt64BE];
	uint64_t tableuncompsize=[fh readUInt64BE];

	heapoffset=headsize+tablecompsize;

	filedefinitions=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObjects:@"Name",StringFormat,nil],@"name",
		[NSArray arrayWithObjects:@"Type",StringFormat,nil],@"type",
		[NSArray arrayWithObjects:@"Link",StringFormat,nil],@"link",
		[NSArray arrayWithObjects:XADLastModificationDateKey,DateFormat,nil],@"mtime",
		[NSArray arrayWithObjects:XADLastAccessDateKey,DateFormat,nil],@"atime",
		[NSArray arrayWithObjects:XADCreationDateKey,DateFormat,nil],@"ctime",
		[NSArray arrayWithObjects:XADPosixPermissionsKey,OctalFormat,nil],@"mode",
		[NSArray arrayWithObjects:XADPosixUserKey,DecimalFormat,nil],@"uid",
		[NSArray arrayWithObjects:XADPosixGroupKey,DecimalFormat,nil],@"gid",
		[NSArray arrayWithObjects:XADPosixUserNameKey,XADStringFormat,nil],@"user",
		[NSArray arrayWithObjects:XADPosixGroupNameKey,XADStringFormat,nil],@"group",
	nil];

	datadefinitions=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObjects:XADFileSizeKey,DecimalFormat,nil],@"size",
		[NSArray arrayWithObjects:XADDataOffsetKey,DecimalFormat,nil],@"offset",
		[NSArray arrayWithObjects:XADDataLengthKey,DecimalFormat,nil],@"length",
		[NSArray arrayWithObjects:@"XARChecksum",HexFormat,nil],@"extracted-checksum",
		[NSArray arrayWithObjects:@"XARChecksumStyle",StringFormat,nil],@"extracted-checksum style",
		[NSArray arrayWithObjects:@"XAREncodingStyle",StringFormat,nil],@"encoding style",
	nil];

	resforkdefinitions=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObjects:XADFileSizeKey,DecimalFormat,nil],@"size",
		[NSArray arrayWithObjects:XADDataOffsetKey,DecimalFormat,nil],@"offset",
		[NSArray arrayWithObjects:XADDataLengthKey,DecimalFormat,nil],@"length",
		[NSArray arrayWithObjects:@"XARChecksum",HexFormat,nil],@"extracted-checksum",
		[NSArray arrayWithObjects:@"XARChecksumStyle",StringFormat,nil],@"extracted-checksum style",
		[NSArray arrayWithObjects:@"XAREncodingStyle",StringFormat,nil],@"encoding style",
	nil];

	finderdefinitions=[NSDictionary dictionaryWithObjectsAndKeys:
		[NSArray arrayWithObjects:@"Size",DecimalFormat,nil],@"size",
		[NSArray arrayWithObjects:@"Offset",DecimalFormat,nil],@"offset",
		[NSArray arrayWithObjects:@"Length",DecimalFormat,nil],@"length",
		[NSArray arrayWithObjects:@"Checksum",HexFormat,nil],@"extracted-checksum",
		[NSArray arrayWithObjects:@"ChecksumStyle",StringFormat,nil],@"extracted-checksum style",
		[NSArray arrayWithObjects:@"EncodingStyle",StringFormat,nil],@"encoding style",
	nil];

	files=[NSMutableArray array];
	filestack=[NSMutableArray array];

	state=GroundState;

	CSZlibHandle *zh=[CSZlibHandle zlibHandleWithHandle:[fh nonCopiedSubHandleFrom:headsize length:tablecompsize]];
	NSData *data=[zh readDataOfLength:tableuncompsize];

	//NSLog(@"%@",[[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease]);

	NSXMLParser *xml=[[[NSXMLParser alloc] initWithData:data] autorelease];
	[xml setDelegate:self];
	[xml parse];

	NSEnumerator *enumerator=[files objectEnumerator];
	NSMutableDictionary *file;
	while(file=[enumerator nextObject])
	{
		if(![self shouldKeepParsing]) break;
		[self finishFile:file parentPath:[self XADPath]];
	}
}

-(void)finishFile:(NSMutableDictionary *)file parentPath:(XADPath *)parentpath
{
	NSString *name=[file objectForKey:@"Name"];
	NSString *type=[file objectForKey:@"Type"];
	NSString *link=[file objectForKey:@"Link"];
	NSArray *filearray=[file objectForKey:@"Files"];
	NSDictionary *resfork=[file objectForKey:@"ResourceFork"];
	NSDictionary *finderinfo=[file objectForKey:@"FinderInfo"];

	static NSArray *tempnames=nil;
	if(!tempnames) tempnames=[[NSArray alloc] initWithObjects:
	@"Name",@"Type",@"Link",@"Files",@"ResourceFork",@"FinderInfo",nil];
	[file removeObjectsForKeys:tempnames];

	XADPath *path=[parentpath pathByAppendingPathComponent:[self XADStringWithString:name]];
	[file setObject:path forKey:XADFileNameKey];

	if([type isEqual:@"directory"]||filearray) [file setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
	else if([type isEqual:@"symlink"])
	{
		if(!link) return;
		[file setObject:[self XADStringWithString:link] forKey:XADLinkDestinationKey];
	}

	if(finderinfo)
	{
		CSHandle *handle=[self handleForEncodingStyle:[finderinfo objectForKey:@"EncodingStyle"]
		offset:[finderinfo objectForKey:@"Offset"] length:[finderinfo objectForKey:@"Length"]
		size:[finderinfo objectForKey:@"Size"] checksum:[finderinfo objectForKey:@"Checksum"]
		checksumStyle:[finderinfo objectForKey:@"ChecksumStyle"]];

		NSData *data=[handle remainingFileContents];
		if(data&&(![handle hasChecksum]||[handle isChecksumCorrect]))
		[file setObject:data forKey:XADFinderInfoKey];
	}

	NSNumber *datalen=[file objectForKey:XADDataLengthKey];
	if(datalen) [file setObject:datalen forKey:XADCompressedSizeKey];
	else [file setObject:[NSNumber numberWithInt:0] forKey:XADCompressedSizeKey];

	if(![file objectForKey:XADFileSizeKey]) [file setObject:[NSNumber numberWithInt:0] forKey:XADFileSizeKey];

	[self addEntryWithDictionary:file];

	if(resfork)
	{
		NSMutableDictionary *resfile=[NSMutableDictionary dictionaryWithDictionary:file];
		[resfile addEntriesFromDictionary:resfork];
		[resfile setObject:[NSNumber numberWithBool:YES] forKey:XADIsResourceForkKey];

		NSNumber *datalen=[resfile objectForKey:XADDataLengthKey];
		if(datalen) [resfile setObject:datalen forKey:XADCompressedSizeKey];

		[self addEntryWithDictionary:resfile];
	}

	if(filearray)
	{
		NSEnumerator *enumerator=[filearray objectEnumerator];
		NSMutableDictionary *file;
		while(file=[enumerator nextObject]) [self finishFile:file parentPath:path];
	}
}

-(void)parser:(NSXMLParser *)parser didStartElement:(NSString *)name
namespaceURI:(NSString *)namespace qualifiedName:(NSString *)qname
attributes:(NSDictionary *)attributes
{
	switch(state)
	{
		case GroundState:
			if([name isEqual:@"xar"]) state=XarState;
		break;

		case XarState:
			if([name isEqual:@"toc"]) state=TocState;
		break;

		case TocState:
			if([name isEqual:@"file"])
			{
				currfile=[NSMutableDictionary dictionary];
				state=FileState;
			}
		break;

		case FileState:
			if([name isEqual:@"file"])
			{
				[filestack addObject:currfile];
				currfile=[NSMutableDictionary dictionary];
				state=FileState;
			}
			else if([name isEqual:@"data"]) state=DataState;
			else if([name isEqual:@"ea"]) state=ExtendedAttributeState;
			else [self startSimpleElement:name attributes:attributes
			definitions:filedefinitions destinationDictionary:currfile];
		break;

		case DataState:
			if([name isEqual:@"encoding"])
			{
				NSString *style=[attributes objectForKey:@"style"];
				if(style) [currfile setObject:style forKey:@"XAREncodingStyle"];
			}
			else [self startSimpleElement:name attributes:attributes
			definitions:datadefinitions destinationDictionary:currfile];
		break;

		case ExtendedAttributeState:
			if([name isEqual:@"com.apple.ResourceFork"])
			{
				currext=[NSMutableDictionary dictionary];
				state=ResourceForkState;
			}
			else if([name isEqual:@"com.apple.FinderInfo"])
			{
				currext=[NSMutableDictionary dictionary];
				state=FinderInfoState;
			}
		break;

		case ResourceForkState:
			[self startSimpleElement:name attributes:attributes
			definitions:resforkdefinitions destinationDictionary:currext];
		break;

		case FinderInfoState:
			[self startSimpleElement:name attributes:attributes
			definitions:finderdefinitions destinationDictionary:currext];
		break;
	}
}

-(void)parser:(NSXMLParser *)parser didEndElement:(NSString *)name
namespaceURI:(NSString *)namespace qualifiedName:(NSString *)qname
{
	switch(state)
	{
		case TocState:
			if([name isEqual:@"toc"]) [parser abortParsing];
		break;

		case FileState:
			if([name isEqual:@"file"])
			{
				if([filestack count])
				{
					NSMutableDictionary *parent=[filestack lastObject];
					[filestack removeLastObject];

					NSMutableArray *filearray=[parent objectForKey:@"Files"];
					if(filearray) [filearray addObject:currfile];
					else [parent setObject:[NSMutableArray arrayWithObject:currfile] forKey:@"Files"];

					currfile=parent;
				}
				else
				{
					[files addObject:currfile];
					currfile=nil;
					state=TocState;
				}
			}
			else [self endSimpleElement:name definitions:filedefinitions
			destinationDictionary:currfile];
		break;

		case DataState:
			if([name isEqual:@"data"]) state=FileState;
			else [self endSimpleElement:name definitions:datadefinitions
			destinationDictionary:currfile];
		break;

		case ExtendedAttributeState:
			if([name isEqual:@"ea"]) state=FileState;
		break;

		case ResourceForkState:
			if([name isEqual:@"com.apple.ResourceFork"])
			{
				[currfile setObject:currext forKey:@"ResourceFork"];
				state=ExtendedAttributeState;
			}
			else [self endSimpleElement:name definitions:resforkdefinitions
			destinationDictionary:currext];
		break;

		case FinderInfoState:
			if([name isEqual:@"com.apple.FinderInfo"])
			{
				[currfile setObject:currext forKey:@"FinderInfo"];
				state=ExtendedAttributeState;
			}
			else [self endSimpleElement:name definitions:finderdefinitions
			destinationDictionary:currext];
		break;
	}
}

-(void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string
{
	[currstring appendString:string];
}

-(void)startSimpleElement:(NSString *)name attributes:(NSDictionary *)attributes
definitions:(NSDictionary *)definitions destinationDictionary:(NSMutableDictionary *)dest
{
	NSEnumerator *enumerator=[attributes keyEnumerator];
	NSString *key;
	while(key=[enumerator nextObject])
	{
		NSArray *definition=[definitions objectForKey:[NSString stringWithFormat:@"%@ %@",name,key]];
		if(definition) [self parseDefinition:definition string:[attributes objectForKey:key] destinationDictionary:dest];
	}

	NSArray *definition=[definitions objectForKey:name];
	if(definition) currstring=[NSMutableString string];
}

-(void)endSimpleElement:(NSString *)name definitions:(NSDictionary *)definitions
destinationDictionary:(NSMutableDictionary *)dest
{
	if(!currstring) return;

	NSArray *definition=[definitions objectForKey:name];
	[self parseDefinition:definition string:currstring destinationDictionary:dest];

	currstring=nil;
}

-(void)parseDefinition:(NSArray *)definition string:(NSString *)string
destinationDictionary:(NSMutableDictionary *)dest
{
	NSString *key=[definition objectAtIndex:0];
	NSString *format=[definition objectAtIndex:1];

	id obj=nil;
	if(format==StringFormat) obj=string;
	else if(format==XADStringFormat) obj=[self XADStringWithString:string];
	else if(format==DecimalFormat) obj=[NSNumber numberWithLongLong:strtoll([string UTF8String],NULL,10)];
	else if(format==OctalFormat) obj=[NSNumber numberWithLongLong:strtoll([string UTF8String],NULL,8)];
	else if(format==HexFormat)
	{
		NSMutableData *data=[NSMutableData data];
		uint8_t byte;
		int n=0,length=[string length];
		for(int i=0;i<length;i++)
		{
			int c=[string characterAtIndex:i];
			if(isxdigit(c))
			{
				int val;
				if(c>='0'&&c<='9') val=c-'0';
				if(c>='A'&&c<='F') val=c-'A'+10;
				if(c>='a'&&c<='f') val=c-'a'+10;

				if(n&1) { byte|=val; [data appendBytes:&byte length:1]; }
				else byte=val<<4;

				n++;
			}
		}
		obj=data;
	}
	else if(format==DateFormat)
	{
		NSArray *matches=[string substringsCapturedByPattern:@"^([0-9]{4})-([0-9]{2})-([0-9]{2})T([0-9]{2}):([0-9]{2})(:([0-9]{2})(.([0-9]+))?)?(([+-])([0-9]{2}):([0-9]{2})|Z)$"];
		if(matches)
		{
			int year=[[matches objectAtIndex:1] intValue];
			int month=[[matches objectAtIndex:2] length]?[[matches objectAtIndex:2] intValue]:1;
			int day=[[matches objectAtIndex:3] length]?[[matches objectAtIndex:3] intValue]:1;
			int hour=[[matches objectAtIndex:4] length]?[[matches objectAtIndex:4] intValue]:0;
			int minute=[[matches objectAtIndex:5] length]?[[matches objectAtIndex:5] intValue]:0;
			int second=[[matches objectAtIndex:7] length]?[[matches objectAtIndex:7] intValue]:0;

			int timeoffs=0;
			if([[matches objectAtIndex:11] length])
			{
				timeoffs=[[matches objectAtIndex:12] intValue]*60+[[matches objectAtIndex:13] intValue];
				if([[matches objectAtIndex:11] isEqual:@"-"]) timeoffs=-timeoffs;
			}
			NSTimeZone *tz=[NSTimeZone timeZoneForSecondsFromGMT:timeoffs*60];

			obj=[NSCalendarDate dateWithYear:year month:month day:day hour:hour minute:minute second:second timeZone:tz];
		}
	}

	if(obj) [dest setObject:obj forKey:key];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	NSData *checksumdata=nil;
	NSString *checksumstyle=nil;
	if(checksum)
	{
		checksumdata=[dict objectForKey:@"XARChecksum"];
		checksumstyle=[dict objectForKey:@"XARChecksumStyle"];
	}

	return [self handleForEncodingStyle:[dict objectForKey:@"XAREncodingStyle"]
	offset:[dict objectForKey:XADDataOffsetKey] length:[dict objectForKey:XADDataLengthKey]
	size:[dict objectForKey:XADFileSizeKey] checksum:checksumdata checksumStyle:checksumstyle];
}

-(CSHandle *)handleForEncodingStyle:(NSString *)encodingstyle offset:(NSNumber *)offset
length:(NSNumber *)length size:(NSNumber *)size checksum:(NSData *)checksum checksumStyle:(NSString *)checksumstyle
{
	off_t sizeval=[size longLongValue];

	CSHandle *handle;
	if(offset)
	{
		handle=[[self handle] nonCopiedSubHandleFrom:[offset longLongValue]+heapoffset
		length:[length longLongValue]];

		if(!encodingstyle||[encodingstyle length]==0); // no encoding style, copy
		else if([encodingstyle isEqual:@"application/x-gzip"]) handle=[CSZlibHandle zlibHandleWithHandle:handle length:sizeval];
		else if([encodingstyle isEqual:@"application/x-bzip2"]) handle=[CSBzip2Handle bzip2HandleWithHandle:handle length:sizeval];
		else if([encodingstyle isEqual:@"application/x-lzma"])
		{
			int first=[handle readUInt8];
			if(first==0xff)
			{
				[handle seekToFileOffset:0];
				XADLZMAParser *parser=[[[XADLZMAParser alloc] initWithHandle:handle name:nil] autorelease];
				lzmahandle=nil;
				[parser parse];
				if(!lzmahandle) return nil;
				handle=lzmahandle;
			}
			else
			{
				[handle seekToFileOffset:0];
				NSData *props=[handle readDataOfLength:5];
				uint64_t streamsize=[handle readUInt64LE];
				handle=[[[XADLZMAHandle alloc] initWithHandle:handle length:streamsize propertyData:props] autorelease];
			}
		}
		else return nil;
	}
	else handle=[[self handle] nonCopiedSubHandleOfLength:0]; // kludge for data-less entries

	if(checksum&&checksumstyle)
	{
		CSHandle *digesthandle=[XADDigestHandle digestHandleWithHandle:handle length:sizeval
		digestName:checksumstyle correctDigest:checksum];
		if(digesthandle) return digesthandle;
	}

	return handle;
}

-(void)archiveParser:(XADArchiveParser *)parser foundEntryWithDictionary:(NSDictionary *)dict
{
	lzmahandle=[parser handleForEntryWithDictionary:dict wantChecksum:NO];
}



-(NSString *)formatName { return @"XAR"; }

@end

