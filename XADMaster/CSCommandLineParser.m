#import "CSCommandLineParser.h"
#import "NSStringPrinting.h"

#ifdef __MINGW32__
#import <windows.h>
#endif



static NSString *NamesKey=@"NamesKey";
static NSString *AllowedValuesKey=@"AllowedValuesKey";
static NSString *DefaultValueKey=@"DefaultValueKey";
static NSString *OptionTypeKey=@"OptionType";
static NSString *DescriptionKey=@"DescriptionKey";
static NSString *ArgumentDescriptionKey=@"ArgumentDescriptionKey";
static NSString *AliasTargetKey=@"AliasTargetKey";
static NSString *RequiredOptionsKey=@"RequiredOptionsKey";

static NSString *NumberValueKey=@"NumberValue";
static NSString *StringValueKey=@"StringValue";
static NSString *ArrayValueKey=@"ArrayValue";

static NSString *StringOptionType=@"StringOptionType";
static NSString *MultipleChoiceOptionType=@"MultipleChoiceOptionType";
static NSString *IntegerOptionType=@"IntegerOptionType";
static NSString *FloatingPointOptionType=@"FloatingPointOptionType";
static NSString *SwitchOptionType=@"SwitchOptionType";
static NSString *HelpOptionType=@"HelpOptionType";
static NSString *AliasOptionType=@"AliasOptionType";

#if MAC_OS_X_VERSION_MAX_ALLOWED<1050
@interface NSScanner (BuildKludge)
-(BOOL)scanHexLongLong:(unsigned long long *)val;
-(BOOL)scanHexDouble:(double *)val;
@end
#endif

@implementation CSCommandLineParser

-(id)init
{
	if((self=[super init]))
	{
		options=[NSMutableDictionary new];
		optionordering=[NSMutableArray new];
		alwaysrequiredoptions=[NSMutableArray new];

		remainingargumentarray=nil;

		programname=nil;
		usageheader=nil;
		usagefooter=nil;
	}
	return self;
}

-(void)dealloc
{
	[options release];
	[optionordering release];
	[alwaysrequiredoptions release];

	[remainingargumentarray release];

	[programname release];
	[usageheader release];
	[usagefooter release];

	[super dealloc];
}




-(void)setProgramName:(NSString *)name
{
	[programname autorelease];
	programname=[name retain];
}

-(void)setUsageHeader:(NSString *)header
{
	[usageheader autorelease];
	usageheader=[header retain];
}

-(void)setUsageFooter:(NSString *)footer
{
	[usagefooter autorelease];
	usagefooter=[footer retain];
}



-(void)addStringOption:(NSString *)option
description:(NSString *)description
{
	[self addStringOption:option defaultValue:nil description:description argumentDescription:@"string"];
}

-(void)addStringOption:(NSString *)option defaultValue:(NSString *)defaultvalue
description:(NSString *)description
{
	[self addStringOption:option defaultValue:defaultvalue description:description argumentDescription:@"string"];
}

-(void)addStringOption:(NSString *)option
description:(NSString *)description argumentDescription:(NSString *)argdescription
{
	[self addStringOption:option defaultValue:nil description:description argumentDescription:argdescription];
}

-(void)addStringOption:(NSString *)option defaultValue:(NSString *)defaultvalue
description:(NSString *)description argumentDescription:(NSString *)argdescription
{
	[self _assertOptionNameIsUnique:option];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		StringOptionType,OptionTypeKey,
		description,DescriptionKey,
		argdescription,ArgumentDescriptionKey,
	nil];
	if(defaultvalue) [dict setObject:defaultvalue forKey:DefaultValueKey];

	[options setObject:dict forKey:option];
	[optionordering addObject:option];
}




-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues
description:(NSString *)description
{
	[self addMultipleChoiceOption:option allowedValues:allowedvalues defaultValue:nil
	description:description argumentDescription:[allowedvalues componentsJoinedByString:@"|"]];
}

-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues defaultValue:(NSString *)defaultvalue
description:(NSString *)description
{
	[self addMultipleChoiceOption:option allowedValues:allowedvalues defaultValue:defaultvalue
	description:description argumentDescription:[allowedvalues componentsJoinedByString:@"|"]];
}

