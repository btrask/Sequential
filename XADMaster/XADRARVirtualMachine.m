#import "XADRARVirtualMachine.h"
#import "XADException.h"
#import "CRC.h"




uint32_t CSInputNextRARVMNumber(CSInputBuffer *input)
{ 
	switch(CSInputNextBitString(input,2))
	{
		case 0: return CSInputNextBitString(input,4);
		case 1:
		{
			int val=CSInputNextBitString(input,8);
			if(val>=16) return val;
			else return 0xffffff00|(val<<4)|CSInputNextBitString(input,4);
		}
		case 2: return CSInputNextBitString(input,16);
		default: return CSInputNextLongBitString(input,32);
	}
}



@implementation XADRARVirtualMachine

-(id)init
{
	if((self=[super init]))
	{
		InitializeRARVirtualMachine(&vm);
	}
	return self;
}

-(void)dealloc
{
	//CleanupRARVirutalMachine(&vm);
	[super dealloc];
}

-(uint8_t *)memory { return vm.memory; }

-(void)setRegisters:(uint32_t *)newregisters
{
	SetRARVirtualMachineRegisters(&vm,newregisters);
}

-(void)readMemoryAtAddress:(uint32_t)address length:(int)length toBuffer:(uint8_t *)buffer
{
	memcpy(buffer,&vm.memory[address],length);
}

-(void)readMemoryAtAddress:(uint32_t)address length:(int)length toMutableData:(NSMutableData *)data
{
	[self readMemoryAtAddress:address length:length toBuffer:[data mutableBytes]];
}

-(void)writeMemoryAtAddress:(uint32_t)address length:(int)length fromBuffer:(const uint8_t *)buffer
{
	memcpy(&vm.memory[address],buffer,length);
}

-(void)writeMemoryAtAddress:(uint32_t)address length:(int)length fromData:(NSData *)data
{
	[self writeMemoryAtAddress:address length:length fromBuffer:[data bytes]];
}

-(uint32_t)readWordAtAddress:(uint32_t)address
{
	return RARVirtualMachineRead32(&vm,address);
}

-(void)writeWordAtAddress:(uint32_t)address value:(uint32_t)value
{
	RARVirtualMachineWrite32(&vm,address,value);
}

-(BOOL)executeProgramCode:(XADRARProgramCode *)code
{
	return ExecuteRARCode(&vm,[code opcodes],[code numberOfOpcodes]);
}

@end





@implementation XADRARProgramCode

-(id)initWithByteCode:(const uint8_t *)bytes length:(int)length
{
	if((self=[super init]))
	{
		opcodes=[NSMutableData new];
		staticdata=nil;
		globalbackup=[NSMutableData new];

		if([self parseByteCode:bytes length:length]) return self;

		[self release];
	}

	return nil;
}

-(void)dealloc
{
	[opcodes release];
	[staticdata release];
	[globalbackup release];
	[super dealloc];
}

