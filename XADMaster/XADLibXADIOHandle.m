#import "XADLibXADIOHandle.h"
#import "XADException.h"
#import "Checksums.h"
#import "CRC.h"

static xadUINT8 xadIOPutFunc(struct xadInOut *io, xadUINT8 data);
static xadUINT8 xadIOGetFunc(struct xadInOut *io);

@implementation XADLibXADIOHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:0];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)outlength
{
	if((self=[super initWithData:[NSMutableData dataWithCapacity:outlength]]))
	{
		parent=[handle retain];
		inlen=[handle fileSize];
		outlen=outlength;
		unpacked=NO;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}



-(off_t)fileSize
{
	if(!unpacked) [self runUnpacker];
	return [super fileSize];
}

-(off_t)offsetInFile
{
	if(!unpacked) [self runUnpacker];
	return [super offsetInFile];
}

-(BOOL)atEndOfFile
{
	if(!unpacked) [self runUnpacker];
	return [super atEndOfFile];
}

-(void)seekToFileOffset:(off_t)offs
{
	if(!unpacked) [self runUnpacker];
	[super seekToFileOffset:offs];
}

-(void)seekToEndOfFile
{
	if(!unpacked) [self runUnpacker];
	[super seekToEndOfFile];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	if(!unpacked) [self runUnpacker];
	return [super readAtMost:num toBuffer:buffer];
}

-(void)writeBytes:(int)num fromBuffer:(const void *)buffer
{
	[self _raiseNotImplemented:_cmd];
}

-(NSData *)fileContents;
{
	if(!unpacked) [self runUnpacker];
	return [super fileContents];
}

-(NSData *)remainingFileContents;
{
	if(!unpacked) [self runUnpacker];
	return [super remainingFileContents];
}

-(NSData *)readDataOfLength:(int)length;
{
	if(!unpacked) [self runUnpacker];
	return [super readDataOfLength:length];
}

-(NSData *)readDataOfLengthAtMost:(int)length;
{
	if(!unpacked) [self runUnpacker];
	return [super readDataOfLengthAtMost:length];
}

-(NSData *)copyDataOfLength:(int)length;
{
	if(!unpacked) [self runUnpacker];
	return [super copyDataOfLength:length];
}

-(NSData *)copyDataOfLengthAtMost:(int)length;
{
	if(!unpacked) [self runUnpacker];
	return [super copyDataOfLengthAtMost:length];
}



-(void)runUnpacker
{
	unpacked=YES;
	xadUINT32 err=[self unpackData];

	if(err) [XADException raiseExceptionWithXADError:err];
}

-(struct xadInOut *)ioStructWithFlags:(xadUINT32)flags
{
	memset(&iostruct,0,sizeof(iostruct));

	iostruct.xio_Flags=flags;
    iostruct.xio_PutFunc=xadIOPutFunc;
    iostruct.xio_GetFunc=xadIOGetFunc;

	if(flags&XADIOF_ALLOCINBUFFER)
	{
		iostruct.xio_InBuffer=inbuf;
		iostruct.xio_InBufferSize=iostruct.xio_InBufferPos=XIDBUFSIZE;
	}
	if(flags & XADIOF_ALLOCOUTBUFFER)
	{
		iostruct.xio_OutBuffer=outbuf;
		iostruct.xio_OutBufferSize=XIDBUFSIZE;
	}

	iostruct.xio_InSize=inlen;
	iostruct.xio_OutSize=outlen;

	iostruct.inputhandle=parent;
	iostruct.outputdata=(NSMutableData *)backingdata;

	return &iostruct;
}

-(xadINT32)unpackData { return XADERR_NOTSUPPORTED; }

@end




static xadUINT8 xadIOPutFunc(struct xadInOut *io, xadUINT8 data)
{
  if(!io->xio_Error)
  {
    if(!io->xio_OutSize && !(io->xio_Flags & XADIOF_NOOUTENDERR))
    {
      io->xio_Error = XADERR_DECRUNCH;
      io->xio_Flags |= XADIOF_ERROR;
    }
    else
    {
      if(io->xio_OutBufferPos >= io->xio_OutBufferSize)
        xadIOWriteBuf(io);
      io->xio_OutBuffer[io->xio_OutBufferPos++] = data;
      if(!--io->xio_OutSize)
        io->xio_Flags |= XADIOF_LASTOUTBYTE;
    }
  }
  return data;
}

static xadUINT8 xadIOGetFunc(struct xadInOut *io)
{
	xadUINT8 res = 0;

	if(!io->xio_Error)
	{
		if(!io->xio_InSize)
		{
			if(!(io->xio_Flags & XADIOF_NOINENDERR))
			{
				io->xio_Error = XADERR_DECRUNCH;
				io->xio_Flags |= XADIOF_ERROR;
			}
		}
		else
		{
			if(io->xio_InBufferPos >= io->xio_InBufferSize)
			{
				xadUINT32 i;

				if((i = io->xio_InBufferSize) > io->xio_InSize)
				i = io->xio_InSize;

				@try {
					int actual=[io->inputhandle readAtMost:i toBuffer:io->xio_InBuffer];
					if(!actual)
					{
						io->xio_Flags|=XADIOF_ERROR;
						io->xio_Error=XADERR_INPUT;
					}
				} @catch(id e) {
					io->xio_Flags |= XADIOF_ERROR;
					io->xio_Error=XADERR_DECRUNCH;
				};

				if(io->xio_InFunc)
				(*(io->xio_InFunc))(io, i);

				res = *io->xio_InBuffer;
				io->xio_InBufferPos = 1;
			}
			else
			res = io->xio_InBuffer[io->xio_InBufferPos++];

			--io->xio_InSize;
		}
		if(!io->xio_InSize)
		io->xio_Flags |= XADIOF_LASTINBYTE;
	}

	return res;
}

xadUINT32 xadIOGetBitsLow(struct xadInOut *io, xadUINT8 bits)
{
  xadUINT32 x;

  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf |= xadIOGetChar(io) << io->xio_BitNum;
    io->xio_BitNum += 8;
  }
  x = io->xio_BitBuf & ((1<<bits)-1);
  io->xio_BitBuf >>= bits;
  io->xio_BitNum -= bits;
  return x;
}

