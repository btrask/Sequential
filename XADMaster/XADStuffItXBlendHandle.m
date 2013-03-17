#import "XADStuffItXBlendHandle.h"
#import "XADStuffItXDarkhorseHandle.h"
#import "XADStuffItXCyanideHandle.h"
#import "XADPPMdHandles.h"

@implementation XADStuffItXBlendHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithName:[handle name] length:length]))
	{
		parent=[handle retain];
		currhandle=nil;
		currinput=NULL;
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
	[currhandle release];
	currhandle=nil;
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int bytes=0;
	uint8_t *bytebuffer=buffer;

	while(bytes<num)
	{
		if(!currhandle)
		{
			uint8_t buf[6];
			int actual=[parent readAtMost:6 toBuffer:buf];

			if(actual<6)
			{
				[self endStream];
				return bytes;
			}

			for(;;)
			{
				if(buf[0]==0x77&&buf[1]<=3) // possible match
				{
					// Check for a possible later match
					if((buf[2]==0x77&&buf[3]<=3)||(buf[3]==0x77&&buf[4]<=3)||(buf[4]==0x77&&buf[5]<=3))
					{
						// Only break if our size looks legit if there is a possible later match.
						if((CSUInt32BE(&buf[2])&0x1fff)==0) break;
					}
					else break;
				}
				memmove(buf,buf+1,5);
				buf[5]=[parent readUInt8];
			}

			uint32_t size=CSUInt32BE(&buf[2]);

			//NSLog(@"%d %x",buf[1],size);

			switch(buf[1])
			{
				case 0:
					currhandle=[[parent subHandleOfLength:size] retain];
					currinput=NULL;
				break;

				case 1:
				{
					int windowsize=1<<[parent readUInt8];
					if(windowsize<0x100000) windowsize=0x100000;
					XADStuffItXDarkhorseHandle *dh=[[XADStuffItXDarkhorseHandle alloc]
					initWithHandle:parent length:size windowSize:windowsize];
					currinput=dh->input;
					currhandle=dh;
				}
				break;

				case 2:
				{
					XADStuffItXCyanideHandle *ch=[[XADStuffItXCyanideHandle alloc]
					initWithHandle:parent length:size];
					currinput=ch->input;
					currhandle=ch;
				}
				break;

				case 3:
				{
					int allocsize=1<<[parent readUInt8];
					int order=[parent readUInt8];
					XADStuffItXBrimstoneHandle *bh=[[XADStuffItXBrimstoneHandle alloc]
					initWithHandle:parent length:size maxOrder:order subAllocSize:allocsize];
					currinput=bh->input;
					currhandle=bh;
				}
				break;
			}
		}

		int actual=[currhandle readAtMost:num-bytes toBuffer:bytebuffer+bytes];
		if(actual==0)
		{
			if(currinput) CSInputSynchronizeFileOffset(currinput);
			[currhandle release];
			currhandle=nil;
		}
		bytes+=actual;
	}

	return bytes;
}

@end