-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues
description:(NSString *)description argumentDescription:(NSString *)argdescription
{
	[self addMultipleChoiceOption:option allowedValues:allowedvalues defaultValue:nil
	description:description argumentDescription:argdescription];
}

-(void)addMultipleChoiceOption:(NSString *)option allowedValues:(NSArray *)allowedvalues defaultValue:(NSString *)defaultvalue
description:(NSString *)description argumentDescription:(NSString *)argdescription
{
	[self _assertOptionNameIsUnique:option];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		allowedvalues,AllowedValuesKey,
		MultipleChoiceOptionType,OptionTypeKey,
		description,DescriptionKey,
		argdescription,ArgumentDescriptionKey,
	nil];
	if(defaultvalue)
	{
		NSUInteger index=[allowedvalues indexOfObject:[defaultvalue lowercaseString]];
		if(index==NSNotFound) [NSException raise:NSInvalidArgumentException format:
		@"Default value \"%@\" is not in the array of allowed values.",defaultvalue];
		[dict setObject:[NSNumber numberWithUnsignedInt:index] forKey:DefaultValueKey];
	}

	[options setObject:dict forKey:option];
	[optionordering addObject:option];
}




-(void)addIntegerOption:(NSString *)option
description:(NSString *)description
{
	[self addIntegerOption:option
	description:description argumentDescription:@"integer"];
}

-(void)addIntegerOption:(NSString *)option
description:(NSString *)description argumentDescription:(NSString *)argdescription
{
	[self _assertOptionNameIsUnique:option];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		IntegerOptionType,OptionTypeKey,
		description,DescriptionKey,
		argdescription,ArgumentDescriptionKey,
	nil];

	[options setObject:dict forKey:option];
	[optionordering addObject:option];
}

-(void)addIntegerOption:(NSString *)option defaultValue:(int)defaultvalue
description:(NSString *)description
{
	[self addIntegerOption:option defaultValue:defaultvalue
	description:description argumentDescription:@"integer"];
}

-(void)addIntegerOption:(NSString *)option defaultValue:(int)defaultvalue
description:(NSString *)description argumentDescription:(NSString *)argdescription
{
	[self _assertOptionNameIsUnique:option];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		[NSNumber numberWithInt:defaultvalue],DefaultValueKey,
		IntegerOptionType,OptionTypeKey,
		description,DescriptionKey,
		argdescription,ArgumentDescriptionKey,
	nil];

	[options setObject:dict forKey:option];
	[optionordering addObject:option];
}

// Int options with range?




-(void)addFloatingPointOption:(NSString *)option
description:(NSString *)description
{
	[self addFloatingPointOption:option
	description:description argumentDescription:@"number"];
}

-(void)addFloatingPointOption:(NSString *)option
description:(NSString *)description argumentDescription:(NSString *)argdescription
{
	[self _assertOptionNameIsUnique:option];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		FloatingPointOptionType,OptionTypeKey,
		description,DescriptionKey,
		argdescription,ArgumentDescriptionKey,
	nil];

	[options setObject:dict forKey:option];
	[optionordering addObject:option];
}

-(void)addFloatingPointOption:(NSString *)option defaultValue:(double)defaultvalue
description:(NSString *)description
{
	[self addFloatingPointOption:option defaultValue:defaultvalue
	description:description argumentDescription:@"number"];
}

-(void)addFloatingPointOption:(NSString *)option defaultValue:(double)defaultvalue
description:(NSString *)description argumentDescription:(NSString *)argdescription
{
	[self _assertOptionNameIsUnique:option];

	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		[NSNumber numberWithDouble:defaultvalue],DefaultValueKey,
		FloatingPointOptionType,OptionTypeKey,
		description,DescriptionKey,
		argdescription,ArgumentDescriptionKey,
	nil];

	[options setObject:dict forKey:option];
	[optionordering addObject:option];
}




-(void)addSwitchOption:(NSString *)option description:(NSString *)description
{
	[self _assertOptionNameIsUnique:option];
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:option],NamesKey,
		SwitchOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:option];
	[optionordering addObject:option];
}