-(BOOL)parseByteCode:(const uint8_t *)bytes length:(int)length
{
	// TODO: deal with exceptions causing memory leaks

	if(length==0) return NO;

	// Check XOR sum.
	uint8_t xor=0;
	for(int i=1;i<length;i++) xor^=bytes[i];
	if(xor!=bytes[0]) return NO;

	// Calculate CRC for fast native path replacements.
	fingerprint=XADCalculateCRC(0xffffffff,bytes,length,XADCRCTable_edb88320)^0xffffffff;
	fingerprint|=(uint64_t)length<<32;

	CSInputBuffer *input=CSInputBufferAllocWithBuffer(&bytes[1],length-1,0);

	// Read static data, if any.
	if(CSInputNextBit(input))
	{
		int length=CSInputNextRARVMNumber(input)+1;
		NSMutableData *data=[NSMutableData dataWithLength:length];
		uint8_t *databytes=[data mutableBytes];

		for(int i=0;i<length;i++) databytes[i]=CSInputNextBitString(input,8);

		staticdata=data;
	}

	// Read instructions.
	while(CSInputBitsLeftInBuffer(input)>=8)
	{
		[opcodes increaseLengthBy:sizeof(RAROpcode)];
		RAROpcode *opcodearray=[self opcodes];
		int currinstruction=[self numberOfOpcodes]-1;
		RAROpcode *opcode=&opcodearray[currinstruction];

		int instruction=CSInputNextBitString(input,4);
		if(instruction&0x08) instruction=((instruction<<2)|CSInputNextBitString(input,2))-24;

		BOOL bytemode=NO;
		if(RARInstructionHasByteMode(instruction)) bytemode=CSInputNextBitString(input,1);

		SetRAROpcodeInstruction(opcode,instruction,bytemode);

		int numargs=NumberOfRARInstructionOperands(instruction);

		if(numargs>=1)
		{
			unsigned int addressingmode;
			uint32_t value;
			[self parseOperandFromBuffer:input addressingMode:&addressingmode value:&value
			byteMode:bytemode isRelativeJump:RARInstructionIsRelativeJump(instruction)
			currentInstructionOffset:currinstruction];
			SetRAROpcodeOperand1(opcode,addressingmode,value);
		}
		if(numargs==2)
		{
			unsigned int addressingmode;
			uint32_t value;
			[self parseOperandFromBuffer:input addressingMode:&addressingmode value:&value
			 byteMode:bytemode isRelativeJump:NO currentInstructionOffset:0];
			SetRAROpcodeOperand2(opcode,addressingmode,value);
		}
	}

	// Check if program is properly terminated, if not, add a ret opcode.
	if(!IsProgramTerminated([self opcodes],[self numberOfOpcodes]))
	{
		[opcodes increaseLengthBy:sizeof(RAROpcode)];
		RAROpcode *opcodearray=[self opcodes];
		int currinstruction=[self numberOfOpcodes]-1;
		RAROpcode *opcode=&opcodearray[currinstruction];

		SetRAROpcodeInstruction(opcode,RARRetInstruction,false);
	}

	CSInputBufferFree(input);

	return PrepareRAROpcodes([self opcodes],[self numberOfOpcodes]);
}

-(void)parseOperandFromBuffer:(CSInputBuffer *)input addressingMode:(unsigned int *)modeptr
value:(uint32_t *)valueptr byteMode:(BOOL)bytemode isRelativeJump:(BOOL)isrel currentInstructionOffset:(int)instructionoffset
{
	if(CSInputNextBit(input))
	{
		int reg=CSInputNextBitString(input,3);
		*modeptr=RARRegisterAddressingMode(reg);
	}
	else
	{
		if(CSInputNextBit(input))
		{
			if(CSInputNextBit(input))
			{
				if(CSInputNextBit(input))
				{
					*valueptr=CSInputNextRARVMNumber(input);
					*modeptr=RARAbsoluteAddressingMode;
				}
				else
				{
					int reg=CSInputNextBitString(input,3);
					*valueptr=CSInputNextRARVMNumber(input);
					*modeptr=RARIndexedAbsoluteAddressingMode(reg);
				}
			}
			else
			{
				int reg=CSInputNextBitString(input,3);
				*modeptr=RARRegisterIndirectAddressingMode(reg);
			}
		}
		else
		{
			if(bytemode)
			{
				*valueptr=CSInputNextBitString(input,8);
				*modeptr=RARImmediateAddressingMode;
				//return [NSString stringWithFormat:@"%d",val];
			}
			else
			{
				*valueptr=CSInputNextRARVMNumber(input);
				*modeptr=RARImmediateAddressingMode;
			}

			if(isrel)
			{
				if(*valueptr>=256) *valueptr-=256; // Absolute address
				else
				{
					// Relative address
					if(*valueptr>=136) *valueptr-=264;
					else if(*valueptr>=16) *valueptr-=8;
					else if(*valueptr>=8) *valueptr-=16;
					*valueptr+=instructionoffset;
				}
			}
		}
	}
}

-(RAROpcode *)opcodes { return [opcodes mutableBytes]; }

-(int)numberOfOpcodes { return [opcodes length]/sizeof(RAROpcode); }

