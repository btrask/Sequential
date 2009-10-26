#import "XADPath.h"

@implementation XADPath

-(id)init
{
	if(self=[super init])
	{
		components=[[NSArray array] retain];
		source=nil;
	}
	return self;
}

-(id)initWithComponents:(NSArray *)pathcomponents
{
	if(self=[super init])
	{
		components=[pathcomponents retain];
		source=nil;

		NSEnumerator *enumerator=[components objectEnumerator];
		XADString *string;
		while(string=[enumerator nextObject]) [self _updateStringSourceWithString:string];
	}
	return self;
}

-(id)initWithString:(NSString *)pathstring
{
	if(self=[super init])
	{
		NSArray *stringcomps=[pathstring pathComponents];
		int count=[stringcomps count];
		if(count>1&&[[stringcomps lastObject] isEqual:@"/"]) count--; // ignore ending slashes, just like NSString does

		NSMutableArray *array=[NSMutableArray arrayWithCapacity:count];
		for(int i=0;i<count;i++)
		{
			[array addObject:[XADString XADStringWithString:[stringcomps objectAtIndex:i]]];
		}

		components=[array copy];
		source=nil;
	}
	return self;
}

static inline BOOL IsSeparator(char c,const char *separators)
{
	return strchr(separators,c)!=NULL; // Note: \0 is always considered a separator!
}

-(id)initWithBytes:(const char *)bytes length:(int)length
encoding:(NSStringEncoding)encoding separators:(const char *)separators
{
	return [self initWithBytes:bytes length:length encoding:encoding separators:separators source:nil];
}

-(id)initWithBytes:(const char *)bytes length:(int)length
separators:(const char *)separators source:(XADStringSource *)stringsource
{
	return [self initWithBytes:bytes length:length encoding:0 separators:separators source:stringsource];
}

-(id)initWithBytes:(const char *)bytes length:(int)length encoding:(NSStringEncoding)encoding
separators:(const char *)separators source:(XADStringSource *)stringsource
{
	if(self=[super init])
	{
		NSMutableArray *array=[NSMutableArray array];

		if(length>0)
		{
			if(IsSeparator(bytes[0],separators)) [array addObject:[XADString XADStringWithString:@"/"]];

			int i=0;
			while(i<length)
			{
				while(i<length&&IsSeparator(bytes[i],separators)) i++;
				if(i>=length) break;

				int start=i;
				while(i<length&&!IsSeparator(bytes[i],separators)) i++;

				NSData *data=[NSData dataWithBytes:&bytes[start] length:i-start];

				if(encoding)
				{
					NSString *string=[[[NSString alloc] initWithData:data encoding:encoding] autorelease];
					[array addObject:[[[XADString alloc] initWithString:string] autorelease]];
				}
				else [array addObject:[[[XADString alloc] initWithData:data source:stringsource] autorelease]];
			}
		}

		components=[array copy];
		source=[stringsource retain];
	}
	return self;
}

-(void)dealloc
{
	[components release];
	[source release];
	[super dealloc];
}

-(void)_updateStringSourceWithString:(XADString *)string
{
	XADStringSource *othersource=[string source];
	if(source)
	{
		if(othersource&&othersource!=source)
		[NSException raise:@"XADPathSourceMismatchException" format:@"Attempted to use XADStrings with different string sources in XADPath"];
	}
	else source=[othersource retain];
}



// TODO: check for short paths for the following four?

-(XADString *)lastPathComponent { return [components lastObject]; }

-(XADString *)firstPathComponent { return [components objectAtIndex:0]; }

-(XADPath *)pathByDeletingLastPathComponent
{
	return [[[XADPath alloc] initWithComponents:
	[components subarrayWithRange:NSMakeRange(0,[components count]-1)]]
	autorelease];
}

-(XADPath *)pathByDeletingFirstPathComponent
{
	return [[[XADPath alloc] initWithComponents:
	[components subarrayWithRange:NSMakeRange(1,[components count]-1)]]
	autorelease];
}

-(XADPath *)pathByAppendingPathComponent:(XADString *)component
{
	return [[[XADPath alloc] initWithComponents:[components arrayByAddingObject:component]] autorelease];
}

