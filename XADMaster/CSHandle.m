#import "CSHandle.h"
#import "CSSubHandle.h"

#include <sys/stat.h>


NSString *CSOutOfMemoryException=@"CSOutOfMemoryException";
NSString *CSEndOfFileException=@"CSEndOfFileException";
NSString *CSNotImplementedException=@"CSNotImplementedException";
NSString *CSNotSupportedException=@"CSNotSupportedException";



@implementation CSHandle

-(id)initWithName:(NSString *)descname
{
	if(self=[super init])
	{
		name=[descname retain];

		bitoffs=-1;

		writebyte=0;
		writebitsleft=8;
	}
	return self;
}

-(id)initAsCopyOf:(CSHandle *)other
{
	if(self=[super init])
	{
		name=[[[other name] stringByAppendingString:@" (copy)"] retain];

		bitoffs=other->bitoffs;
		readbyte=other->readbyte;
		readbitsleft=other->readbitsleft;
		writebyte=other->writebyte;
		writebitsleft=other->writebitsleft;
	}
	return self;
}

-(void)dealloc
{
	[name release];
	[super dealloc];
}

-(void)close {}



//-(off_t)fileSize { [self _raiseNotImplemented:_cmd]; return 0; }
-(off_t)fileSize { return CSHandleMaxLength; }

-(off_t)offsetInFile { [self _raiseNotImplemented:_cmd]; return 0; }

-(BOOL)atEndOfFile { [self _raiseNotImplemented:_cmd]; return NO; }

-(void)seekToFileOffset:(off_t)offs { [self _raiseNotImplemented:_cmd]; }

-(void)seekToEndOfFile { [self _raiseNotImplemented:_cmd]; }

-(void)pushBackByte:(int)byte { [self _raiseNotImplemented:_cmd]; }

-(int)readAtMost:(int)num toBuffer:(void *)buffer { [self _raiseNotImplemented:_cmd]; return 0; }

-(void)writeBytes:(int)num fromBuffer:(const void *)buffer { [self _raiseNotImplemented:_cmd]; }




-(void)skipBytes:(off_t)bytes
{
	[self seekToFileOffset:[self offsetInFile]+bytes];
}

-(int8_t)readInt8;
{
	int8_t c;
	[self readBytes:1 toBuffer:&c];
	return c;
}

-(uint8_t)readUInt8
{
	uint8_t c;
	[self readBytes:1 toBuffer:&c];
	return c;
}

#define CSReadValueImpl(type,name,conv) \
-(type)name \
{ \
	uint8_t bytes[sizeof(type)]; \
	if([self readAtMost:sizeof(type) toBuffer:bytes]!=sizeof(type)) [self _raiseEOF]; \
	return conv(bytes); \
}

//CSReadValueImpl(int8_t,readInt8,(int8_t)*)
//CSReadValueImpl(uint8_t,readUInt8,(uint8_t)*)

CSReadValueImpl(int16_t,readInt16BE,CSInt16BE)
CSReadValueImpl(int32_t,readInt32BE,CSInt32BE)
CSReadValueImpl(int64_t,readInt64BE,CSInt64BE)
CSReadValueImpl(uint16_t,readUInt16BE,CSUInt16BE)
CSReadValueImpl(uint32_t,readUInt32BE,CSUInt32BE)
CSReadValueImpl(uint64_t,readUInt64BE,CSUInt64BE)

CSReadValueImpl(int16_t,readInt16LE,CSInt16LE)
CSReadValueImpl(int32_t,readInt32LE,CSInt32LE)
CSReadValueImpl(int64_t,readInt64LE,CSInt64LE)
CSReadValueImpl(uint16_t,readUInt16LE,CSUInt16LE)
CSReadValueImpl(uint32_t,readUInt32LE,CSUInt32LE)
CSReadValueImpl(uint64_t,readUInt64LE,CSUInt64LE)

CSReadValueImpl(uint32_t,readID,CSUInt32BE)

-(uint32_t)readBits:(int)bits
{
	int res=0,done=0;

	if([self offsetInFile]!=bitoffs) readbitsleft=0;
	while(done<bits)
	{
		if(!readbitsleft)
		{
			readbyte=[self readUInt8];
			bitoffs=[self offsetInFile];
			readbitsleft=8;
		}

		int num=bits-done;
		if(num>readbitsleft) num=readbitsleft;
		res=(res<<num)|((readbyte>>(readbitsleft-num))&((1<<num)-1));

		done+=num;
		readbitsleft-=num;
	}
	return res;
}

