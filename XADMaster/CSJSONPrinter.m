#import "CSJSONPrinter.h"
#import "NSStringPrinting.h"

@implementation CSJSONPrinter

-(id)init
{
	if(self=[super init])
	{
		indentlevel=0;
		indentstring=[@"\n" retain];
	}
	return self;
}

-(void)dealloc
{
	[indentstring release];
	[super dealloc];
}




-(void)setIndentString:(NSString *)string
{
	[indentstring autorelease];
	indentstring=[string retain];
}

-(void)setASCIIMode:(BOOL)ascii
{
	asciimode=ascii;
}



-(void)printObject:(id)object
{
	if(object==[NSNull null]) [self printNull];
	else if([object isKindOfClass:[NSNumber class]]) [self printNumber:object];
	else if([object isKindOfClass:[NSString class]]) [self printString:object];
	else if([object isKindOfClass:[NSData class]]) [self printData:object];
	else if([object isKindOfClass:[NSValue class]]) [self printValue:object];
	else if([object isKindOfClass:[NSArray class]]) [self printArray:object];
	else if([object isKindOfClass:[NSDictionary class]]) [self printDictionary:object];
	else [self printString:[object description]];
}

-(void)printNull
{
	[@"null" print];
}

-(void)printNumber:(NSNumber *)number
{
	if(strcmp([number objCType],"c")==0)
	{
		if([number boolValue]) [@"true" print];
		else [@"false" print];
	}
	else
	{
		[[number description] print];
	}
}

-(void)printString:(NSString *)string
{
	[@"\"" print];
	[[self stringByEscapingString:string] print];
	[@"\"" print];
}

-(void)printData:(NSData *)data
{
	[@"\"" print];
	[[self stringByEncodingBytes:[data bytes] length:[data length]] print];
	[@"\"" print];
}

-(void)printValue:(NSValue *)value
{
	NSUInteger length;
	NSGetSizeAndAlignment([value objCType],&length,NULL);
	uint8_t bytes[length];
	[value getValue:bytes];

	[@"\"" print];
	[[self stringByEncodingBytes:bytes length:length] print];
	[@"\"" print];
}

-(void)printArray:(NSArray *)array
{
	[self startPrintingArray];
	[self printArrayObjects:array];
	[self endPrintingArray];
}

-(void)printDictionary:(NSDictionary *)dictionary
{
	[self startPrintingDictionary];
	[self printDictionaryKeysAndObjects:dictionary];
	[self endPrintingDictionary];
}



-(void)startPrintingArray
{
	[@"[" print];
	indentlevel++;
}

-(void)startPrintingArrayObject
{
	[self startNewLine];
}

-(void)endPrintingArrayObject
{
	[@"," print];
}

-(void)endPrintingArray
{
	indentlevel--;
	[self startNewLine];
	[@"]" print];
}

-(void)printArrayObject:(id)object
{
	[self startPrintingArrayObject];
	[self printObject:object];
	[self endPrintingArrayObject];
}

-(void)printArrayObjects:(NSArray *)array
{
	NSEnumerator *enumerator=[array objectEnumerator];
	id object;
	while(object=[enumerator nextObject]) [self printArrayObject:object];
}





-(void)startPrintingDictionary
{
	[@"{" print];
	indentlevel++;
}

-(void)printDictionaryKey:(id)key
{
	[self startNewLine];
	[@"\"" print];
	[[self stringByEscapingString:[key description]] print];
	[@"\": " print];
}

-(void)startPrintingDictionaryObject
{
}

-(void)endPrintingDictionaryObject
{
	[@"," print];
}

-(void)endPrintingDictionary
{
	indentlevel--;
	[self startNewLine];
	[@"}" print];
}

-(void)printDictionaryObject:(id)object
{
	[self startPrintingDictionaryObject];
	[self printObject:object];
	[self endPrintingDictionaryObject];
}

-(void)printDictionaryKeysAndObjects:(NSDictionary *)dictionary
{
	NSEnumerator *enumerator=[dictionary keyEnumerator];
	id key;
	while(key=[enumerator nextObject])
	{
		[self printDictionaryKey:key];
		[self printDictionaryObject:[dictionary objectForKey:key]];
	}
}




-(void)startNewLine
{
	[@"\n" print];
	for(int i=0;i<indentlevel;i++) [indentstring print];
}



-(NSString *)stringByEscapingString:(NSString *)string
{
	int length=[string length];
	NSMutableString *res=[NSMutableString stringWithCapacity:length];

	for(int i=0;i<length;i++)
	{
		unichar c=[string characterAtIndex:i];
		if(c=='"'||c=='\\') [res appendFormat:@"\\%C",c];
		else if(c=='\b') [res appendString:@"\\b"];
		else if(c=='\f') [res appendString:@"\\f"];
		else if(c=='\n') [res appendString:@"\\n"];
		else if(c=='\r') [res appendString:@"\\r"];
		else if(c=='\t') [res appendString:@"\\t"];
		else if(c<32) [res appendFormat:@"\\u%04x",c];
		else if(asciimode&&c>=128) [res appendFormat:@"\\u%04x",c];
		else [res appendFormat:@"%C",c];
	}

	return res;
}

-(NSString *)stringByEncodingBytes:(const uint8_t *)bytes length:(int)length
{
	NSMutableString *res=[NSMutableString stringWithCapacity:length*6];

	for(int i=0;i<length;i++) [res appendFormat:@"\\u%04x",bytes[i]];

	return res;
}

@end
