#import "PDFParser.h"

#import "../XADRegex.h"
#import "../CSFileHandle.h"



NSString *PDFWrongMagicException=@"PDFWrongMagicException";
NSString *PDFInvalidFormatException=@"PDFInvalidFormatException";
NSString *PDFParserException=@"PDFParserException";



static int HexDigit(uint8_t c);
static BOOL IsHexDigit(uint8_t c);
static BOOL IsWhitespace(uint8_t c);
static BOOL IsDelimiter(uint8_t c);


@implementation PDFParser

+(PDFParser *)parserWithHandle:(CSHandle *)handle
{
	return [[[PDFParser alloc] initWithHandle:handle] autorelease];
}

+(PDFParser *)parserForPath:(NSString *)path
{
	CSFileHandle *handle=[CSFileHandle fileHandleForReadingAtPath:path];
	return [[[PDFParser alloc] initWithHandle:handle] autorelease];
}

-(id)initWithHandle:(CSHandle *)handle
{
	if(self=[super init])
	{
		mainhandle=[handle retain];
		fh=nil;

		objdict=[[NSMutableDictionary dictionary] retain];
		unresolved=[[NSMutableArray array] retain];

		encryption=nil;

		passwordaction=NULL;
		passwordtarget=nil;

		currchar=0;

		@try
		{
			if([handle readUInt8]!='%'||[handle readUInt8]!='P'||
			[handle readUInt8]!='D'||[handle readUInt8]!='F'||[handle readUInt8]!='-')
			[NSException raise:PDFWrongMagicException format:@"Not a PDF file."];
		}
		@catch(id e) { [self release]; @throw; }
	}
	return self;
}

-(void)dealloc
{
	[mainhandle release];
	[fh release];
	[objdict release];
	[unresolved release];
	[encryption release];
	[super dealloc];
}



-(BOOL)isEncrypted
{
	return encryption?YES:NO;
}

-(BOOL)needsPassword
{
	if(!encryption) return NO;
	return [encryption needsPassword];
}

-(BOOL)setPassword:(NSString *)password
{
	return [encryption setPassword:password];
}

-(void)setPasswordRequestAction:(SEL)action target:(id)target
{
	passwordaction=action;
	passwordtarget=target;
}



-(NSDictionary *)objectDictionary { return objdict; }

-(NSDictionary *)trailerDictionary { return trailerdict; }

-(NSDictionary *)rootDictionary { return [trailerdict objectForKey:@"Root"]; }

-(NSDictionary *)infoDictionary { return [trailerdict objectForKey:@"Info"]; }

-(NSData *)permanentID
{
	NSArray *ids=[trailerdict objectForKey:@"ID"];
	if(!ids) return nil;
	return [[ids objectAtIndex:0] rawData];
}

-(NSData *)currentID
{
	NSArray *ids=[trailerdict objectForKey:@"ID"];
	if(!ids) return nil;
	return [[ids objectAtIndex:1] rawData];
}

-(NSDictionary *)pagesRoot
{
	return [[self rootDictionary] objectForKey:@"Pages"];
}

-(PDFEncryptionHandler *)encryptionHandler { return encryption; }




-(void)startParsingFromHandle:(CSHandle *)handle atOffset:(off_t)offset
{
	[fh autorelease];
	fh=[handle retain];
	[fh seekToFileOffset:offset];

	currchar=0;
	[self proceed];
}

-(off_t)parserFileOffset
{
	return [fh offsetInFile]-1;
}

-(void)proceed
{
	[self proceedWithoutCommentHandling];

	while(currchar=='%')
	{
		while(currchar!='\n' && currchar!='\r') [self proceedWithoutCommentHandling];
		while(currchar=='\n' || currchar=='\r') [self proceedWithoutCommentHandling];
	}
}

-(void)proceedWithoutCommentHandling
{
	if(currchar==-1) [fh _raiseEOF];

	uint8_t byte;
	int actual=[fh readAtMost:1 toBuffer:&byte];
	if(actual!=0) currchar=byte;
	else currchar=-1;
}

-(void)skipWhitespace
{
	while(IsWhitespace(currchar)) [self proceed];
}

-(void)proceedAssumingCharacter:(uint8_t)c errorMessage:(NSString *)error
{
	if(currchar!=c) [self _raiseParserException:error];
	[self proceed];
}