-(uint32_t)readBitsLE:(int)bits
{
	int res=0,done=0;

	if([self offsetInFile]!=bitoffs) readbitsleft=0;
	while(done<bits)
	{
		if(!readbitsleft)
		{
			readbyte=[self readUInt8];
			bitoffs=[self offsetInFile];
			readbitsleft=8;
		}

		int num=bits-done;
		if(num>readbitsleft) num=readbitsleft;
		res=res|(((readbyte>>(8-readbitsleft))&((1<<num)-1))<<done);

		done+=num;
		readbitsleft-=num;
	}
	return res;
}

-(int32_t)readSignedBits:(int)bits
{
	uint32_t res=[self readBits:bits];
//	return res|((res&(1<<(bits-1)))*0xffffffff);
	return -(res&(1<<(bits-1)))|res;
}

-(int32_t)readSignedBitsLE:(int)bits
{
	uint32_t res=[self readBitsLE:bits];
	return -(res&(1<<(bits-1)))|res;
}

-(void)flushReadBits { readbitsleft=0; }


-(NSData *)readLine
{
	int (*readatmost_ptr)(id,SEL,int,void *)=(void *)[self methodForSelector:@selector(readAtMost:toBuffer:)];

	NSMutableData *data=[NSMutableData data];
	for(;;)
	{
		uint8_t b[1];
		int actual=readatmost_ptr(self,@selector(readAtMost:toBuffer:),1,b);

		if(actual==0)
		{
			if([data length]==0) [self _raiseEOF];
			else break;
		}

		if(b[0]=='\n') break;

		[data appendBytes:b length:1];
	}

	const char *bytes=[data bytes];
	int length=[data length];
	if(length&&bytes[length-1]=='\r') [data setLength:length-1];

	return [NSData dataWithData:data];
}

-(NSString *)readLineWithEncoding:(NSStringEncoding)encoding
{
	return [[[NSString alloc] initWithData:[self readLine] encoding:encoding] autorelease];
}

-(NSString *)readUTF8Line
{
	return [[[NSString alloc] initWithData:[self readLine] encoding:NSUTF8StringEncoding] autorelease];
}



-(NSData *)fileContents
{
	[self seekToFileOffset:0];
	return [self remainingFileContents];
}

-(NSData *)remainingFileContents
{
	uint8_t buffer[16384];
	NSMutableData *data=[NSMutableData data];
	int actual;

	do
	{
		actual=[self readAtMost:sizeof(buffer) toBuffer:buffer];
		[data appendBytes:buffer length:actual];
	}
	while(actual==sizeof(buffer));

	return [NSData dataWithData:data];
}

-(NSData *)readDataOfLength:(int)length
{
	return [[self copyDataOfLength:length] autorelease];
}

-(NSData *)readDataOfLengthAtMost:(int)length;
{
	return [[self copyDataOfLengthAtMost:length] autorelease];
}

-(NSData *)copyDataOfLength:(int)length
{
	NSMutableData *data=[[NSMutableData alloc] initWithLength:length];
	if(!data) [self _raiseMemory];
	[self readBytes:length toBuffer:[data mutableBytes]];
	return data;
}

-(NSData *)copyDataOfLengthAtMost:(int)length
{
	NSMutableData *data=[[NSMutableData alloc] initWithLength:length];
	if(!data) [self _raiseMemory];
	int actual=[self readAtMost:length toBuffer:[data mutableBytes]];
	[data setLength:actual];
	return data;
}

-(void)readBytes:(int)num toBuffer:(void *)buffer
{
	if([self readAtMost:num toBuffer:buffer]!=num) [self _raiseEOF];
}



-(off_t)readAndDiscardAtMost:(off_t)num
{
	off_t skipped=0;
	uint8_t buf[16384];
	while(skipped<num)
	{
		int numbytes=num-skipped>sizeof(buf)?sizeof(buf):num-skipped;
		int actual=[self readAtMost:numbytes toBuffer:buf];
		skipped+=actual;
		if(actual==0) break;
	}
	return skipped;
}

-(void)readAndDiscardBytes:(off_t)num
{
	if([self readAndDiscardAtMost:num]!=num) [self _raiseEOF];
}



-(CSHandle *)subHandleOfLength:(off_t)length
{
	return [[[CSSubHandle alloc] initWithHandle:[[self copy] autorelease] from:[self offsetInFile] length:length] autorelease];
}

