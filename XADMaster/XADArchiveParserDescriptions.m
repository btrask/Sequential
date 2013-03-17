#import "XADArchiveParserDescriptions.h"
#import "XADRegex.h"

@implementation XADArchiveParser (Descriptions)

-(NSString *)descriptionOfValueInDictionary:(NSDictionary *)dict key:(NSString *)key
{
	id object=[dict objectForKey:key];
	if(!object) return nil;

	if([key matchedByPattern:@"CRC32$"])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return [NSString stringWithFormat:@"0x%08llx",[object longLongValue]];
	}
	else if([key matchedByPattern:@"CRC16$"])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return [NSString stringWithFormat:@"0x%04llx",[object longLongValue]];
	}
	else if([key matchedByPattern:@"Is[A-Z0-9]"])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return XADHumanReadableBoolean([object longLongValue]);
	}
	else if([key isEqual:XADFileSizeKey]||[key isEqual:XADCompressedSizeKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return XADHumanReadableFileSize([object longLongValue]);
	}
	else if([key isEqual:XADPosixPermissionsKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return XADHumanReadablePOSIXPermissions([object longLongValue]);
	}
	else if([key isEqual:XADAmigaProtectionBitsKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return XADHumanReadableAmigaProtectionBits([object longLongValue]);
	}
	else if([key isEqual:XADDOSFileAttributesKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return XADHumanReadableDOSFileAttributes([object longLongValue]);
	}
	else if([key isEqual:XADWindowsFileAttributesKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return XADHumanReadableWindowsFileAttributes([object longLongValue]);
	}
	else if([key isEqual:XADFileTypeKey]||[key isEqual:XADFileCreatorKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return XADHumanReadableOSType([object longLongValue]);
	}
	else if([key isEqual:XADFinderFlagsKey])
	{
		if(![object isKindOfClass:[NSNumber class]]) return [object description];
		return [NSString stringWithFormat:@"0x%04llx",[object longLongValue]];
	}
	else
	{
		return XADHumanReadableObject(object);
	}
}

-(NSString *)descriptionOfKey:(NSString *)key
{
	static NSDictionary *descriptions=nil;
	if(!descriptions) descriptions=[[NSDictionary alloc] initWithObjectsAndKeys:
		NSLocalizedString(@"Comment",@""),XADCommentKey,
		NSLocalizedString(@"Name",@""),XADFileNameKey,
		NSLocalizedString(@"Size",@""),XADFileSizeKey,
		NSLocalizedString(@"Compressed size",@""),XADCompressedSizeKey,
		NSLocalizedString(@"Compression type",@""),XADCompressionNameKey,

		NSLocalizedString(@"Is a directory",@""),XADIsDirectoryKey,
		NSLocalizedString(@"Is a Mac OS resource fork",@""),XADIsResourceForkKey,
		NSLocalizedString(@"Is an archive",@""),XADIsArchiveKey,
		NSLocalizedString(@"Is hidden",@""),XADIsHiddenKey,
		NSLocalizedString(@"Is a link",@""),XADIsLinkKey,
		NSLocalizedString(@"Is a hard link",@""),XADIsHardLinkKey,
		NSLocalizedString(@"Link destination",@""),XADLinkDestinationKey,
		NSLocalizedString(@"Is a Unix character device",@""),XADIsCharacterDeviceKey,
		NSLocalizedString(@"Is a Unix block device",@""),XADIsBlockDeviceKey,
		NSLocalizedString(@"Unix major device number",@""),XADDeviceMajorKey,
		NSLocalizedString(@"Unix minor device number",@""),XADDeviceMinorKey,
		NSLocalizedString(@"Is a Unix FIFO",@""),XADIsFIFOKey,
		NSLocalizedString(@"Is encrypted",@""),XADIsEncryptedKey,
		NSLocalizedString(@"Is corrupted",@""),XADIsCorruptedKey,

		NSLocalizedString(@"Last modified",@""),XADLastModificationDateKey,
		NSLocalizedString(@"Last accessed",@""),XADLastAccessDateKey,
		NSLocalizedString(@"Last attribute change",@""),XADLastAttributeChangeDateKey,
		NSLocalizedString(@"Last backup",@""),XADLastBackupDateKey,
		NSLocalizedString(@"Created",@""),XADCreationDateKey,

		NSLocalizedString(@"Extended attributes",@""),XADExtendedAttributesKey,
		NSLocalizedString(@"Mac OS type code",@""),XADFileTypeKey,
		NSLocalizedString(@"Mac OS creator code",@""),XADFileCreatorKey,
		NSLocalizedString(@"Mac OS Finder flags",@""),XADFinderFlagsKey,
		NSLocalizedString(@"Mac OS Finder info",@""),XADFinderInfoKey,
		NSLocalizedString(@"Unix permissions",@""),XADPosixPermissionsKey,
		NSLocalizedString(@"Unix user number",@""),XADPosixUserKey,
		NSLocalizedString(@"Unix group number",@""),XADPosixGroupKey,
		NSLocalizedString(@"Unix user name",@""),XADPosixUserNameKey,
		NSLocalizedString(@"Unix group name",@""),XADPosixGroupNameKey,
		NSLocalizedString(@"DOS file attributes",@""),XADDOSFileAttributesKey,
		NSLocalizedString(@"Windows file attributes",@""),XADWindowsFileAttributesKey,
		NSLocalizedString(@"Amiga protection bits",@""),XADAmigaProtectionBitsKey,

		NSLocalizedString(@"Index in file",@""),XADIndexKey,
		NSLocalizedString(@"Start of data",@""),XADDataOffsetKey,
		NSLocalizedString(@"Length of data",@""),XADDataLengthKey,
		NSLocalizedString(@"Start of data (minus skips)",@""),XADSkipOffsetKey,
		NSLocalizedString(@"Length of data (minus skips)",@""),XADSkipLengthKey,

		NSLocalizedString(@"Is a solid archive file",@""),XADIsSolidKey,
		NSLocalizedString(@"Index of first solid file",@""),XADFirstSolidIndexKey,
		NSLocalizedString(@"Pointer to first solid file",@""),XADFirstSolidEntryKey,
		NSLocalizedString(@"Index of next solid file",@""),XADNextSolidIndexKey,
		NSLocalizedString(@"Pointer to next solid file",@""),XADNextSolidEntryKey,
		NSLocalizedString(@"Internal solid identifier",@""),XADSolidObjectKey,
		NSLocalizedString(@"Start of data in solid stream",@""),XADSolidOffsetKey,
		NSLocalizedString(@"Length of data in solid stream",@""),XADSolidLengthKey,

		NSLocalizedString(@"Archive name",@""),XADArchiveNameKey,
		NSLocalizedString(@"Archive volumes",@""),XADVolumesKey,
		NSLocalizedString(@"Disk label",@""),XADDiskLabelKey,
		nil];

	NSString *description=[descriptions objectForKey:key];
	if(description) return description;

	return key;
}

static NSInteger OrderKeys(id first,id second,void *context);

-(NSArray *)descriptiveOrderingOfKeysInDictionary:(NSDictionary *)dict
{
	static NSDictionary *ordering=nil;
	if(!ordering) ordering=[[NSDictionary alloc] initWithObjectsAndKeys:
		[NSNumber numberWithInt:100],XADFileNameKey,
		[NSNumber numberWithInt:101],XADCommentKey,
		[NSNumber numberWithInt:102],XADFileSizeKey,
		[NSNumber numberWithInt:103],XADCompressedSizeKey,
		[NSNumber numberWithInt:104],XADCompressionNameKey,

		[NSNumber numberWithInt:200],XADIsDirectoryKey,
		[NSNumber numberWithInt:201],XADIsResourceForkKey,
		[NSNumber numberWithInt:202],XADIsArchiveKey,
		[NSNumber numberWithInt:203],XADIsHiddenKey,
		[NSNumber numberWithInt:204],XADIsLinkKey,
		[NSNumber numberWithInt:205],XADIsHardLinkKey,
		[NSNumber numberWithInt:206],XADLinkDestinationKey,
		[NSNumber numberWithInt:207],XADIsCharacterDeviceKey,
		[NSNumber numberWithInt:208],XADIsBlockDeviceKey,
		[NSNumber numberWithInt:209],XADDeviceMajorKey,
		[NSNumber numberWithInt:210],XADDeviceMinorKey,
		[NSNumber numberWithInt:211],XADIsFIFOKey,
		[NSNumber numberWithInt:212],XADIsEncryptedKey,
		[NSNumber numberWithInt:213],XADIsCorruptedKey,

		[NSNumber numberWithInt:300],XADLastModificationDateKey,
		[NSNumber numberWithInt:301],XADLastAccessDateKey,
		[NSNumber numberWithInt:302],XADLastAttributeChangeDateKey,
		[NSNumber numberWithInt:303],XADLastBackupDateKey,
		[NSNumber numberWithInt:304],XADCreationDateKey,

		[NSNumber numberWithInt:400],XADExtendedAttributesKey,
		[NSNumber numberWithInt:401],XADFileTypeKey,
		[NSNumber numberWithInt:402],XADFileCreatorKey,
		[NSNumber numberWithInt:403],XADFinderFlagsKey,
		[NSNumber numberWithInt:404],XADFinderInfoKey,
		[NSNumber numberWithInt:404],XADPosixPermissionsKey,
		[NSNumber numberWithInt:405],XADPosixUserKey,
		[NSNumber numberWithInt:406],XADPosixGroupKey,
		[NSNumber numberWithInt:407],XADPosixUserNameKey,
		[NSNumber numberWithInt:408],XADPosixGroupNameKey,
		[NSNumber numberWithInt:409],XADDOSFileAttributesKey,
		[NSNumber numberWithInt:410],XADWindowsFileAttributesKey,
		[NSNumber numberWithInt:411],XADAmigaProtectionBitsKey,

		[NSNumber numberWithInt:500],XADIndexKey,
		[NSNumber numberWithInt:501],XADDataOffsetKey,
		[NSNumber numberWithInt:502],XADDataLengthKey,
		[NSNumber numberWithInt:503],XADSkipOffsetKey,
		[NSNumber numberWithInt:504],XADSkipLengthKey,

		[NSNumber numberWithInt:600],XADIsSolidKey,
		[NSNumber numberWithInt:601],XADFirstSolidIndexKey,
		[NSNumber numberWithInt:602],XADFirstSolidEntryKey,
		[NSNumber numberWithInt:603],XADNextSolidIndexKey,
		[NSNumber numberWithInt:604],XADNextSolidEntryKey,
		[NSNumber numberWithInt:605],XADSolidObjectKey,
		[NSNumber numberWithInt:606],XADSolidOffsetKey,
		[NSNumber numberWithInt:607],XADSolidLengthKey,

		[NSNumber numberWithInt:700],XADArchiveNameKey,
		[NSNumber numberWithInt:701],XADVolumesKey,
		[NSNumber numberWithInt:702],XADDiskLabelKey,
		nil];

	return [[dict allKeys] sortedArrayUsingFunction:OrderKeys context:ordering];
}

static NSInteger OrderKeys(id first,id second,void *context)
{
	NSDictionary *ordering=context;
	NSNumber *firstorder=[ordering objectForKey:first];
	NSNumber *secondorder=[ordering objectForKey:second];

	if(firstorder&&secondorder) return [firstorder compare:secondorder];
	else if(firstorder) return NSOrderedAscending;
	else if(secondorder) return NSOrderedDescending;
	else return [first compare:second];
}

@end



static NSString *DottedNumber(uint64_t size);

NSString *XADHumanReadableFileSize(uint64_t size)
{
	if(size<1000) return [NSString localizedStringWithFormat:
	NSLocalizedString(@"%lld bytes",@"Format string for human-redable sizes <1000"),
	size];
	else return [NSString localizedStringWithFormat:
	NSLocalizedString(@"%@ (%@ bytes)",@"Format string for human-readable sizes >=1000"),
	XADShortHumanReadableFileSize(size),DottedNumber(size)];
}

NSString *XADShortHumanReadableFileSize(uint64_t size)
{
	if(size<1000)
	{
		return [NSString stringWithFormat:
		NSLocalizedString(@"%lld B",@"Format string for short sizes expressed in bytes"),
		size];
	}

	double value;
	NSString *unitformat;
	if(size<1000000)
	{
		value=size/1000.0;
		unitformat=NSLocalizedString(@"%@ KB",@"Format string for short sizes expressed in kilobytes");
	}
	else if(size<1000000000)
	{
		value=size/1000000.0;
		unitformat=NSLocalizedString(@"%@ MB",@"Format string for short sizes expressed in megabytes");
	}
	else
	{
		value=size/1000000000.0;
		unitformat=NSLocalizedString(@"%@ GB",@"Format string for short sizes expressed in gigabytes");
	}

	NSString *number;
	if(value<10) number=[NSString localizedStringWithFormat:@"%.2f",value];
	else if(value<100) number=[NSString localizedStringWithFormat:@"%.1f",value];
	else number=[NSString localizedStringWithFormat:@"%.0f",value];

	return [NSString stringWithFormat:unitformat,number];
}

static NSString *DottedNumber(uint64_t size)
{
	NSNumberFormatter *formatter=[[NSNumberFormatter new] autorelease];
	formatter.formatterBehavior=NSNumberFormatterBehavior10_4;
	formatter.numberStyle=NSNumberFormatterDecimalStyle;
	return [formatter stringFromNumber:[NSNumber numberWithLongLong:size]];
}

NSString *XADHumanReadableBoolean(uint64_t boolean)
{
	if(boolean==1) return NSLocalizedString(@"Yes",@"String for true values");
	else if (boolean==0) return NSLocalizedString(@"No",@"String for false values");
	else return [NSString stringWithFormat:@"%llx",boolean];
}

NSString *XADHumanReadablePOSIXPermissions(uint64_t permissions)
{
	char str[10]="rwxrwxrwx";
	for(int i=0;i<9;i++) if(!(permissions&(0400>>i))) str[i]='-';
	return [NSString stringWithFormat:@"%s (%llo)",str,permissions];
}

NSString *XADHumanReadableAmigaProtectionBits(uint64_t protection)
{
	char str[9]="hsparwed";
	for(int i=0;i<8;i++) if(!((protection^0x0f)&(0x80>>i))) str[i]='-';
	return [NSString stringWithFormat:@"%s (0x%02llx)",str,protection];
}

NSString *XADHumanReadableDOSFileAttributes(uint64_t attributes)
{
	char str[9]="ADVSHR";
	for(int i=0;i<6;i++) if(!(attributes&(0x20>>i))) str[i]='-';
	return [NSString stringWithFormat:@"%s (0x%02llx)",str,attributes];
}

NSString *XADHumanReadableWindowsFileAttributes(uint64_t attributes)
{
	char str[16]="EIOCLPTN AD SHR";
	for(int i=0;i<15;i++) if(!(attributes&(0x4000>>i))) str[i]='-';
	return [NSString stringWithFormat:@"%s (0x%04llx)",str,attributes];
}

NSString *XADHumanReadableOSType(uint64_t ostype)
{
	char str[5]={0};
	for(int i=0;i<4;i++)
	{
		uint8_t c=(ostype>>(24-i*8))&0xff;
		if(c>=32&&c<=127) str[i]=c;
		else str[i]='?';
	}
	return [NSString stringWithFormat:@"%s (0x%08llx)",str,ostype];

}

NSString *XADHumanReadableEntryWithDictionary(NSDictionary *dict,XADArchiveParser *parser)
{
	NSArray *keys=[parser descriptiveOrderingOfKeysInDictionary:dict];
	NSMutableArray *labels=[NSMutableArray array];
	NSMutableArray *values=[NSMutableArray array];

	NSEnumerator *enumerator=[keys objectEnumerator];
	NSString *key;
	while((key=[enumerator nextObject]))
	{
		NSString *label=[parser descriptionOfKey:key];
		NSString *value=[parser descriptionOfValueInDictionary:dict key:key];
		[labels addObject:label];
		[values addObject:value];
	}

	return XADHumanReadableList(labels,values);
}




#ifdef GNUSTEP
static NSString *GNUSTEPKludge_HumanReadableValue(NSValue *value);
#endif

NSString *XADHumanReadableObject(id object)
{
	if ([object isKindOfClass:[NSDate class]]) return XADHumanReadableDate(object);
	else if([object isKindOfClass:[NSData class]]) return XADHumanReadableData(object);
	else if([object isKindOfClass:[NSArray class]]) return XADHumanReadableArray(object);
	else if([object isKindOfClass:[NSDictionary class]]) return XADHumanReadableDictionary(object);
	#ifdef GNUSTEP
	else if([object isKindOfClass:[NSValue class]]) return GNUSTEPKludge_HumanReadableValue(object);
	#endif
	else return [object description];

}

NSString *XADHumanReadableDate(NSDate *date)
{
	#ifndef __COCOTRON__
	NSDateFormatter *formatter=[[NSDateFormatter new] autorelease];
	[formatter setFormatterBehavior:NSDateFormatterBehavior10_4];
	[formatter setDateStyle:NSDateFormatterFullStyle];
	[formatter setTimeStyle:NSDateFormatterMediumStyle];
	return [formatter stringForObjectValue:date];
	#else
	return [date description];
	#endif
}

NSString *XADHumanReadableData(NSData *data)
{
	NSMutableString *string=[NSMutableString string];

	NSInteger length=[data length];
	const uint8_t *bytes=[data bytes];

	[string appendFormat:
	NSLocalizedString(@"%llu bytes (",@"Format string for raw data objects"),
	(uint64_t)length];

	for(int i=0;i<length && i<256;i++)
	{
		if(i!=0 && (i&3)==0) [string appendString:@" "];
		[string appendFormat:@"%02x",bytes[i]];
	}

	if(length>256) [string appendString:@"..."];
	[string appendString:@")"];

	return string;
}

NSString *XADHumanReadableArray(NSArray *array)
{
	NSInteger count=[array count];
	NSMutableArray *labels=[NSMutableArray array];
	NSMutableArray *values=[NSMutableArray array];

	for(int i=0;i<count;i++)
	{
		id value=[array objectAtIndex:i];
		[labels addObject:[NSString stringWithFormat:@"%d",i]];
		[values addObject:XADHumanReadableObject(value)];
	}

	return XADHumanReadableList(labels,values);
}

NSString *XADHumanReadableDictionary(NSDictionary *dict)
{
	NSArray *keys=[[dict allKeys] sortedArrayUsingSelector:@selector(compare:)];
	NSMutableArray *labels=[NSMutableArray array];
	NSMutableArray *values=[NSMutableArray array];

	NSEnumerator *enumerator=[keys objectEnumerator];
	NSString *key;
	while((key=[enumerator nextObject]))
	{
		id value=[dict objectForKey:key];
		[labels addObject:key];
		[values addObject:XADHumanReadableObject(value)];
	}

	return XADHumanReadableList(labels,values);
}

NSString *XADHumanReadableList(NSArray *labels,NSArray *values)
{
	int maxlen=0;
	NSInteger count=[labels count];
	for(int i=0;i<count;i++)
	{
		NSString *label=[labels objectAtIndex:i];
		int len=[label length];

		if(len>maxlen) maxlen=len;
	}

	NSMutableString *string=[NSMutableString string];
	for(int i=0;i<count;i++)
	{
		NSString *label=[labels objectAtIndex:i];
		NSString *value=[values objectAtIndex:i];
		int len=[label length];

		[string appendString:label];
		[string appendString:@": "];

		for(int i=len;i<maxlen;i++) [string appendString:@" "];

		[string appendString:XADIndentTextWithSpaces(value,maxlen+2)];

		if(i!=count-1) [string appendString:@"\n"];
	}

	return string;
}

NSString *XADIndentTextWithSpaces(NSString *text,int spaces)
{
	if([text rangeOfString:@"\n"].location==NSNotFound) return text;

	char spacestring[spaces+2];
	spacestring[0]='\n';
	for(int i=0;i<spaces;i++) spacestring[i+1]=' ';
	spacestring[spaces+1]=0;

	NSString *indentstring=[NSString stringWithUTF8String:spacestring];

	return [text stringByReplacingOccurrencesOfString:@"\n" withString:indentstring];
}



#ifdef GNUSTEP
// GNUstep will dereference non-retained objects in NSValues. This is not safe, so avoid it.
static NSString *GNUSTEPKludge_HumanReadableValue(NSValue *value)
{
	if(strcmp([value objCType],@encode(id))==0)
	{
		return [NSString stringWithFormat:@"<%p>",[value nonretainedObjectValue]];
	}
	else
	{
		return [value description];
	}
}
#endif