-(void)addHelpOption
{
	[self addHelpOptionNamed:@"help" description:@"Display this information."];
	[self addAlias:@"h" forOption:@"help"];
}

-(void)addHelpOptionNamed:(NSString *)helpoption description:(NSString *)description
{
	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[NSMutableArray arrayWithObject:helpoption],NamesKey,
		HelpOptionType,OptionTypeKey,
		description,DescriptionKey,
	nil] forKey:helpoption];
	[optionordering addObject:helpoption];
}




-(void)addAlias:(NSString *)alias forOption:(NSString *)option
{
	[self _assertOptionNameIsUnique:alias];

	NSMutableDictionary *dict=[options objectForKey:option];
	if(!dict) [self _raiseUnknownOption:option];

	[[dict objectForKey:NamesKey] addObject:alias];

	[options setObject:[NSMutableDictionary dictionaryWithObjectsAndKeys:
		option,AliasTargetKey,
		AliasOptionType,OptionTypeKey,
	nil] forKey:alias];
}




-(void)addRequiredOption:(NSString *)requiredoption
{
	if(![options objectForKey:requiredoption]) [self _raiseUnknownOption:requiredoption];

	[alwaysrequiredoptions addObject:requiredoption];
}

-(void)addRequiredOptionsArray:(NSArray *)requiredoptions
{
	NSEnumerator *enumerator=[requiredoptions objectEnumerator];
	NSString *requiredoption;
	while((requiredoption=[enumerator nextObject])) [self addRequiredOption:requiredoption];
}

-(void)addRequiredOption:(NSString *)requiredoption forOption:(NSString *)option
{
	NSMutableDictionary *dict=[options objectForKey:option];
	if(!dict) [self _raiseUnknownOption:option];

	NSMutableArray *requiredoptions=[dict objectForKey:RequiredOptionsKey];
	if(requiredoptions) [requiredoptions addObject:requiredoption];
	else
	{
		requiredoptions=[NSMutableArray arrayWithObject:requiredoption];
		[dict setObject:requiredoptions forKey:RequiredOptionsKey];
	}
}

-(void)addRequiredOptionsArray:(NSArray *)requiredoptions forOption:(NSString *)option
{
	NSEnumerator *enumerator=[requiredoptions objectEnumerator];
	NSString *requiredoption;
	while((requiredoption=[enumerator nextObject])) [self addRequiredOption:requiredoption forOption:option];
}




-(BOOL)parseCommandLineWithArgc:(int)argc argv:(const char **)argv
{
	NSMutableArray *arguments=[NSMutableArray array];

	#ifdef __MINGW32__
	int wargc;
	wchar_t **wargv=CommandLineToArgvW(GetCommandLineW(),&wargc);
	for(int i=1;i<wargc;i++) [arguments addObject:[NSString stringWithCharacters:wargv[i] length:wcslen(wargv[i])]];
	if(!programname) [self setProgramName:[NSString stringWithCharacters:wargv[0] length:wcslen(wargv[0])]];
	#else
	for(int i=1;i<argc;i++) [arguments addObject:[NSString stringWithUTF8String:argv[i]]];
	if(!programname) [self setProgramName:[NSString stringWithUTF8String:argv[0]]];
	#endif

	return [self parseArgumentArray:arguments];
}

-(BOOL)parseArgumentArray:(NSArray *)arguments
{
	NSMutableArray *remainingarguments=[NSMutableArray array];
	NSMutableArray *errors=[NSMutableArray array];

	[self _parseArguments:arguments remainingArguments:remainingarguments errors:errors];
	[self _setDefaultValues];
	[self _parseRemainingArguments:remainingarguments errors:errors];
	[self _enforceRequirementsWithErrors:errors];

	if([errors count])
	{
		[self _reportErrors:errors];
		return NO;
	}
	else return YES;
}

