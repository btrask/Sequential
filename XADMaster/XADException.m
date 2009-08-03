#import "XADException.h"

NSString *XADExceptionName=@"XADException";

@implementation XADException

+(void)raiseUnknownException  { [self raiseExceptionWithXADError:XADUnknownError]; }
+(void)raiseIllegalDataException  { [self raiseExceptionWithXADError:XADIllegalDataError]; }
+(void)raiseNotSupportedException  { [self raiseExceptionWithXADError:XADNotSupportedError]; }
+(void)raisePasswordException { [self raiseExceptionWithXADError:XADPasswordError]; }
+(void)raiseDecrunchException { [self raiseExceptionWithXADError:XADDecrunchError]; }
+(void)raiseChecksumException { [self raiseExceptionWithXADError:XADChecksumError]; }
+(void)raiseDataFormatException { [self raiseExceptionWithXADError:XADDataFormatError]; }

+(void)raiseExceptionWithXADError:(XADError)errnum
{
//	[NSException raise:@"XADException" format:@"%@",[self describeXADError:errnum]];
	[[[[NSException alloc] initWithName:XADExceptionName reason:[self describeXADError:errnum]
	userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:errnum]
	forKey:@"XADError"]] autorelease] raise];
}

+(NSString *)describeXADError:(XADError)error
{
	switch(error)
	{
		case XADNoError:			return nil;
		case XADUnknownError:		return @"Unknown error";
		case XADInputError:			return @"Input data buffers border exceeded";
		case XADOutputError:		return @"Output data buffers border exceeded";
		case XADBadParametersError:	return @"Function called with illegal parameters";
		case XADOutOfMemoryError:	return @"Not enough memory available";
		case XADIllegalDataError:	return @"Data is corrupted";
		case XADNotSupportedError:	return @"Command is not supported";
		case XADResourceError:		return @"Required resource missing";
		case XADDecrunchError:		return @"Error on decrunching";
		case XADFiletypeError:		return @"Unknown file type";
		case XADOpenFileError:		return @"Opening file failed";
		case XADSkipError:			return @"File, disk has been skipped";
		case XADBreakError:			return @"User break in progress hook";
		case XADFileExistsError:	return @"File already exists";
		case XADPasswordError:		return @"Missing or wrong password";
		case XADMakeDirectoryError:	return @"Could not create directory";
		case XADChecksumError:		return @"Wrong checksum";
		case XADVerifyError:		return @"Verify failed (disk hook)";
		case XADGeometryError:		return @"Wrong drive geometry";
		case XADDataFormatError:	return @"Unknown data format";
		case XADEmptyError:			return @"Source contains no files";
		case XADFileSystemError:	return @"Unknown filesystem";
		case XADFileDirectoryError:	return @"Name of file exists as directory";
		case XADShortBufferError:	return @"Buffer was too short";
		case XADEncodingError:		return @"Text encoding was defective";
	}
	return nil;
}

-(XADError)error { return error; }

@end