-(void)proceedWithoutCommentHandlingAssumingCharacter:(uint8_t)c errorMessage:(NSString *)error
{
	if(currchar!=c) [self _raiseParserException:error];
	[self proceedWithoutCommentHandling];
}




-(void)parse
{
	[mainhandle seekToEndOfFile];
	[mainhandle skipBytes:-48];
	NSData *enddata=[mainhandle readDataOfLength:48];
	NSString *end=[[[NSString alloc] initWithData:enddata encoding:NSISOLatin1StringEncoding] autorelease];

	NSString *startxref=[[end substringsCapturedByPattern:@"startxref[\n\r ]+([0-9]+)[\n\r ]+%%EOF"] objectAtIndex:1];
	if(!startxref) [NSException raise:PDFInvalidFormatException format:@"Missing PDF trailer."];

	[self startParsingFromHandle:mainhandle atOffset:[startxref longLongValue]];

	// Read newest xrefs and trailer.
	trailerdict=[[self parsePDFXref] retain];

	// Read older xrefs, ignoring their trailers.
	NSNumber *prev=[trailerdict objectForKey:@"Prev"];
	while(prev)
	{
		[self startParsingFromHandle:mainhandle atOffset:[prev longLongValue]];
		NSDictionary *oldtrailer=[self parsePDFXref];
		prev=[oldtrailer objectForKey:@"Prev"];
	}

	[self resolveIndirectObjects];
}

-(NSDictionary *)parsePDFXref
{
	if(currchar=='x') return [self parsePDFXrefTable];
	else return [self parsePDFXrefStream];
}

-(NSDictionary *)parsePDFXrefTable
{
	off_t totalsize=[mainhandle fileSize];

	[self proceedAssumingCharacter:'x' errorMessage:@"Error parsing xref"];
	[self proceedAssumingCharacter:'r' errorMessage:@"Error parsing xref"];
	[self proceedAssumingCharacter:'e' errorMessage:@"Error parsing xref"];
	[self proceedAssumingCharacter:'f' errorMessage:@"Error parsing xref"];

	for(;;)
	{
		[self skipWhitespace];

		if(currchar=='t')
		{
			[self proceedAssumingCharacter:'t' errorMessage:@"Error parsing xref trailer"];
			[self proceedAssumingCharacter:'r' errorMessage:@"Error parsing xref trailer"];
			[self proceedAssumingCharacter:'a' errorMessage:@"Error parsing xref trailer"];
			[self proceedAssumingCharacter:'i' errorMessage:@"Error parsing xref trailer"];
			[self proceedAssumingCharacter:'l' errorMessage:@"Error parsing xref trailer"];
			[self proceedAssumingCharacter:'e' errorMessage:@"Error parsing xref trailer"];
			[self proceedAssumingCharacter:'r' errorMessage:@"Error parsing xref trailer"];

			id trailer=[self parsePDFTypeWithParent:nil];

			if(![trailer isKindOfClass:[NSDictionary class]])
			[self _raiseParserException:@"Error parsing xref trailer"];

			[self setupEncryptionIfNeededForTrailerDictionary:trailer];

			return trailer;
		}
		else if(currchar>='0' && currchar<='9')
		{
			int first=[self parseSimpleInteger];
			int num=[self parseSimpleInteger];

			[self skipWhitespace];

			off_t tableoffset=[self parserFileOffset];

			for(int i=0;i<num;i++)
			{
				NSAutoreleasePool *pool=[NSAutoreleasePool new];

				char entry[21];
				[mainhandle seekToFileOffset:tableoffset+i*20];
				[mainhandle readBytes:20 toBuffer:entry];
				entry[20]=0; // Not strictly necessary?

				if(entry[17]!='n') continue;

				off_t objoffs=atoll(entry);
				int objgen=atol(entry+11);

				if(!objoffs) continue; // Kludge to handle broken Apple PDF files.
				if(objoffs>totalsize) continue; // Kludge to handle some other broken files.

				[self startParsingFromHandle:mainhandle atOffset:objoffs];
				id obj=[self parsePDFObject];

				PDFObjectReference *ref=[PDFObjectReference referenceWithNumber:first+i generation:objgen];
				if(obj && ![objdict objectForKey:ref]) [objdict setObject:obj forKey:ref];

				[pool release];
			}

			[self startParsingFromHandle:mainhandle atOffset:tableoffset+num*20];
		}
		else
		{
			[self _raiseParserException:@"Error parsing xref table"];
		}
	}
	return nil;
}