-(XADPath *)pathByAppendingPath:(XADPath *)path
{
	return [[[XADPath alloc] initWithComponents:[components arrayByAddingObjectsFromArray:path->components]] autorelease];
}

-(XADPath *)safePath
{
	NSMutableArray *safecomponents=[NSMutableArray arrayWithArray:components];

	// Drop . anywhere in the path
	for(int i=0;i<[safecomponents count];)
	{
		XADString *comp=[safecomponents objectAtIndex:i];
		if([comp isEqual:@"."]) [safecomponents removeObjectAtIndex:i];
		else i++;
	}

	// Drop all .. that can be dropped
	for(int i=1;i<[safecomponents count];)
	{
		XADString *comp1=[safecomponents objectAtIndex:i-1];
		XADString *comp2=[safecomponents objectAtIndex:i];
		if(![comp1 isEqual:@".."]&&[comp2 isEqual:@".."])
		{
			[safecomponents removeObjectAtIndex:i];
			[safecomponents removeObjectAtIndex:i-1];
			if(i>1) i--;
		}
		else i++;
	}

	// Drop slashes and .. at the start of the path
	while([safecomponents count])
	{
		NSString *first=[safecomponents objectAtIndex:0];
		if([first isEqual:@".."]||[first isEqual:@"/"]) [safecomponents removeObjectAtIndex:0];
		else break;
	}

	return [[[XADPath alloc] initWithComponents:safecomponents] autorelease];
}



-(BOOL)isAbsolute
{
	return [components count]>0&&[[components objectAtIndex:0] isEqual:@"/"];
}

-(BOOL)hasPrefix:(XADPath *)other
{
	int count=[components count];
	int othercount=[other->components count];

	if(othercount>count) return NO;

	for(int i=0;i<othercount;i++)
	{
		if(![[components objectAtIndex:i] isEqual:[other->components objectAtIndex:i]]) return NO;
	}

	return YES;
}



-(NSString *)string
{
	return [self stringWithEncoding:[source encoding]];
}

-(NSString *)stringWithEncoding:(NSStringEncoding)encoding
{
	NSMutableString *string=[NSMutableString string];

	int count=[components count];
	int i=0;

	if(count>1&&[[components objectAtIndex:0] isEqual:@"/"]) i++;

	for(;i<count;i++)
	{
		if(i!=0) [string appendString:@"/"];

		NSString *compstring=[[components objectAtIndex:i] stringWithEncoding:encoding];

		if([compstring rangeOfString:@"/"].location==NSNotFound) [string appendString:compstring];
		else
		{
			NSMutableString *newstring=[NSMutableString stringWithString:compstring];
			[newstring replaceOccurrencesOfString:@"/" withString:@":" options:0 range:NSMakeRange(0,[newstring length])];

			[string appendString:newstring];
		}
	}

	return string;
}

-(NSData *)data
{
	NSMutableData *data=[NSMutableData data];

	int count=[components count];
	int i=0;

	if(count>1&&[[components objectAtIndex:0] isEqual:@"/"]) i++;

	for(;i<count;i++)
	{
		if(i!=0) [data appendBytes:"/" length:1];
		// NOTE: Doesn't map '/' to ':'.
		[data appendData:[[components objectAtIndex:i] data]];
	}

	return data;
}



-(BOOL)encodingIsKnown
{
	if(!source) return YES;
	if([source hasFixedEncoding]) return YES;
	return NO;
}

-(NSStringEncoding)encoding
{
	if(!source) return NSUTF8StringEncoding; // TODO: what should this really return?
	return [source encoding];
}

-(float)confidence
{
	if(!source) return 1;
	return [source confidence];
}



-(XADStringSource *)source { return source; }



-(NSString *)description
{
	// TODO: more info?
	return [self string];
}

-(BOOL)isEqual:(id)other { return [other isKindOfClass:[XADPath class]]&&[components isEqual:((XADPath *)other)->components]; }

-(NSUInteger)hash
{
	int count=[components count];
	if(!count) return 0;
	return [[components lastObject] hash]^count;
}

-(id)copyWithZone:(NSZone *)zone { return [self retain]; } // class is immutable, so just return self

@end
