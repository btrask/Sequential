#import "XADXZHandle.h"
#import "XADLZMA2Handle.h"
#import "XAD7ZipBranchHandles.h"
#import "XADDeltaHandle.h"
#import "XADException.h"
#import "CRC.h"
#import "Progress.h"


#define StreamHeaderState 0
#define BlockHeaderState 1
#define BlockDataState 2
#define BlockPaddingState 3
#define BlockChecksumState 4
#define StreamIndexState 5
#define StreamFooterState 6
#define StreamPaddingState 7
#define EndState 10

static uint64_t ParseInteger(CSHandle *fh);

@implementation XADXZHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithName:[handle name] length:length]))
	{
		parent=[handle retain];
		startoffs=[parent offsetInFile];
		currhandle=nil;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[currhandle release];
	[super dealloc];
}

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];

	[currhandle release];
	currhandle=nil;

	state=StreamHeaderState;
	checksumscorrect=YES;
	checksumflags=0;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int bytesread=0;
	uint8_t *bytebuf=buffer;

	while(bytesread<num && state!=EndState) switch(state)
	{
		 case StreamHeaderState:
		 {
			uint8_t head[6];
			[parent readBytes:6 toBuffer:head];
			if(head[0]!=0xfd||head[1]!='7'||head[2]!='z'||head[3]!='X'||head[4]!='Z'||head[5]!=0)
			[XADException raiseIllegalDataException];

			int version=[parent readUInt8];
			if(version!=0) [XADException raiseIllegalDataException];

			checksumflags=[parent readUInt8];
			if(checksumflags&0xf0) [XADException raiseIllegalDataException];
			[parent skipBytes:4]; // skip CRC

			state=BlockHeaderState;
		}
		break;

		case BlockHeaderState:
		{
			int blockheadsize=[parent readUInt8];
			if(blockheadsize==0)
			{
				state=StreamIndexState;
				break;
			}

			off_t streamstart=[parent offsetInFile]+blockheadsize*4+3;

			int blockflags=[parent readUInt8];
			if(blockflags&0x3c) [XADException raiseIllegalDataException];

			int numfilters=(blockflags&3)+1;

			if(blockflags&0x40) ParseInteger(parent);
			if(blockflags&0x80) ParseInteger(parent);

			uint64_t ids[4];
			NSData *properties[4];

			for(int i=0;i<numfilters;i++)
			{
				ids[i]=ParseInteger(parent);
				uint64_t size=ParseInteger(parent);
				properties[i]=[parent readDataOfLength:size];
			}

			[parent seekToFileOffset:streamstart];

			CSHandle *handle=parent;
			for(int i=numfilters-1;i>=0;i--)
			{
				switch(ids[i])
				{
					case 3: handle=[[[XADDeltaHandle alloc] initWithHandle:handle propertyData:properties[i]] autorelease]; break;

					case 4: handle=[[[XAD7ZipBCJHandle alloc] initWithHandle:handle propertyData:properties[i]] autorelease]; break;
					case 5: handle=[[[XAD7ZipPPCHandle alloc] initWithHandle:handle propertyData:properties[i]] autorelease]; break;
					case 6: handle=[[[XAD7ZipIA64Handle alloc] initWithHandle:handle propertyData:properties[i]] autorelease]; break;
					case 7: handle=[[[XAD7ZipARMHandle alloc] initWithHandle:handle propertyData:properties[i]] autorelease]; break;
					case 8: handle=[[[XAD7ZipThumbHandle alloc] initWithHandle:handle propertyData:properties[i]] autorelease]; break;
					case 9: handle=[[[XAD7ZipSPARCHandle alloc] initWithHandle:handle propertyData:properties[i]] autorelease]; break;

					case 33:
					{
						XADLZMA2Handle *lh=[[[XADLZMA2Handle alloc] initWithHandle:handle propertyData:properties[i]] autorelease];
						[lh setSeekBackAtEOF:YES];
						handle=lh;
					}
					break;
				}
			}

			currhandle=[handle retain];

			//currhandle=[[self decompressHandleForHandleAtBlockHeader:parent] retain];

			switch(checksumflags)
			{
				case 1: crc=0xffffffff; break;
				case 4: crc=0xffffffffffffffff; break;
			}

			state=BlockDataState;
		}
		break;

		case BlockDataState:
		{
			int actual=[currhandle readAtMost:num-bytesread toBuffer:&bytebuf[bytesread]];

			switch(checksumflags)
			{
				case 1:
					crc=XADCalculateCRC(crc,&bytebuf[bytesread],actual,XADCRCTable_edb88320);
				break;

				case 4:
					crc=XADCalculateCRC64(crc,&bytebuf[bytesread],actual,XADCRCTable_c96c5795d7870f42);
				break;
			}

			bytesread+=actual;

			if([currhandle atEndOfFile])
			{
				[currhandle release];
				currhandle=nil;
				state=BlockPaddingState;
			}
		}
		break;

		case BlockPaddingState:
			[parent skipBytes:(-([parent offsetInFile]-startoffs))&3];
			state=BlockChecksumState;
		break;

		case BlockChecksumState:
			switch(checksumflags)
			{
				case 0: break; // none

				case 1: // crc32
				{
					uint32_t correctcrc=[parent readUInt32LE];
					if((crc^0xffffffff)!=correctcrc) checksumscorrect=NO;
				}
				break;

				case 4: // crc64
				{
					uint64_t correctcrc=[parent readUInt64LE];
					if((crc^0xffffffffffffffff)!=correctcrc) checksumscorrect=NO;
				}
				break;

				case 2: case 3: [parent skipBytes:4]; break;
				case 5: case 6: [parent skipBytes:8]; break;
				case 7: case 8: case 9: [parent skipBytes:16]; break;
				case 10: case 11: case 12: [parent skipBytes:32]; break;
				case 13: case 14: case 15: [parent skipBytes:64]; break;
			}
			state=BlockHeaderState;
		break;

		case StreamIndexState:
		{
			uint64_t numrecords=ParseInteger(parent);
			for(uint64_t i=0;i<numrecords;i++)
			{
				// Just skip the index records
				ParseInteger(parent);
				ParseInteger(parent);
			}

			[parent skipBytes:(-([parent offsetInFile]-startoffs))&3];
			[parent skipBytes:4]; // skip CRC

			state=StreamFooterState;
		}
		break;

		case StreamFooterState:
			[parent skipBytes:8]; // skip CRC and backwards size
			if([parent readUInt8]!=0) [XADException raiseIllegalDataException];
			if([parent readUInt8]!=checksumflags) [XADException raiseIllegalDataException];
			if([parent readUInt8]!='Y') [XADException raiseIllegalDataException];
			if([parent readUInt8]!='Z') [XADException raiseIllegalDataException];

			state=StreamPaddingState;
		break;

		case StreamPaddingState:
			for(;;)
			{
				if([parent atEndOfFile])
				{
					state=EndState;
					break;
				}
				uint32_t pad=[parent readUInt32BE];
				if(pad=='\3757zX')
				{
					[parent skipBytes:-4];
					state=StreamHeaderState;
					break;
				}
				else if(pad!=0) [XADException raiseIllegalDataException];
			}
		break;
	}

	if(state==EndState) [self endStream];

	return bytesread;
}

-(BOOL)hasChecksum
{
	return checksumflags==1||checksumflags==4;
}

-(BOOL)isChecksumCorrect
{
	return checksumscorrect;
}

-(double)estimatedProgress { return [parent estimatedProgress]; } // TODO: better estimation using buffer?

@end




static uint64_t ParseInteger(CSHandle *fh)
{
	uint64_t res=0;
	int pos=0;
	uint8_t b;

	do
	{
		b=[fh readUInt8];
		res|=(b&0x7f)<<pos;
		pos+=7;
	}
	while(b&0x80);

	return res;
}
