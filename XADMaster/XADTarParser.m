// Parses tar files, except: Star, sparse tar files.

#import "XADTarParser.h"

#define TAR_FORMAT_V7 0
#define TAR_FORMAT_GNU 1 // GNU and OLDGNU are basically identical
#define TAR_FORMAT_USTAR 2 // POSIX-ish tar formats
#define TAR_FORMAT_STAR 3 // STAR is POSIX-ish, but not similiar enough to ustar and posix.2001 tar.
#define TAR_FORMAT_V7_RECOGNIZED 4

// TODO: star.

@implementation XADTarParser

+(int)requiredHeaderSize { return 512; }

+(int)getTarType:(NSData *)header
{
	unsigned char head[512];
	[header getBytes:head length:512];

	int tarFormat = TAR_FORMAT_V7;
	unsigned char magic[8];
	[header getBytes:magic range:NSMakeRange(257,8)]; // "ustar\000" (ustar) / "ustar  \0" (gnu)
	
	unsigned char starExtendedMagic[4];
	[header getBytes:starExtendedMagic range:NSMakeRange(508,4)]; // "tar\0"
	
	unsigned int checksum = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(148,8) buffer:header];
	if( [XADTarParser isTarChecksumCorrect:header checksum:checksum] == YES )
	{
		tarFormat = TAR_FORMAT_V7_RECOGNIZED;
	}

	if( memcmp( magic, (unsigned char[]){ 117, 115, 116, 97, 114, 0, 48, 48 }, 8 ) == 0 )
	{
		if( memcmp( starExtendedMagic, (unsigned char[]){ 116, 97, 114, 0 }, 4 ) == 0 )
		{
			tarFormat = TAR_FORMAT_STAR;
		}
		else
		{
// 			printf("TAR: Ustar format.\n" );
			tarFormat = TAR_FORMAT_USTAR;
		}
	}
	else if( memcmp( magic, (unsigned char[]){ 117, 115, 116, 97, 114, 32, 32, 0 }, 8 ) == 0 )
	{
		tarFormat = TAR_FORMAT_GNU;
	}

	return( tarFormat );
}

// Recognize files by name or magic. (tar v7 files have no magic, are recognized as
// TAR_FORMAT_V7_RECOGNIZED via checksums)
+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name
{
	if([data length]<512) return NO;
	return(
		[name matchedByPattern:@"^(.*)\\.tar$" options:REG_ICASE] ||
		([XADTarParser getTarType:data] != TAR_FORMAT_V7)
	);
}

+(double)doubleFromCString:(char *)buffer
{
	NSString *readString = [[NSString alloc] initWithUTF8String:buffer];
	NSScanner* scanner = [NSScanner scannerWithString:readString];
	[readString release];
	double returnValue;
	if([scanner scanDouble:&returnValue] == YES) {
		return( returnValue );
	}
	return( 0 );
}

+(int64_t)longFromCString:(char *)buffer
{
	NSString *readString = [[NSString alloc] initWithUTF8String:buffer];
	NSScanner* scanner = [NSScanner scannerWithString:readString];
	[readString release];
	long long returnValue;
	if([scanner scanLongLong:&returnValue] == YES) {
		return( returnValue );
	}
	return( 0 );
}

+(int64_t)readNumberInRangeFromBuffer:(NSRange)range buffer:(NSData *)buffer
{
	NSString *readString = [[NSString alloc] initWithData:[buffer subdataWithRange:range] encoding:NSASCIIStringEncoding];
	NSScanner* scanner = [NSScanner scannerWithString:readString];
	[readString release];
	long long returnValue;
	if([scanner scanLongLong:&returnValue] == YES) {
		return( returnValue );
	}
	return( 0 );
}

+(int64_t)octalToDecimal:(int64_t)octal
{
	int64_t decimal = 0;
	int temp = 0;
	int64_t power_of_ten = 10000000000000;
	int64_t power_of_eight = 549755813888;
	while( power_of_ten != 1 )
	{
		power_of_ten = power_of_ten / 10;
		power_of_eight = power_of_eight / 8;
		temp = octal / power_of_ten;
		decimal += temp * power_of_eight;
		octal -= temp * power_of_ten;
	}
	return( decimal );
}