-(NSData *)staticData { return staticdata; }

-(NSMutableData *)globalBackup { return globalbackup; }

-(uint64_t)fingerprint { return fingerprint; }

-(NSString *)disassemble
{
	RAROpcode *opcodearray=[self opcodes];
	int numopcodes=[self numberOfOpcodes];

	NSMutableString *disassembly=[NSMutableString string];

	for(int i=0;i<numopcodes;i++)
	{
		[disassembly appendFormat:@"%04x\t%s\n",i,DescribeRAROpcode(&opcodearray[i])];
	}

	return disassembly;
}

@end



@implementation XADRARProgramInvocation

-(id)initWithProgramCode:(XADRARProgramCode *)code globalData:(NSData *)data registers:(uint32_t *)registers
{
	if((self=[super init]))
	{
		programcode=[code retain];

		if(data)
		{
			globaldata=[[NSMutableData alloc] initWithData:data];
			if([globaldata length]<RARProgramSystemGlobalSize) [globaldata setLength:RARProgramSystemGlobalSize];
		}
		else globaldata=[[NSMutableData alloc] initWithLength:RARProgramSystemGlobalSize];

		if(registers) memcpy(initialregisters,registers,sizeof(initialregisters));
		else memset(initialregisters,0,sizeof(initialregisters));
	}
	return self;
}

-(void)dealloc
{
	[programcode release];
	[globaldata release];
	[super dealloc];
}

-(XADRARProgramCode *)programCode { return programcode; }

-(NSData *)globalData { return globaldata; }

-(uint32_t)initialRegisterState:(int)n
{
	if(n<0||n>=8) [NSException raise:NSRangeException format:@"Attempted to set non-existent register"];

	return initialregisters[n];
}

-(void)setInitialRegisterState:(int)n toValue:(uint32_t)val
{
	if(n<0||n>=8) [NSException raise:NSRangeException format:@"Attempted to set non-existent register"];

	initialregisters[n]=val;
}

-(void)setGlobalValueAtOffset:(int)offs toValue:(uint32_t)val
{
	if(offs<0||offs+4>[globaldata length]) [NSException raise:NSRangeException format:@"Attempted to write outside global memory"];

	uint8_t *bytes=[globaldata mutableBytes];
	CSSetUInt32LE(&bytes[offs],val);
}

-(void)backupGlobalData
{
	NSMutableData *backup=[programcode globalBackup];
	if([globaldata length]>RARProgramSystemGlobalSize) [backup setData:globaldata];
	else [backup setLength:0];
}

-(void)restoreGlobalDataIfAvailable
{
	NSMutableData *backup=[programcode globalBackup];
	if([backup length]>RARProgramSystemGlobalSize) [globaldata setData:backup];
}

-(BOOL)executeOnVitualMachine:(XADRARVirtualMachine *)vm
{
	int globallength=[globaldata length];
	if(globallength>RARProgramGlobalSize) globallength=RARProgramGlobalSize;
	[vm writeMemoryAtAddress:RARProgramGlobalAddress length:globallength fromData:globaldata];

	NSData *staticdata=[programcode staticData];
	if(staticdata)
	{
		int staticlength=[staticdata length];
		if(staticlength>RARProgramGlobalSize-globallength) staticlength=RARProgramGlobalSize-globallength;
		[vm writeMemoryAtAddress:RARProgramGlobalAddress length:staticlength fromData:staticdata];
	}

	[vm setRegisters:initialregisters];

	if(![vm executeProgramCode:programcode]) return NO;

	uint32_t newgloballength=[vm readWordAtAddress:RARProgramGlobalAddress+0x30];
	if(newgloballength>RARProgramUserGlobalSize) newgloballength=RARProgramUserGlobalSize;
	if(newgloballength>0)
	{
		[vm readMemoryAtAddress:RARProgramGlobalAddress
		length:newgloballength+RARProgramSystemGlobalSize
		toMutableData:[globaldata mutableBytes]];
	}
	else [globaldata setLength:0];

	return YES;
}

@end