-(NSDictionary *)parsePDFXrefStream
{
	PDFStream *stream=[self parsePDFObject];
	if(![stream isKindOfClass:[PDFStream class]]) [self _raiseParserException:@"Error parsing xref stream"];

	NSDictionary *dict=[stream dictionary];
	if(![[dict objectForKey:@"Type"] isEqual:@"XRef"]) [self _raiseParserException:@"Error parsing xref stream"];

	NSArray *w=[dict objectForKey:@"W"];
	if(!w) [self _raiseParserException:@"Error parsing xref stream"];
	if(![w isKindOfClass:[NSArray class]]) [self _raiseParserException:@"Error parsing xref stream"];
	if([w count]!=3) [self _raiseParserException:@"Error parsing xref stream"];

	int typesize=[[w objectAtIndex:0] intValue];
	int value1size=[[w objectAtIndex:1] intValue];
	int value2size=[[w objectAtIndex:2] intValue];

	NSArray *index=[dict objectForKey:@"Index"];
	if(index)
	{
		if(![index isKindOfClass:[NSArray class]]) [self _raiseParserException:@"Error parsing xref stream"];
	}
	else
	{
		NSNumber *size=[dict objectForKey:@"Size"];
		if(!size) [self _raiseParserException:@"Error parsing xref stream"];
		if(![size isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error parsing xref stream"];

		index=[NSArray arrayWithObjects:[NSNumber numberWithInt:0],size,nil];
	}

	CSHandle *handle=[stream handleExcludingLast:NO decrypted:NO];
	if(!handle) [self _raiseParserException:@"Error decoding xref stream"];

	NSMutableArray *objstreams=[NSMutableArray array];

	for(int i=0;i<[index count];i+=2)
	{
		NSNumber *firstnum=[index objectAtIndex:i];
		NSNumber *numnum=[index objectAtIndex:i+1];

		if(![firstnum isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error decoding xref stream"];
		if(![numnum isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error decoding xref stream"];

		int first=[firstnum intValue];
		int num=[numnum intValue];

		for(int n=first;n<first+num;n++)
		{
			int type=[self parseIntegerOfSize:typesize fromHandle:handle default:1];
			uint64_t value1=[self parseIntegerOfSize:value1size fromHandle:handle default:0];
			uint64_t value2=[self parseIntegerOfSize:value2size fromHandle:handle default:0];

			if(type!=1) continue;
			if(!value1) continue; // Kludge to handle broken Apple PDF files. TODO: Is this actually needed here?

			NSAutoreleasePool *pool=[NSAutoreleasePool new];

			off_t curroffs=[mainhandle offsetInFile];
			[self startParsingFromHandle:mainhandle atOffset:value1];
			id obj=[self parsePDFObject];
			[mainhandle seekToFileOffset:curroffs];

			PDFObjectReference *ref=[PDFObjectReference referenceWithNumber:n generation:value2];
			if(obj && ![objdict objectForKey:ref]) [objdict setObject:obj forKey:ref];

			if([obj isKindOfClass:[PDFStream class]])
			{
				if([[[obj dictionary] objectForKey:@"Type"] isEqual:@"ObjStm"])
				{
					// This is an object stream, but we can't parse it until encryption has
					// been set up, so cache it for later.
					[objstreams addObject:obj];
				}
			}

			[pool release];
		}
	}

	[self setupEncryptionIfNeededForTrailerDictionary:dict];

	// Parse any object streams that were encountered earlier, now that encryption
	// should be properly set up.
	NSEnumerator *enumerator=[objstreams objectEnumerator];
	PDFStream *objstream;
	while((objstream=[enumerator nextObject]))
	{
		off_t curroffs=[mainhandle offsetInFile];
		[self parsePDFCompressedObjectStream:objstream];
		[mainhandle seekToFileOffset:curroffs];
	}

	return dict;
}


-(void)setupEncryptionIfNeededForTrailerDictionary:(NSDictionary *)trailer
{
	if(encryption) return;

	id encryptdict=[trailer objectForKey:@"Encrypt"];
	if(!encryptdict) return;

	if([encryptdict isKindOfClass:[PDFObjectReference class]])
	{
		encryptdict=[objdict objectForKey:encryptdict];
	}

	NSArray *ids=[trailer objectForKey:@"ID"];
	if(!ids) return;
	NSData *permanentid=[[ids objectAtIndex:0] rawData];

	encryption=[[PDFEncryptionHandler alloc]
	initWithEncryptDictionary:encryptdict permanentID:permanentid];

	if([encryption needsPassword] && passwordaction)
	{
		[passwordtarget performSelector:passwordaction withObject:self];
	}
}



-(id)parsePDFObject
{
	int objnum=[self parseSimpleInteger];
	int objgen=[self parseSimpleInteger];
	PDFObjectReference *ref=[PDFObjectReference referenceWithNumber:objnum generation:objgen];

	[self skipWhitespace];

	[self proceedAssumingCharacter:'o' errorMessage:@"Error parsing object"];
	[self proceedAssumingCharacter:'b' errorMessage:@"Error parsing object"];
	[self proceedAssumingCharacter:'j' errorMessage:@"Error parsing object"];

	id value=[self parsePDFTypeWithParent:ref];

	[self skipWhitespace];

	switch(currchar)
	{
		case 's':
			[self proceedAssumingCharacter:'s' errorMessage:@"Error parsing stream object"];
			[self proceedAssumingCharacter:'t' errorMessage:@"Error parsing stream object"];
			[self proceedAssumingCharacter:'r' errorMessage:@"Error parsing stream object"];
			[self proceedAssumingCharacter:'e' errorMessage:@"Error parsing stream object"];
			[self proceedAssumingCharacter:'a' errorMessage:@"Error parsing stream object"];
			[self proceedAssumingCharacter:'m' errorMessage:@"Error parsing stream object"];

			if(currchar=='\r')
			{
				[self proceedWithoutCommentHandling];
				[self proceedWithoutCommentHandlingAssumingCharacter:'\n' errorMessage:@"Error parsing stream object"];
			}
			else if(currchar=='\n')
			{
				[self proceedWithoutCommentHandling];
			}
			else
			{
				[self _raiseParserException:@"Error parsing stream object"];
			}

			if(![value isKindOfClass:[NSDictionary class]]) [self _raiseParserException:@"Error parsing stream object"];

			return [[[PDFStream alloc] initWithDictionary:value fileHandle:mainhandle
			offset:[self parserFileOffset] reference:ref parser:self] autorelease];
		break;

		case 'e':
			[self proceedAssumingCharacter:'e' errorMessage:@"Error parsing object"];
			[self proceedAssumingCharacter:'n' errorMessage:@"Error parsing object"];
			[self proceedAssumingCharacter:'d' errorMessage:@"Error parsing object"];
			[self proceedAssumingCharacter:'o' errorMessage:@"Error parsing object"];
			[self proceedAssumingCharacter:'b' errorMessage:@"Error parsing object"];
			[self proceedAssumingCharacter:'j' errorMessage:@"Error parsing object"];

			return value;
		break;

		default:
			[self _raiseParserException:@"Error parsing obj"];
			return nil; // Shut up, gcc.
	}
}

-(uint64_t)parseSimpleInteger
{
	uint64_t val=0;

	[self skipWhitespace];

	while(isdigit(currchar))
	{
		val=val*10+(currchar-'0');
		[self proceed];
	}

	return val;
}

-(uint64_t)parseIntegerOfSize:(int)size fromHandle:(CSHandle *)handle default:(uint64_t)def
{
	if(!size) return def;

	uint64_t res=0;
	for(int i=0;i<size;i++) res=(res<<8)|[handle readUInt8];

	return res;
}




-(void)parsePDFCompressedObjectStream:(PDFStream *)stream
{
	NSDictionary *dict=[stream dictionary];

	NSNumber *n=[dict objectForKey:@"N"];
	if(!n) [self _raiseParserException:@"Error decoding compressed object stream"];
	if(![n isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error decoding compressed object stream"];

	NSNumber *first=[dict objectForKey:@"First"];
	if(!first) [self _raiseParserException:@"Error decoding compressed object stream"];
	if(![first isKindOfClass:[NSNumber class]]) [self _raiseParserException:@"Error decoding compressed object stream"];

	CSHandle *handle=[stream handle];
	if(!handle) [self _raiseParserException:@"Error decoding compressed object stream"];

	int num=[n intValue];
	off_t startoffset=[first longLongValue];

	int objnums[num];
	off_t offsets[num];

	[self startParsingFromHandle:handle atOffset:0];

	for(int i=0;i<num;i++)
	{
		objnums[i]=[self parseSimpleInteger];
		offsets[i]=[self parseSimpleInteger];
	}

	for(int i=0;i<num;i++)
	{
		NSAutoreleasePool *pool=[NSAutoreleasePool new];

		PDFObjectReference *ref=[PDFObjectReference referenceWithNumber:objnums[i] generation:0];

		// TODO: Strings in compressed object streams are apparently
		// *not* encrypted. There needs to be some kind of flag for this,
		// but this is not yet implemented.
		[self startParsingFromHandle:handle atOffset:offsets[i]+startoffset];
		id value=[self parsePDFTypeWithParent:ref];

		if(value && ![objdict objectForKey:ref]) [objdict setObject:value forKey:ref];

		[pool release];
	}
}




-(id)parsePDFTypeWithParent:(PDFObjectReference *)parent
{
	[self skipWhitespace];

	switch(currchar)
	{
		case 'n': return [self parsePDFNull];

		case 't': case 'f': return [self parsePDFBool];

		case '0': case '1': case '2': case '3': case '4': case '5':
		case '6': case '7': case '8': case '9': case '-': case '.':
			return [self parsePDFNumber];

		case '/': return [self parsePDFWord];

		case '(': return [self parsePDFStringWithParent:parent];

		case '[': return [self parsePDFArrayWithParent:parent];

		case '<':
			[self proceed];

			if(currchar=='<')
			{
				return [self parsePDFDictionaryWithParent:parent];
			}
			else if(IsHexDigit(currchar)||IsWhitespace(currchar))
			{
				return [self parsePDFHexStringWithParent:parent];
			}
			else
			{
				return nil; // TODO: Should this be an exception?
			}
		break;

		default: return nil; // TODO: Should this be an exception?
	}
}

-(NSNull *)parsePDFNull
{
	[self proceedAssumingCharacter:'n' errorMessage:@"Error parsing null value"];
	[self proceedAssumingCharacter:'u' errorMessage:@"Error parsing null value"];
	[self proceedAssumingCharacter:'l' errorMessage:@"Error parsing null value"];
	[self proceedAssumingCharacter:'l' errorMessage:@"Error parsing null value"];

	return [NSNull null];
}

-(NSNumber *)parsePDFBool
{
	if(currchar=='t')
	{
		[self proceedAssumingCharacter:'t' errorMessage:@"Error parsing boolean true value"];
		[self proceedAssumingCharacter:'r' errorMessage:@"Error parsing boolean true value"];
		[self proceedAssumingCharacter:'u' errorMessage:@"Error parsing boolean true value"];
		[self proceedAssumingCharacter:'e' errorMessage:@"Error parsing boolean true value"];

		return [NSNumber numberWithBool:YES];
	}
	else
	{
		[self proceedAssumingCharacter:'f' errorMessage:@"Error parsing boolean false value"];
		[self proceedAssumingCharacter:'a' errorMessage:@"Error parsing boolean false value"];
		[self proceedAssumingCharacter:'l' errorMessage:@"Error parsing boolean false value"];
		[self proceedAssumingCharacter:'s' errorMessage:@"Error parsing boolean false value"];
		[self proceedAssumingCharacter:'e' errorMessage:@"Error parsing boolean false value"];

		return [NSNumber numberWithBool:NO];
	}
}

-(NSNumber *)parsePDFNumber
{
	NSMutableData *data=[NSMutableData data];

	if(currchar=='-' || currchar=='+')
	{
		[data appendBytes:(uint8_t [1]){currchar} length:1];
		[self proceed];
	}

	while(isdigit(currchar))
	{
		[data appendBytes:(uint8_t [1]){currchar} length:1];
		[self proceed];
	}

	if(currchar=='.')
	{
		[data appendBytes:(uint8_t [1]){currchar} length:1];
		[self proceed];

		while(isdigit(currchar))
		{
			[data appendBytes:(uint8_t [1]){currchar} length:1];
			[self proceed];
		}

		[data appendBytes:(uint8_t [1]){0} length:1];
		return [NSNumber numberWithDouble:atof([data bytes])];
	}
	else
	{
		[data appendBytes:(uint8_t [1]){0} length:1];
		return [NSNumber numberWithLongLong:atoll([data bytes])];
	}
}

-(NSString *)parsePDFWord
{
	NSMutableString *str=[NSMutableString string];

	[self proceedAssumingCharacter:'/' errorMessage:@""];

	for(;;)
	{
		if(currchar=='#')
		{
			[self proceed];
			int c1=currchar;
			[self proceed];
			int c2=currchar;

			if(!IsHexDigit(c1)||!IsHexDigit(c2)) [self _raiseParserException:@"Error parsing hex escape in name"];

			[str appendFormat:@"%c",HexDigit(c1)*16+HexDigit(c2)];
		}
		else if(IsWhitespace(currchar)||IsDelimiter(currchar))
		{
			return str;
		}
		else
		{
			[str appendFormat:@"%c",currchar];
		}

		[self proceed];
	}
}

-(PDFString *)parsePDFStringWithParent:(PDFObjectReference *)parent
{
	NSMutableData *data=[NSMutableData data];
	int nesting=1;

	[self proceedWithoutCommentHandling];

	for(;;)
	{
		uint8_t b=0;

		switch(currchar)
		{
			default:
				b=currchar;
			break;

			case '(':
				nesting++;
				b='(';
			break;

			case ')':
				if(--nesting==0)
				{
					[self proceed];
					return [[[PDFString alloc] initWithData:data parent:parent parser:self] autorelease];
				}
				else
				{
					b=')';
				}
			break;

			case '\\':
				[self proceedWithoutCommentHandling];
				switch(currchar)
				{
					default: b=currchar; break;
					case '\n': { [self proceedWithoutCommentHandling]; continue; } // Ignore newlines.
					case '\r': // Ignore carriage return.
						[self proceedWithoutCommentHandling];
						if(currchar=='\n') [self proceedWithoutCommentHandling]; // Ignore CRLF.
						continue;
 					break;
					case 'n': b='\n'; break; // Line feed.
					case 'r': b='\r'; break; // Carriage return.
					case 't': b='\t'; break; // Tab.
					case 'b': b='\b'; break; // Backspace.
					case 'f': b='\f'; break; // Form feed.
					case '0': case '1': case '2': case '3': // Octal character code.
					case '4': case '5': case '6': case '7':
						b=currchar-'0';
						[self proceedWithoutCommentHandling];
						if(currchar>='0'&&currchar<='7')
						{
							b=b*8+currchar-'0';
							[self proceedWithoutCommentHandling];
							if(currchar>='0'&&currchar<='7')
							{
								b=b*8+currchar-'0';
							}
						}
					break;
				}
			break;
		}

		[data appendBytes:&b length:1];

		[self proceedWithoutCommentHandling];
	}
}

-(PDFString *)parsePDFHexStringWithParent:(PDFObjectReference *)parent
{
	NSMutableData *data=[NSMutableData data];

	// Initial character has been consumed.

	for(;;)
	{
		[self skipWhitespace];
		if(!IsHexDigit(currchar) && currchar!='>') [self _raiseParserException:@"Error parsing hex data value"];
		int c1=currchar;
		[self proceed];

		if(c1=='>') return [[[PDFString alloc] initWithData:data parent:parent parser:self] autorelease];

		[self skipWhitespace];
		if(!IsHexDigit(currchar) && currchar!='>') [self _raiseParserException:@"Error parsing hex data value"];
		int c2=currchar;
		[self proceed];

		uint8_t byte=HexDigit(c1)*16+HexDigit(c2);
		[data appendBytes:&byte length:1];

		if(c2=='>') return [[[PDFString alloc] initWithData:data parent:parent parser:self] autorelease];
	}
}

-(NSArray *)parsePDFArrayWithParent:(PDFObjectReference *)parent
{
	NSMutableArray *array=[NSMutableArray array];

	[self proceedAssumingCharacter:'[' errorMessage:@""];

	for(;;)
	{
		[self skipWhitespace];

		if(currchar==']')
		{
			[self proceed];
			[unresolved addObject:array];
			return array;
		}
		else if(currchar=='R')
		{
			[self proceed];

			id num=[array objectAtIndex:[array count]-2];
			id gen=[array objectAtIndex:[array count]-1];

			if(![num isKindOfClass:[NSNumber class]] || ![gen isKindOfClass:[NSNumber class]])
			[self _raiseParserException:@"Error parsing indirect object in array"];

			PDFObjectReference *obj=[PDFObjectReference referenceWithNumberObject:num generationObject:gen];
			[array removeLastObject];
			[array removeLastObject];
			[array addObject:obj];
		}
		else
		{
			id value=[self parsePDFTypeWithParent:parent];
			if(!value) [self _raiseParserException:@"Error parsing array"]; // TODO: Replace with exception in method?

			[array addObject:value];
		}
	}
}

-(NSDictionary *)parsePDFDictionaryWithParent:(PDFObjectReference *)parent
{
	NSMutableDictionary *dict=[NSMutableDictionary dictionary];
	id prev_key=nil,prev_value=nil;

	[self proceedAssumingCharacter:'<' errorMessage:@""];

	for(;;)
	{
		[self skipWhitespace];

		if(currchar=='>')
		{
			[self proceedAssumingCharacter:'>' errorMessage:@"Error parsing dictionary"];
			[self proceedAssumingCharacter:'>' errorMessage:@"Error parsing dictionary"];

			[unresolved addObject:dict];
			return dict;
		}

		id key=[self parsePDFTypeWithParent:nil];
		if(!key) [self _raiseParserException:@"Error parsing dictionary"]; // TODO: Replace with exception in method?

		if([key isKindOfClass:[NSString class]])
		{
			id value=[self parsePDFTypeWithParent:parent];
			if(!value) [self _raiseParserException:@"Error parsing dictionary value"]; // TODO: Replace with exception in method?

			[dict setObject:value forKey:key];
			prev_key=key;
			prev_value=value;
		}
		else if([key isKindOfClass:[NSNumber class]])
		{
			[self skipWhitespace];

			if(currchar=='R')
			{
				[self proceed];

				if(![prev_value isKindOfClass:[NSNumber class]])
				[self _raiseParserException:@"Error parsing indirect object in dictionary"];

				[dict setObject:[PDFObjectReference referenceWithNumberObject:prev_value generationObject:key] forKey:prev_key];
				prev_key=nil;
				prev_value=nil;
			}
			else [self _raiseParserException:@"Error parsing indirect object in dictionary"];
		}
		else [self _raiseParserException:@"Error parsing dictionary key"];
	}
}

-(void)resolveIndirectObjects
{
	NSEnumerator *enumerator=[unresolved objectEnumerator];
	id obj;
	while(obj=[enumerator nextObject])
	{
		if([obj isKindOfClass:[NSDictionary class]])
		{
			NSMutableDictionary *dict=obj;
			NSEnumerator *keyenum=[[dict allKeys] objectEnumerator];
			NSString *key;
			while(key=[keyenum nextObject])
			{
				id value=[dict objectForKey:key];
				if([value isKindOfClass:[PDFObjectReference class]])
				{
					id realobj=[objdict objectForKey:value];
					if(realobj) [dict setObject:realobj forKey:key];
				}
			}
		}
		else if([obj isKindOfClass:[NSArray class]])
		{
			NSMutableArray *array=obj;
			int count=[array count];
			for(int i=0;i<count;i++)
			{
				id value=[array objectAtIndex:i];
				if([value isKindOfClass:[PDFObjectReference class]])
				{
					id realobj=[objdict objectForKey:value];
					if(realobj) [array replaceObjectAtIndex:i withObject:realobj];
				}
			}
		}
	}
}

-(void)_raiseParserException:(NSString *)error
{
	NSData *start;

	off_t offs=[fh offsetInFile];
	if(offs<100)
	{
		[fh seekToFileOffset:0];
		start=[fh readDataOfLength:offs];
	}
	else
	{
		[fh skipBytes:-100];
		start=[fh readDataOfLength:100];
	}

	int length=[start length];
	const uint8_t *bytes=[start bytes];
	int skip=0;
	for(int i=0;i<length;i++) if(bytes[i]=='\n'||bytes[i]=='\r') skip=i+1;
	NSString *startstr=[[[NSString alloc] initWithBytes:bytes+skip length:length-skip encoding:NSISOLatin1StringEncoding] autorelease];

	NSData *end=[fh readDataOfLengthAtMost:100];
	length=[end length];
	bytes=[end bytes];
	for(int i=0;i<length;i++) if(bytes[i]=='\n'||bytes[i]=='\r') { length=i; break; }
	NSString *endstr=[[[NSString alloc] initWithBytes:bytes length:length encoding:NSISOLatin1StringEncoding] autorelease];

	[NSException raise:PDFParserException format:@"%@: \"%@%C%@\"",error,startstr,(unichar)0x25bc,endstr];
}

@end



@implementation PDFString

-(id)initWithData:(NSData *)bytes parent:(PDFObjectReference *)parent parser:(PDFParser *)owner
{
	if(self=[super init])
	{
		data=[bytes retain];
		ref=[parent retain];
		parser=owner;
	}
	return self;
}

-(void)dealloc
{
	[data release];
	[ref release];
	[super dealloc];
}

-(NSData *)rawData { return data; }

-(PDFObjectReference *)reference { return ref; }

-(NSData *)data
{
	PDFEncryptionHandler *encryption=[parser encryptionHandler];
	if(encryption) return [encryption decryptString:self];
	else return data;
}

-(NSString *)string
{
	NSData *characters=[self data];
	int length=[characters length];
	const unsigned char *bytes=[characters bytes];

	if(length>=2&&bytes[0]==0xfe&&bytes[1]==0xff)
	{
		NSMutableString *string=[NSMutableString stringWithCapacity:length/2-1];

		for(int offset=2;offset<length;offset+=2)
		{
			[string appendFormat:@"%C",CSUInt16BE(&bytes[offset])];
		}

		return string;
	}
	else
	{
		return [[[NSString alloc] initWithData:characters encoding:NSISOLatin1StringEncoding] autorelease];
	}
}

-(BOOL)isEqual:(id)other
{
	return [other isKindOfClass:[PDFString class]]&&[data isEqual:((PDFString *)other)->data];
}

-(unsigned)hash { return [data hash]; }

-(id)copyWithZone:(NSZone *)zone
{
	return [[[self class] allocWithZone:zone] initWithData:data];
}

-(NSString *)description
{
	return [self string];
}

@end




@implementation PDFObjectReference

+(PDFObjectReference *)referenceWithNumber:(int)objnum generation:(int)objgen
{
	return [[[[self class] alloc] initWithNumber:objnum generation:objgen] autorelease];
}

+(PDFObjectReference *)referenceWithNumberObject:(NSNumber *)objnum generationObject:(NSNumber *)objgen
{
	return [[[[self class] alloc] initWithNumber:[objnum intValue] generation:[objgen intValue]] autorelease];
}

-(id)initWithNumber:(int)objnum generation:(int)objgen
{
	if(self=[super init])
	{
		num=objnum;
		gen=objgen;
	}
	return self;
}

-(int)number { return num; }

-(int)generation { return gen; }

-(BOOL)isEqual:(id)other
{
	return [other isKindOfClass:[PDFObjectReference class]]&&((PDFObjectReference *)other)->num==num&&((PDFObjectReference *)other)->gen==gen;
}

-(unsigned)hash { return num^(gen*69069); }

-(id)copyWithZone:(NSZone *)zone { return [[[self class] allocWithZone:zone] initWithNumber:num generation:gen]; }

-(NSString *)description { return [NSString stringWithFormat:@"<Reference to object %d, generation %d>",num,gen]; }

@end



static BOOL IsHexDigit(uint8_t c)
{
	return (c>='0'&&c<='9')||(c>='A'&&c<='F')||(c>='a'&&c<='f');
}

static BOOL IsWhitespace(uint8_t c)
{
	return c==' '||c=='\t'||c=='\r'||c=='\n'||c=='\f';
}

static BOOL IsDelimiter(uint8_t c)
{
	return c=='%'||c=='('||c==')'||c=='<'||c=='>'||c=='['||c==']'||c=='{'||c=='}'||c=='/';
}

static int HexDigit(uint8_t c)
{
	if(c>='0'&&c<='9') return c-'0'; 
	else if(c>='a'&&c<='f') return c-'a'+10; 
	else if(c>='A'&&c<='F') return c-'A'+10;
	else return 0; 
}