+(uint64_t)readOctalNumberInRangeFromBuffer:(NSRange)range buffer:(NSData *)buffer
{
	// This implementation only supports numbers up to 2^64. If we ever need bigger numbers,
	// that needs to change.
	// Also, negative values are not supported. This could be an issue if the mtime field was
	// supposed to be negative, but it is probably fair to assume that we will not be
	// extracting star archives with files last modified before 1970.
	uint8_t num_string[8];
	uint8_t mask = 0x80;
	[buffer getBytes:num_string range:NSMakeRange(range.location,8)];
	if( (num_string[0]&mask) == 0x80 ) {
		[buffer getBytes:num_string range:NSMakeRange(range.location + range.length - 8,8)];
		return CSUInt64BE(num_string);
	}
	return( [XADTarParser octalToDecimal:[XADTarParser readNumberInRangeFromBuffer:range buffer:buffer]] );
}

// "Sum of all header bytes if the checksum field was 8 * ' '".
+(BOOL)isTarChecksumCorrect:(NSData *)header checksum:(int)checksum
{
	unsigned char head[512];
	[header getBytes:head length:512];

	int signedChecksum = 0;
	unsigned int unsignedChecksum = 0;
	for( int i = 0; i < 148; i++ )
	{
		signedChecksum += (signed char)head[i];
		unsignedChecksum += (unsigned char)head[i];
	}

	for( int i = 156; i < 512; i++ )
	{
		signedChecksum += (signed char)head[i];
		unsignedChecksum += (unsigned char)head[i];
	}

	signedChecksum += 8 * ' ';
	unsignedChecksum += 8 * ' ';

	return( checksum == signedChecksum || checksum == unsignedChecksum );
}

-(void)dealloc
{
	[currentGlobalHeader release];
	[super dealloc];
}

-(void)parseSparseHeadersFromData:(NSData*)header numHeaders:(int)num toDict:(NSMutableDictionary *)dict
{
	for( int i = 0; i < num; i++ )
	{
		
		off_t regionOffset = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(24*i,12) buffer:header];
		off_t regionLength = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(24*i+12,12) buffer:header];

		// printf( "Parse sparse header: %d -> %d\n", regionOffset, regionLength );

		// Are we done yet?
		if( regionLength == 0 && regionOffset == 0 ) {
			break;
		}

		[[dict objectForKey:@"TARSparseRegionOffsets"] addObject:[NSNumber numberWithInt:regionOffset]];
		[[dict objectForKey:@"TARSparseRegionLengths"] addObject:[NSNumber numberWithInt:regionLength]];
	}
}

-(int)parseGenericTarHeader:(NSData *)header toDict:(NSMutableDictionary *)dict
{
	char name[101];
	[header getBytes:name range:NSMakeRange(0,100)];
	name[100] = '\000';
	[dict setObject:[self XADPathWithCString:name separators:XADUnixPathSeparator] forKey:XADFileNameKey];
	
	unsigned int mode = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(100,8) buffer:header];
	[dict setObject:[NSNumber numberWithInt:mode] forKey:XADPosixPermissionsKey];

	unsigned int uid = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(108,8) buffer:header];
	[dict setObject:[NSNumber numberWithInt:uid] forKey:XADPosixUserKey];

	unsigned int gid = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(116,8) buffer:header];
	[dict setObject:[NSNumber numberWithInt:gid] forKey:XADPosixGroupKey];

	uint64_t size = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(124,12) buffer:header];
	
	[dict setObject:[NSNumber numberWithLongLong:size] forKey:XADFileSizeKey];
	[dict setObject:[NSNumber numberWithLongLong:(size+(512-size%512))] forKey:XADCompressedSizeKey];
	[dict setObject:[NSNumber numberWithLongLong:size] forKey:XADDataLengthKey];

	unsigned long mtime = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(136,12) buffer:header];
	[dict setObject:[NSDate dateWithTimeIntervalSince1970:mtime] forKey:XADLastModificationDateKey];

	unsigned int checksum = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(148,8) buffer:header];
	if( [XADTarParser isTarChecksumCorrect:header checksum:checksum] == NO )
	{
		[XADException raiseIllegalDataException];
	}

	char typeFlag;
	[header getBytes:&typeFlag range:NSMakeRange(156,1)];
	
	// There are only two type flags that tar, in general, supports.	
	// "Directory"
	if( typeFlag == '5' )
	{
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
	}

	// "Hard link / soft link"
	if( typeFlag == '1' || typeFlag == '2' )
	{
		char linkName[101];
		[header getBytes:linkName range:NSMakeRange(157,100)];
		linkName[100] = '\000';
		[dict setObject:[self XADStringWithCString:linkName] forKey:XADLinkDestinationKey];
		[dict setObject:[NSNumber numberWithInt:(typeFlag%2)] forKey:XADIsHardLinkKey];
	}

	// KLUDGE: Fix broken directory typeflags.
	if( typeFlag == 0 && name[strlen(name)-1] == '/' ) {
		[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsDirectoryKey];
	}

	// KLUDGE: Fix broken ant tar wrong magic files.
	if( strncmp( name, "././@LongLink", 13 ) == 0 ) {
		return( 1 );
	}

