#import "XADWinZipWavPackHandle.h"
#import "XADException.h"

#define SamplesPerBuffer 4096

extern WavpackStreamReader inputreader;

@implementation XADWinZipWavPackHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithHandle:handle length:length]))
	{
		context=NULL;
		buffer=NULL;
	}
	return self;
}

-(void)dealloc
{
	if(context) WavpackCloseFile(context);
	free(buffer);

	[super dealloc];
}

-(void)resetBlockStream
{
	if(context) { WavpackCloseFile(context); context=NULL; }
	free(buffer); buffer=NULL;

	char error[80];
	context=WavpackOpenFileInputEx(&inputreader,input,NULL,error,OPEN_WRAPPER,0);
	if(!context) [NSException raise:@"WavPackException" format:@"Error opening WavPack stream: %s",error];

	int numchannels=WavpackGetNumChannels(context);
	buffer=malloc(numchannels*SamplesPerBuffer*4);

	header=YES;
}

-(int)produceBlockAtOffset:(off_t)pos
{
	if(header)
	{
		header=NO;
		headerlength=WavpackGetWrapperBytes(context);
		[self setBlockPointer:WavpackGetWrapperData(context)];
		return headerlength;
	}
	else
	{
		int numchannels=WavpackGetNumChannels(context);
		int bytespersample=WavpackGetBytesPerSample(context);
		int numsamples=WavpackUnpackSamples(context,(int32_t *)buffer,SamplesPerBuffer);

		if(numsamples)
		{
			int32_t *expandedptr=(int32_t *)buffer;
			uint8_t *compactptr=buffer;

			switch(bytespersample)
			{
				case 1:
					for(int i=0;i<numsamples*numchannels;i++)
					{
						int32_t value=*expandedptr++;
						*compactptr++=(value+0x80)&0xff;
					}
				break;

				case 2:
					for(int i=0;i<numsamples*numchannels;i++)
					{
						int32_t value=*expandedptr++;
						*compactptr++=value&0xff;
						*compactptr++=(value>>8)&0xff;
					}
				break;

				case 3:
					for(int i=0;i<numsamples*numchannels;i++)
					{
						int32_t value=*expandedptr++;
						*compactptr++=value&0xff;
						*compactptr++=(value>>8)&0xff;
						*compactptr++=(value>>16)&0xff;
					}
				break;

				case 4:
					for(int i=0;i<numsamples*numchannels;i++)
					{
						int32_t value=*expandedptr++;
						*compactptr++=value&0xff;
						*compactptr++=(value>>8)&0xff;
						*compactptr++=(value>>16)&0xff;
						*compactptr++=(value>>24)&0xff;
					}
				break;
			}

			[self setBlockPointer:buffer];
			return numchannels*numsamples*bytespersample;
		}
		else
		{
			[self setBlockPointer:WavpackGetWrapperData(context)+headerlength];
			[self endBlockStream];
			return WavpackGetWrapperBytes(context)-headerlength;
		}
	}
}

@end

static int32_t ReadBytes(void *context,void *data,int32_t numbytes)
{
	CSInputBuffer *input=context;
	uint8_t *buffer=data;
	for(int i=0;i<numbytes;i++)
	{
		if(CSInputAtEOF(input)) return i;
		buffer[i]=CSInputNextByte(input);
	}
	return numbytes;
}

static uint32_t GetPos(void *context)
{
	CSInputBuffer *input=context;
	return CSInputBufferOffset(input);
}

static int SetPosAbs(void *context,uint32_t pos)
{
	CSInputBuffer *input=context;
	CSInputSeekToBufferOffset(input,pos);
	return 0;
}

static int SetPosRel(void *context,int32_t delta,int mode)
{
	CSInputBuffer *input=context;
	switch(mode)
	{
		case SEEK_SET: CSInputSeekToBufferOffset(input,delta); break;
		case SEEK_CUR: CSInputSeekToBufferOffset(input,CSInputBufferOffset(input)+delta); break;
		case SEEK_END: [XADException raiseNotSupportedException]; break;
	}
	return 0;
}

static int PushBackByte(void *context,int c) { [XADException raiseNotSupportedException]; return EOF; }

static uint32_t GetLength(void *context) { return 0; }

static int CanSeek(void *context) { return 1; }

WavpackStreamReader inputreader=
{
	.read_bytes=ReadBytes,
	.get_pos=GetPos,
	.set_pos_abs=SetPosAbs,
	.set_pos_rel=SetPosRel,
	.push_back_byte=PushBackByte,
	.get_length=GetLength,
	.can_seek=CanSeek,
	.write_bytes=NULL,
};