-(void)_parseArguments:(NSArray *)arguments remainingArguments:(NSMutableArray *)remainingarguments
errors:(NSMutableArray *)errors
{
	NSEnumerator *enumerator=[arguments objectEnumerator];
	NSString *argument;
	BOOL stillparsing=YES;
	while((argument=[enumerator nextObject]))
	{
		// Check for options, unless we have seen a stop marker.
		if(stillparsing && [argument length]>1 && [argument characterAtIndex:0]=='-')
		{
			// Check for a stop marker.
			if([argument isEqual:@"--"])
			{
				stillparsing=NO;
				continue;
			}

			// See if option starts with one or two dashes (treated the same for now).
			int firstchar=1;
			if([argument characterAtIndex:1]=='-') firstchar=2;

			// See if the option is of the form -option=value, and extract the name and value.
			// Otherwise, just extract the name.
			NSString *option,*value;
			NSRange equalsign=[argument rangeOfString:@"="];
			if(equalsign.location!=NSNotFound)
			{
				option=[argument substringWithRange:NSMakeRange(firstchar,equalsign.location-firstchar)];
				value=[argument substringFromIndex:equalsign.location+1];
			}
			else
			{
				option=[argument substringFromIndex:firstchar];
				value=nil; // Find the value later.
			}

			// Find option dictionary, or produce an error if the option is not known.
			NSMutableDictionary *dict=[options objectForKey:option];
			if(!dict)
			{
				[errors addObject:[NSString stringWithFormat:@"Unknown option %@.",argument]];
				continue;
			}

			NSString *type=[dict objectForKey:OptionTypeKey];

			// Resolve aliases.
			while(type==AliasOptionType)
			{
				dict=[options objectForKey:[dict objectForKey:AliasTargetKey]];
				type=[dict objectForKey:OptionTypeKey];
			}

			// Handle help options.
			if(type==HelpOptionType)
			{
				[self printUsage];
				exit(0);
			}

			// Find value for options of the form -option value, if needed.
			if(!value)
			if(type==StringOptionType||type==MultipleChoiceOptionType||
			type==IntegerOptionType||type==FloatingPointOptionType)
			{
				value=[enumerator nextObject];
				if(!value)
				{
					[errors addObject:[NSString stringWithFormat:@"The option -%@ requires a value.",option]];
					continue;
				}
			}

			// Actually parse value and type
			[self _parseOptionWithDictionary:dict type:type name:option value:value errors:errors];
		}
		else
		{
			[remainingarguments addObject:argument];
		}
	}
}

-(void)_parseOptionWithDictionary:(NSMutableDictionary *)dict type:(NSString *)type
name:(NSString *)option value:(NSString *)value errors:(NSMutableArray *)errors
{
	if(type==StringOptionType)
	{
		[dict setObject:value forKey:StringValueKey];
	}
	else if(type==MultipleChoiceOptionType)
	{
		NSArray *allowedvalues=[dict objectForKey:AllowedValuesKey];
		NSUInteger index=[allowedvalues indexOfObject:[value lowercaseString]];
		if(index==NSNotFound)
		{
			[errors addObject:[NSString stringWithFormat:@"\"%@\" is not a valid "
			@"value for option \"%@\". (Valid values are: %@.)",value,option,
			[allowedvalues componentsJoinedByString:@", "]]];
			return;
		}

		[dict setObject:[allowedvalues objectAtIndex:index] forKey:StringValueKey];
		[dict setObject:[NSNumber numberWithUnsignedInt:index] forKey:NumberValueKey];
	}
	else if(type==IntegerOptionType)
	{
		NSScanner *scanner=[NSScanner scannerWithString:value];
		BOOL success;
		if([value hasPrefix:@"0x"]||[value hasPrefix:@"0X"])
		{
			unsigned long long intval;
			success=[scanner scanHexLongLong:&intval];
			if(success) [dict setObject:[NSNumber numberWithUnsignedLongLong:intval] forKey:NumberValueKey];
		}
		else
		{
			long long intval;
			success=[scanner scanLongLong:&intval];
			if(success) [dict setObject:[NSNumber numberWithLongLong:intval] forKey:NumberValueKey];
		}

		if(!success)
		{
			[errors addObject:[NSString stringWithFormat:@"The option -%@ requires an "
			@"integer number value.",option]];
			return;
		}
	}
	else if(type==FloatingPointOptionType)
	{
		NSScanner *scanner=[NSScanner scannerWithString:value];
		double floatval;
		BOOL success;

		#ifndef __COCOTRON__
		if([value hasPrefix:@"0x"]||[value hasPrefix:@"0X"]) success=[scanner scanHexDouble:&floatval];
		else success=[scanner scanDouble:&floatval];
		#else
		success=[scanner scanDouble:&floatval];
		#endif

		if(!success)
		{
			[errors addObject:[NSString stringWithFormat:@"The option -%@ requires a "
			@"floating-point number value.",option]];
			return;
		}

		[dict setObject:[NSNumber numberWithDouble:floatval] forKey:NumberValueKey];
	}
	else if(type==SwitchOptionType)
	{
		[dict setObject:[NSNumber numberWithBool:YES] forKey:NumberValueKey];
	}
}