// 	printf( "Generictar: Name %s / %u\n", name, size );

	return( 0 );
}

-(void)parsePaxTarHeader:(NSData *)header toDict:(NSMutableDictionary *)dict {
	int position = 0;
	while( position < [header length] ) {
		// Get next pair length.
		int start_pos = position;
		int read_length = 0;
		char current_char = '\0';
		while( current_char != ' ' && read_length < 16 && position < [header length] ) {
			[header getBytes:&current_char range:NSMakeRange(position,1)];
			position++;
			read_length++;
		}
		if( read_length == 0 ){
			break;
		}

		// Grab the pair from the header.
		int next_pair_size = [XADTarParser readNumberInRangeFromBuffer:NSMakeRange(start_pos,read_length) buffer:header] - read_length;
		int next_pair_offset = position + next_pair_size;
		char key_val_pair[next_pair_size];
		memset( key_val_pair, '\0', next_pair_size );
		[header getBytes:key_val_pair range:NSMakeRange(position,next_pair_size - 1)];

		// Parse the pair into key/value.
		read_length = 0;
		start_pos = position;
		int max_len = strlen( key_val_pair );
		while( key_val_pair[read_length] != '=' && read_length < max_len ) {
			position++;
			read_length++;
		}
		char key[read_length + 1];
		memcpy( key, key_val_pair, read_length );
		key[read_length] = '\0';
		char value[max_len - read_length + 1];
		memcpy( value, key_val_pair + read_length + 1, (max_len - read_length) );
		value[(max_len - read_length)] = '\0';		

		// Check keys and add proper value to dict.
		// Accessed/Created/Last Modified
		if( strcmp( key, "atime" ) == 0 ) {
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[XADTarParser doubleFromCString:value]] forKey:XADLastAccessDateKey];
		}
		else if( strcmp( key, "ctime" ) == 0 ) {
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[XADTarParser doubleFromCString:value]] forKey:XADCreationDateKey];
		}
		else if( strcmp( key, "mtime" ) == 0 ) {
			[dict setObject:[NSDate dateWithTimeIntervalSince1970:[XADTarParser doubleFromCString:value]] forKey:XADLastModificationDateKey];
		}

		// User/Group ids/names.
		else if( strcmp( key, "uname" ) == 0 ) {
			[dict setObject:[self XADStringWithCString:value encodingName:XADUTF8StringEncodingName] forKey:XADPosixUserNameKey];
		}
		else if( strcmp( key, "gname" ) == 0 ) {
			[dict setObject:[self XADStringWithCString:value encodingName:XADUTF8StringEncodingName] forKey:XADPosixGroupNameKey];
		}
		else if( strcmp( key, "uid" ) == 0 ) {
			[dict setObject:[NSNumber numberWithInt:[XADTarParser longFromCString:value]] forKey:XADPosixUserKey];
		}
		else if( strcmp( key, "gid" ) == 0 ) {
			[dict setObject:[NSNumber numberWithInt:[XADTarParser longFromCString:value]] forKey:XADPosixGroupKey];
		}
		
		// File path and link path.
		else if( strcmp( key, "path" ) == 0 ) {
			[dict setObject:[self XADPathWithCString:value encodingName:XADUTF8StringEncodingName separators:XADUnixPathSeparator] forKey:XADFileNameKey];
		}
		else if( strcmp( key, "linkpath" ) == 0 ) {
			[dict setObject:[self XADStringWithCString:value encodingName:XADUTF8StringEncodingName] forKey:XADLinkDestinationKey];
		}

		// File size.
		else if( strcmp( key, "size" ) == 0 ) {
			[dict setObject:[NSNumber numberWithInt:[XADTarParser longFromCString:value]] forKey:XADFileSizeKey];
		}

		// Comment.
		else if( strcmp( key, "comment" ) == 0 ) {
			[dict setObject:[self XADStringWithCString:value encodingName:XADUTF8StringEncodingName] forKey:XADCommentKey];
		}

		// Continue after the pair.

		position = next_pair_offset;
	}
}