-(CSHandle *)subHandleFrom:(off_t)start length:(off_t)length
{
	return [[[CSSubHandle alloc] initWithHandle:[[self copy] autorelease] from:start length:length] autorelease];
}

-(CSHandle *)nonCopiedSubHandleOfLength:(off_t)length
{
	return [[[CSSubHandle alloc] initWithHandle:self from:[self offsetInFile] length:length] autorelease];
}

-(CSHandle *)nonCopiedSubHandleFrom:(off_t)start length:(off_t)length
{
	return [[[CSSubHandle alloc] initWithHandle:self from:start length:length] autorelease];
}




-(void)writeInt8:(int8_t)val { [self writeBytes:1 fromBuffer:(uint8_t *)&val]; }
-(void)writeUInt8:(uint8_t)val { [self writeBytes:1 fromBuffer:&val]; }

#define CSWriteValueImpl(type,name,conv) \
-(void)name:(type)val \
{ \
	uint8_t bytes[sizeof(type)]; \
	conv(bytes,val); \
	[self writeBytes:sizeof(type) fromBuffer:bytes]; \
}

CSWriteValueImpl(int16_t,writeInt16BE,CSSetInt16BE)
CSWriteValueImpl(int32_t,writeInt32BE,CSSetInt32BE)
//CSWriteValueImpl(int64_t,writeInt64BE,CSSetInt64BE)
CSWriteValueImpl(uint16_t,writeUInt16BE,CSSetUInt16BE)
CSWriteValueImpl(uint32_t,writeUInt32BE,CSSetUInt32BE)
//CSWriteValueImpl(uint64_t,writeUInt64BE,CSSetUInt64BE)

CSWriteValueImpl(int16_t,writeInt16LE,CSSetInt16LE)
CSWriteValueImpl(int32_t,writeInt32LE,CSSetInt32LE)
//CSWriteValueImpl(int64_t,writeInt64LE,CSSetInt64LE)
CSWriteValueImpl(uint16_t,writeUInt16LE,CSSetUInt16LE)
CSWriteValueImpl(uint32_t,writeUInt32LE,CSSetUInt32LE)
//CSWriteValueImpl(uint64_t,writeUInt64LE,CSSetUInt64LE)

CSWriteValueImpl(uint32_t,writeID,CSSetUInt32BE)


-(void)writeBits:(int)bits value:(uint32_t)val
{
	int bitsleft=bits;
	while(bitsleft)
	{
		if(!writebitsleft)
		{
			[self writeUInt8:writebyte];
			writebyte=0;
			writebitsleft=8;
		}

		int num=bitsleft;
		if(num>writebitsleft) num=writebitsleft;
		writebyte|=((val>>(bitsleft-num))&((1<<num)-1))<<(writebitsleft-num);

		bitsleft-=num;
		writebitsleft-=num;
	}
}

-(void)writeSignedBits:(int)bits value:(int32_t)val;
{
	[self writeBits:bits value:val];
}

-(void)flushWriteBits
{
	if(writebitsleft!=8) [self writeUInt8:writebyte];
	writebyte=0;
	writebitsleft=8;
}

-(void)writeData:(NSData *)data
{
	[self writeBytes:[data length] fromBuffer:[data bytes]];
}




/*-(void)_raiseClosed
{
	[NSException raise:@"CSFileNotOpenException"
	format:@"Attempted to read from file \"%@\", which was not open.",name];
}*/

-(void)_raiseMemory
{
	[NSException raise:CSOutOfMemoryException
	format:@"Out of memory while attempting to read from file \"%@\" (%@).",name,[self class]];
}

-(void)_raiseEOF
{
	[NSException raise:CSEndOfFileException
	format:@"Attempted to read past the end of file \"%@\" (%@).",name,[self class]];
}

-(void)_raiseNotImplemented:(SEL)selector
{
	[NSException raise:CSNotImplementedException
	format:@"Attempted to use unimplemented method +[%@ %@] when reading from file \"%@\".",[self class],NSStringFromSelector(selector),name];
}

-(void)_raiseNotSupported:(SEL)selector
{
	[NSException raise:CSNotSupportedException
	format:@"Attempted to use unsupported method +[%@ %@] when reading from file \"%@\".",[self class],NSStringFromSelector(selector),name];
}


-(NSString *)name { return name; }

-(NSString *)description
{
	return [NSString stringWithFormat:@"%@ for \"%@\", position %qu",
	[self class],name,[self offsetInFile]];
}



-(id)copyWithZone:(NSZone *)zone
{
	return [[[self class] allocWithZone:zone] initAsCopyOf:self];
}

@end
