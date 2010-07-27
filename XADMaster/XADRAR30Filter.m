#import "XADRAR30Filter.h"
#import "XADException.h"
#import "RARAudioDecoder.h"

@implementation XADRAR30Filter

+(XADRAR30Filter *)filterForProgramInvocation:(XADRARProgramInvocation *)program
startPosition:(off_t)startpos length:(int)length
{
	//NSLog(@"%010qx",[[program programCode] fingerprint]);

	Class class;
	switch([[program programCode] fingerprint])
	{
		case 0x1d0e06077d: class=[XADRAR30DeltaFilter class]; break;
		case 0xd8bc85e701: class=[XADRAR30AudioFilter class]; break;
		case 0x35ad576887: class=[XADRAR30E8Filter class]; break;
		case 0x393cd7e57e: class=[XADRAR30E8E9Filter class]; break;
		default: class=[XADRAR30Filter class]; break;
	}

	return [[[class alloc] initWithProgramInvocation:program startPosition:startpos length:length] autorelease];
}

-(id)initWithProgramInvocation:(XADRARProgramInvocation *)program
startPosition:(off_t)startpos length:(int)length
{
	if(self=[super init])
	{
		invocation=[program retain];
		blockstartpos=startpos;
		blocklength=length;

		filteredblockaddress=filteredblocklength=0;
	}
	return self;
}

-(void)dealloc
{
	[invocation release];
	[super dealloc];
}

-(off_t)startPosition { return blockstartpos; }

-(int)length { return blocklength; }

-(uint32_t)filteredBlockAddress { return filteredblockaddress; }

-(uint32_t)filteredBlockLength { return filteredblocklength; }

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	[invocation restoreGlobalDataIfAvailable]; // This is silly, but RAR does it.

	[invocation setInitialRegisterState:6 toValue:(uint32_t)pos];
	[invocation setGlobalValueAtOffset:0x24 toValue:(uint32_t)pos];
	[invocation setGlobalValueAtOffset:0x28 toValue:(uint32_t)(pos>>32)];

	if(![invocation executeOnVitualMachine:vm]) [XADException raiseIllegalDataException];

	filteredblockaddress=[vm readWordAtAddress:RARProgramGlobalAddress+0x20]&RARProgramMemoryMask;
	filteredblocklength=[vm readWordAtAddress:RARProgramGlobalAddress+0x1c]&RARProgramMemoryMask;

	if(filteredblockaddress+filteredblocklength>=RARProgramMemorySize) filteredblockaddress=filteredblocklength=0;

	[invocation backupGlobalData]; // Also silly.
}

@end




@implementation XADRAR30DeltaFilter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	int length=[invocation initialRegisterState:4]; // should really be blocklength, but, RAR.
	int numchannels=[invocation initialRegisterState:0];
	uint8_t *memory=[vm memory];

	if(length>RARProgramWorkSize/2) return;

	filteredblockaddress=length;
	filteredblocklength=length;

	uint8_t *src=&memory[0];
	uint8_t *dest=&memory[filteredblockaddress];
	for(int i=0;i<numchannels;i++)
	{
		uint8_t lastbyte=0;
		for(int destoffs=i;destoffs<length;destoffs+=numchannels)
		{
			uint8_t newbyte=lastbyte-*src++;
			lastbyte=dest[destoffs]=newbyte;
		}
	}
}

@end



@implementation XADRAR30AudioFilter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	int length=[invocation initialRegisterState:4]; // should really be blocklength, but, RAR.
	int numchannels=[invocation initialRegisterState:0];
	uint8_t *memory=[vm memory];

	if(length>RARProgramWorkSize/2) return;

	filteredblockaddress=length;
	filteredblocklength=length;

	uint8_t *src=&memory[0];
	uint8_t *dest=&memory[filteredblockaddress];
	for(int i=0;i<numchannels;i++)
	{
		RAR30AudioState state;
		memset(&state,0,sizeof(state));

		for(int destoffs=i;destoffs<length;destoffs+=numchannels)
		{
			dest[destoffs]=DecodeRAR30Audio(&state,*src++);
		}
	}
}

@end



@implementation XADRAR30E8Filter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	int length=[invocation initialRegisterState:4];
	int filesize=0x1000000;
	uint8_t *memory=[vm memory];

	if(length>RARProgramWorkSize || length<4) return;

	filteredblockaddress=0;
	filteredblocklength=length;

	for(int i=0;i<=length-5;i++)
	{
		if(memory[i]==0xe8)
		{
			int32_t currpos=pos+i+1;
			int32_t address=XADRARVirtualMachineRead32(vm,i+1);
			if(address<0)
			{
				if(address+currpos>=0) XADRARVirtualMachineWrite32(vm,i+1,address+filesize);
			}
            else
			{
				if(address<filesize) XADRARVirtualMachineWrite32(vm,i+1,address-currpos);
			}

			i+=4;
		}
	}
}

@end



@implementation XADRAR30E8E9Filter

-(void)executeOnVirtualMachine:(XADRARVirtualMachine *)vm atPosition:(off_t)pos
{
	int length=[invocation initialRegisterState:4];
	int filesize=0x1000000;
	uint8_t *memory=[vm memory];

	if(length>RARProgramWorkSize || length<4) return;

	filteredblockaddress=0;
	filteredblocklength=length;

	for(int i=0;i<=length-5;i++)
	{
		if(memory[i]==0xe8 || memory[i]==0xe9)
		{
			int32_t currpos=pos+i+1;
			int32_t address=XADRARVirtualMachineRead32(vm,i+1);
			if(address<0)
			{
				if(address+currpos>=0) XADRARVirtualMachineWrite32(vm,i+1,address+filesize);
			}
            else
			{
				if(address<filesize) XADRARVirtualMachineWrite32(vm,i+1,address-currpos);
			}

			i+=4;
		}
	}
}

@end