-(void)parseUstarTarHeader:(NSData *)header toDict:(NSMutableDictionary *)dict
{
	char userName[33];
	[header getBytes:userName range:NSMakeRange(265,32)];
	userName[32] = '\000';
	[dict setObject:[self XADStringWithCString:userName] forKey:XADPosixUserNameKey];

	char groupName[33];
	[header getBytes:groupName range:NSMakeRange(297,32)];
	groupName[32] = '\000';
	[dict setObject:[self XADStringWithCString:groupName] forKey:XADPosixGroupNameKey];
	
	unsigned int devMajor = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(329,8) buffer:header];

	unsigned int devMinor = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(337,8) buffer:header];

	char prefix[156];
	[header getBytes:prefix range:NSMakeRange(345,155)];
	prefix[155] = '\000';

	// Prefix is not null => name is prefix . name
	char fullName[257];
	if( !(prefix[0] == '\000') ) {
		char name[101];
		[header getBytes:name range:NSMakeRange(0,100)];
		name[100] = '\000';
		fullName[0] = '\000';
		strcat( fullName, prefix );
		strcat( fullName, "/" );
		strcat( fullName, name );
		fullName[256] = '\000';
		[dict setObject:[self XADPathWithCString:fullName separators:XADUnixPathSeparator] forKey:XADFileNameKey];
	}

	char typeFlag;
	[header getBytes:&typeFlag range:NSMakeRange(156,1)];

	// Global header parse.
	[self parsePaxTarHeader:currentGlobalHeader toDict:dict];

// 	printf( "Ustar header parse after global\n" );

	// Needed later for extended headers, possibly.
	CSHandle *handle = [self handle];
	long size = [[dict objectForKey:XADDataLengthKey] longValue];
	off_t offset = [handle offsetInFile];;
	offset += size;
	offset += (offset % 512 == 0 ? 0 : 512 - (offset % 512) );

	switch( typeFlag ) {
		// Device files
		case '3':
			[dict setObject:[NSNumber numberWithInt:1] forKey:XADIsCharacterDeviceKey];
			[dict setObject:[NSNumber numberWithInt:devMajor] forKey:XADDeviceMajorKey];
			[dict setObject:[NSNumber numberWithInt:devMinor] forKey:XADDeviceMinorKey];
		break;
		case '4':
			[dict setObject:[NSNumber numberWithInt:1] forKey:XADIsBlockDeviceKey];
			[dict setObject:[NSNumber numberWithInt:devMajor] forKey:XADDeviceMajorKey];
			[dict setObject:[NSNumber numberWithInt:devMinor] forKey:XADDeviceMinorKey];
		break;

		// FIFOs
		case '6':
			[dict setObject:[NSNumber numberWithInt:1] forKey:XADIsFIFOKey];
		break;

		// POSIX.2001 global header.
		case 'g': {
			// Read in the header and store for parsing
			[currentGlobalHeader release];
			currentGlobalHeader = [[handle readDataOfLength:size] retain];
			[handle seekToFileOffset:offset];

			// Parse next header.
			NSData *header = [handle readDataOfLength:512];
			[dict removeAllObjects];
			[self parseGenericTarHeader:header toDict:dict];
			[self parseUstarTarHeader:header toDict:dict];
		} break;

		// POSIX.2001 extended header.
		case 'x': {
			// Read in the header.
			NSData *extendedHeader = [handle readDataOfLength:size];
			[handle seekToFileOffset:offset];

			// Prepare a new dictionary with the next header.
			NSData *header = [handle readDataOfLength:512];
			[dict removeAllObjects];
			[self parseGenericTarHeader:header toDict:dict];
			[self parseUstarTarHeader:header toDict:dict];

			// Parse extended header.
			[self parsePaxTarHeader:extendedHeader toDict:dict];
		} break;
	}
}