-(void)_setDefaultValues
{
	NSEnumerator *enumerator=[options objectEnumerator];
	NSMutableDictionary *dict;
	while((dict=[enumerator nextObject]))
	{
		id defaultvalue=[dict objectForKey:DefaultValueKey];
		if(!defaultvalue) continue;

		NSString *type=[dict objectForKey:OptionTypeKey];

		if(type==StringOptionType)
		{
			if(![dict objectForKey:StringValueKey]) [dict setObject:defaultvalue forKey:StringValueKey];
		}
		else if(type==MultipleChoiceOptionType)
		{
			if(![dict objectForKey:NumberValueKey])
			{
				int index=[defaultvalue unsignedIntValue];
				NSArray *allowedvalues=[dict objectForKey:AllowedValuesKey];
				[dict setObject:[allowedvalues objectAtIndex:index] forKey:StringValueKey];
				[dict setObject:defaultvalue forKey:NumberValueKey];
			}
		}
		else if(type==IntegerOptionType||type==FloatingPointOptionType)
		{
			if(![dict objectForKey:NumberValueKey]) [dict setObject:defaultvalue forKey:NumberValueKey];
		}
	}
}

-(void)_parseRemainingArguments:(NSArray *)remainingarguments errors:(NSMutableArray *)errors
{
	[remainingargumentarray autorelease];
	remainingargumentarray=[remainingarguments retain];
}

-(void)_enforceRequirementsWithErrors:(NSMutableArray *)errors
{
	if([alwaysrequiredoptions count]) [self _requireOptionsInArray:alwaysrequiredoptions when:@"" errors:errors];

	NSEnumerator *enumerator=[options objectEnumerator];
	NSDictionary *dict;
	while((dict=[enumerator nextObject]))
	{
		NSArray *names=[dict objectForKey:NamesKey];
		NSString *name=[names objectAtIndex:0];
		NSArray *requiredoptions=[dict objectForKey:RequiredOptionsKey];

		if(requiredoptions)
		if([self _isOptionDefined:name])
		{
			[self _requireOptionsInArray:requiredoptions
			when:[NSString stringWithFormat:@" when the option %@ is used",[self _describeOption:name]]
			errors:errors];
		}
	}
}

-(void)_requireOptionsInArray:(NSArray *)requiredoptions when:(NSString *)when errors:(NSMutableArray *)errors
{
	NSMutableSet *set=[NSMutableSet set];

	NSEnumerator *enumerator=[requiredoptions objectEnumerator];
	NSString *requiredoption;
	while((requiredoption=[enumerator nextObject]))
	{
		if(![self _isOptionDefined:requiredoption]) [set addObject:requiredoption];
	}

	if([set count]==0) return;

	NSMutableArray *array=[NSMutableArray array];

	enumerator=[optionordering objectEnumerator];
	NSString *option;
	while((option=[enumerator nextObject]))
	{
		if([set containsObject:option]) [array addObject:[self _describeOption:option]];
	}

	if([array count]==1)
	{
		[errors addObject:[NSString stringWithFormat:@"The option %@ is required%@.",[array objectAtIndex:0],when]];
	}
	else
	{
		[errors addObject:[NSString stringWithFormat:@"The options %@ and %@ are required%@.",[array objectAtIndex:0],
		[[array subarrayWithRange:NSMakeRange(0,[array count]-1)] componentsJoinedByString:@", "],when]];
	}
}