xadUINT32 xadIOGetBitsLowR(struct xadInOut *io, xadUINT8 bits)
{
  xadUINT32 x;

  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf |= xadIOGetChar(io) << io->xio_BitNum;
    io->xio_BitNum += 8;
  }
  x = 0;
  io->xio_BitNum -= bits;
  while(bits)
  {
    x = (x<<1) | (io->xio_BitBuf & 1);
    io->xio_BitBuf >>= 1;
    --bits;
  }
  return x;
}

xadUINT32 xadIOReadBitsLow(struct xadInOut *io, xadUINT8 bits)
{
  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf |= xadIOGetChar(io) << io->xio_BitNum;
    io->xio_BitNum += 8;
  }
  return io->xio_BitBuf & ((1<<bits)-1);
}

void xadIODropBitsLow(struct xadInOut *io, xadUINT8 bits)
{
  io->xio_BitBuf >>= bits;
  io->xio_BitNum -= bits;
}

xadUINT32 xadIOGetBitsHigh(struct xadInOut *io, xadUINT8 bits)
{
  xadUINT32 x;

  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf = (io->xio_BitBuf << 8) | xadIOGetChar(io);
    io->xio_BitNum += 8;
  }
  x = (io->xio_BitBuf >> (io->xio_BitNum-bits)) & ((1<<bits)-1);
  io->xio_BitNum -= bits;
  return x;
}

xadUINT32 xadIOReadBitsHigh(struct xadInOut *io, xadUINT8 bits)
{
  while(io->xio_BitNum < bits)
  {
    io->xio_BitBuf = (io->xio_BitBuf << 8) | xadIOGetChar(io);
    io->xio_BitNum += 8;
  }
  return (io->xio_BitBuf >> (io->xio_BitNum-bits)) & ((1<<bits)-1);
}

void xadIODropBitsHigh(struct xadInOut *io, xadUINT8 bits)
{
  io->xio_BitNum -= bits;
}

xadERROR xadIOWriteBuf(struct xadInOut *io)
{
	if(!io->xio_Error && io->xio_OutBufferPos)
	{
		if(io->xio_OutFunc)
		io->xio_OutFunc(io, io->xio_OutBufferPos);
		if(!(io->xio_Flags & XADIOF_COMPLETEOUTFUNC))
		{
			[io->outputdata appendBytes:io->xio_OutBuffer length:io->xio_OutBufferPos];
			if(!(io->xio_Flags & XADIOF_NOCRC16))
			{
//				&io->xio_CRC16,
			}
			if(!(io->xio_Flags & XADIOF_NOCRC32))
			{
				io->xio_CRC32=XADCalculateCRC(io->xio_CRC32,io->xio_OutBuffer,io->xio_OutBufferPos,XADCRCTable_edb88320);
//				&io->xio_CRC32,
			}
		}
		io->xio_OutBufferPos = 0;
	}
	return io->xio_Error;
}