-(void)parseGnuTarHeader:(NSData *)header toDict:(NSMutableDictionary *)dict
{
	char typeFlag;
	[header getBytes:&typeFlag range:NSMakeRange(156,1)];

	// In case of LongName / LongLink, we need the data.
	CSHandle *handle = [self handle];
	long size = [[dict objectForKey:XADDataLengthKey] longValue];
	off_t offset = [handle offsetInFile];
	offset += size;
	offset += (offset % 512 == 0 ? 0 : 512 - (offset % 512) );

	// LongName or LongLink?
	if( typeFlag == 'L' || typeFlag == 'K' ) {
		// Read in the header
		NSData *longHeader = [handle readDataOfLength:size];
		[handle seekToFileOffset:offset];

		// Check if there is a terminating null byte, and eliminate it.
		int length=[longHeader length];
		const uint8_t *bytes=[longHeader bytes];
		if(length>0 && bytes[length-1]==0) longHeader=[longHeader subdataWithRange:NSMakeRange(0,length-1)];
		
		// Prepare a new dictionary with the next header.
		NSData *header = [handle readDataOfLength:512];
		[dict removeAllObjects];
		[self parseGenericTarHeader:header toDict:dict];
		[self parseGnuTarHeader:header toDict:dict];

		// Set the proper key.
		if( typeFlag == 'L' ) {
			[dict setObject:[self XADPathWithData:longHeader separators:XADUnixPathSeparator] forKey:XADFileNameKey];
		}
		else {
			[dict setObject:[self XADStringWithData:longHeader] forKey:XADLinkDestinationKey];
		}
	}

	// Sparse header?
	if( typeFlag == 'S' ) {
		// For now, pass out a "Not supported".
		
// 		// Get and store real size.
// 		off_t size = [XADTarParser readOctalNumberInRangeFromBuffer:NSMakeRange(483,12) buffer:header];
// 		[dict setObject:[NSNumber numberWithLongLong:size] forKey:XADFileSizeKey];
// 		[dict setObject:[NSNumber numberWithLongLong:size] forKey:XADDataLengthKey];
// 
// 		// Set up sparse map storage.
		[dict setObject:[NSNumber numberWithBool:YES] forKey:@"TARIsSparseFile"];
// 		[dict setObject:[[NSMutableArray alloc] init] forKey:@"TARSparseRegionOffsets"];
// 		[dict setObject:[[NSMutableArray alloc] init] forKey:@"TARSparseRegionLengths"];
// 		
// 		NSData* sparseMap = [header subdataWithRange:NSMakeRange(386,96)];
// 		[self parseSparseHeadersFromData:sparseMap numHeaders:4 toDict:dict];
// 
// 		// Handle extended sparse headers.
// 		char hasExtended;
// 		[header getBytes:&hasExtended range:NSMakeRange(482,1)];
// 		printf( "Hasx: %d\n", hasExtended );
// 		while( hasExtended == 1 ) {
// 			NSData *sparseMap = [handle readDataOfLength:512];
// 			[self parseSparseHeadersFromData:sparseMap numHeaders:21 toDict:dict];
// 			[sparseMap getBytes:&hasExtended range:NSMakeRange(504,1)];
// 		}
	}
}

-(void)addTarEntryWithDictionaryAndSeek:(NSMutableDictionary *)dict
{
	CSHandle *handle = [self handle];
	off_t size = [[dict objectForKey:XADDataLengthKey] longLongValue];
	off_t offset = [handle offsetInFile];
	[dict setObject:[NSNumber numberWithLong:offset] forKey:XADDataOffsetKey];
	[self addEntryWithDictionary:dict];
	offset += size;
	offset += (offset % 512 == 0 ? 0 : 512 - (offset % 512) );
	[handle seekToFileOffset:offset];
}