-(BOOL)_isOptionDefined:(NSString *)option
{
	NSDictionary *dict=[options objectForKey:option];
	return [dict objectForKey:StringValueKey]||[dict objectForKey:NumberValueKey]||[dict objectForKey:ArrayValueKey];
}

-(NSString *)_describeOption:(NSString *)name
{
	NSDictionary *dict=[options objectForKey:name];
	NSArray *names=[dict objectForKey:NamesKey];
	if([names count]==1) return [names objectAtIndex:0];
	else return [NSString stringWithFormat:@"-%@ (-%@)",[names objectAtIndex:0],
	[[names subarrayWithRange:NSMakeRange(1,[names count]-1)] componentsJoinedByString:@", -"]];
}

-(NSString *)_describeOptionAndArgument:(NSString *)name
{
	NSDictionary *dict=[options objectForKey:name];
	NSString *argdescription=[dict objectForKey:ArgumentDescriptionKey];

	if(argdescription) return [NSString stringWithFormat:@"%@ <%@>",[self _describeOption:name],argdescription];
	else return [self _describeOption:name];
}

-(void)_reportErrors:(NSArray *)errors
{
	NSEnumerator *enumerator=[errors objectEnumerator];
	NSString *error;
	while((error=[enumerator nextObject]))
	{
		[error print];
		[@"\n" print];
	}
}



-(void)printUsage
{
	[usageheader print];

	int terminalwidth=[NSString terminalWidth];
	int count=[optionordering count];
	int maxlength=0;

	NSMutableArray *optiondescriptions=[NSMutableArray array];

	for(int i=0;i<count;i++)
	{
		NSString *option=[optionordering objectAtIndex:i];

		NSString *description=[self _describeOptionAndArgument:option];

		[optiondescriptions addObject:description];

		int length=[description length];
		if(length>maxlength) maxlength=length;
	}

	int columnwidth1=maxlength+2;
	int columnwidth2=terminalwidth-columnwidth1;

	for(int i=0;i<count;i++)
	{
		NSString *option=[optionordering objectAtIndex:i];
		NSString *optiondescription=[optiondescriptions objectAtIndex:i];
		NSDictionary *dict=[options objectForKey:option];

		[optiondescription print];

		for(int i=[optiondescription length];i<columnwidth1;i++)
		[@" " print];

		NSArray *lines=[[dict objectForKey:DescriptionKey] linesWrappedToWidth:columnwidth2];

		int numlines=[lines count];
		for(int i=0;i<numlines;i++)
		{
			if(i!=0) for(int j=0;j<columnwidth1;j++) [@" " print];
			[[lines objectAtIndex:i] print];
			[@"\n" print];
		}
	}

	[usagefooter print];
}



-(NSString *)stringValueForOption:(NSString *)option
{
	return [[options objectForKey:option] objectForKey:StringValueKey];
}

-(NSArray *)stringArrayValueForOption:(NSString *)option
{
	return [[options objectForKey:option] objectForKey:ArrayValueKey];
}

-(int)intValueForOption:(NSString *)option
{
	return [[[options objectForKey:option] objectForKey:NumberValueKey] intValue];
}

-(float)floatValueForOption:(NSString *)option
{
	return [[[options objectForKey:option] objectForKey:NumberValueKey] floatValue];
}

-(double)doubleValueForOption:(NSString *)option
{
	return [[[options objectForKey:option] objectForKey:NumberValueKey] doubleValue];
}

-(BOOL)boolValueForOption:(NSString *)option
{
	return [[[options objectForKey:option] objectForKey:NumberValueKey] boolValue];
}




-(NSArray *)remainingArguments
{
	return remainingargumentarray;
}




-(void)_assertOptionNameIsUnique:(NSString *)option
{
	if([options objectForKey:option])
	[NSException raise:NSInvalidArgumentException format:@"Attempted to add duplicate option \"%@\".",option];
}

-(void)_raiseUnknownOption:(NSString *)option
{
	[NSException raise:NSInvalidArgumentException format:@"Unknown option \"%@\".",option];
}

@end