-(void)parseWithSeparateMacForks
{
	// Reset global current header for posix.2001;
	currentGlobalHeader = [NSData new];
	
	CSHandle *handle = [self handle];
	int tarFormat = -1;

	while([self shouldKeepParsing])
	{
		NSAutoreleasePool *pool = [NSAutoreleasePool new];

		// Read next header.
		if([handle atEndOfFile]) break;
		NSData *header = [handle readDataOfLength:512];

		// Figure out format if we haven't yet done so.
		if( tarFormat == -1 ) tarFormat = [XADTarParser getTarType:header];
		
		// See if there are 512 nullbytes. That means the file is over.
		const char *firstBytes = [header bytes];
		BOOL isArchiverOver = YES;
		for( int i = 0; i < 512; i++ ) {		
			if( firstBytes[i] != '\000' ) {
				isArchiverOver = NO;
			}
		}
		if( isArchiverOver )
		{
			[pool release];
			break;
		}

		NSMutableDictionary *dict = [NSMutableDictionary dictionary];

		// Reset sparseity.
		[dict setObject:[NSNumber numberWithBool:NO] forKey:@"TARIsSparseFile"];

		int wrongFormat = [self parseGenericTarHeader:header toDict:dict];
		if( wrongFormat == 1 ) {
			tarFormat = TAR_FORMAT_GNU;
		}

		if( tarFormat == TAR_FORMAT_V7 || tarFormat == TAR_FORMAT_V7_RECOGNIZED ) {
			[self addTarEntryWithDictionaryAndSeek:dict];
		}
		else if( tarFormat == TAR_FORMAT_USTAR )
		{
			[self parseUstarTarHeader:header toDict:dict];
			[self addTarEntryWithDictionaryAndSeek:dict];
		}
		else if( tarFormat == TAR_FORMAT_GNU )
		{
			[self parseGnuTarHeader:header toDict:dict];
			[self addTarEntryWithDictionaryAndSeek:dict];
		}
		else
		{
			// Handled like an ustar archive.
			[self parseUstarTarHeader:header toDict:dict];
			[self addTarEntryWithDictionaryAndSeek:dict];
		}

		[pool release];
	}
}

-(CSHandle *)rawHandleForEntryWithDictionary:(NSDictionary *)dict wantChecksum:(BOOL)checksum
{
	CSHandle* retHandle = [self handleAtDataOffsetForDictionary:dict];
	if( [[dict objectForKey:@"TARIsSparseFile"] boolValue] ) {
		// Just return nil.
		return( nil );
	
// 		XADTarSparseHandle* sparseHandle = [[XADTarSparseHandle alloc] initWithHandle:retHandle size:[[dict objectForKey:XADDataLengthKey] longValue]];
// 		NSArray* offsets = [dict objectForKey:@"TARSparseRegionOffsets"];	
// 		NSArray* lengths = [dict objectForKey:@"TARSparseRegionLengths"];
// 		int sparseRegionCount = [offsets count];
// 		for( int i = 0; i < sparseRegionCount; i++ ) {
// 			// GNU tar is pretty special about some things.
// 			if( [[lengths objectAtIndex:i] longValue] == 0 )
// 			{
// 				// The final region is also the first - special case!
// 				if( i == 0 )
// 				{
// 					printf( "Final region add (not really)!\n" );
// 					[sparseHandle setSingleEmptySparseRegion];
// 				}
// 				else
// 				{
// 					printf( "Final region add!\n" );
// 					[sparseHandle addFinalSparseRegionEndingAt:[[offsets objectAtIndex:i] longValue]];
// 				}
// 			}
// 			else
// 			{
// 				printf( "Normal region add!\n" );
// 				[sparseHandle addSparseRegionFrom:[[offsets objectAtIndex:i] longValue] length:[[lengths objectAtIndex:i] longValue]];
// 			}
// 		}
// 		return( sparseHandle );
	}
//	printf( "Handle return" );
	return( retHandle );
}
// This should maybe return USTAR or POSIX Tar or whatever the proper tar type is.
-(NSString *)formatName { return @"Tar"; }

@end
