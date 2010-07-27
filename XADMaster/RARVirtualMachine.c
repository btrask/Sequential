#include "RARVirtualMachine.h"

#include <stdio.h>



static bool RunVirtualMachineOrGetLabels(RARVirtualMachine *self,
RAROpcode *opcodes,int numopcodes,void ***instructionlabels);

static RARGetterFunction OperandGetters_32[RARNumberOfAddressingModes];
static RARGetterFunction OperandGetters_8[RARNumberOfAddressingModes];
static RARSetterFunction OperandSetters_32[RARNumberOfAddressingModes];
static RARSetterFunction OperandSetters_8[RARNumberOfAddressingModes];




// Setup

void InitializeRARVirtualMachine(RARVirtualMachine *self)
{
	memset(self->registers,0,sizeof(self->registers));
}



// Program building

void SetRAROpcodeInstruction(RAROpcode *opcode,unsigned int instruction,bool bytemode)
{
	opcode->instruction=instruction;
	opcode->bytemode=bytemode;
}

void SetRAROpcodeOperand1(RAROpcode *opcode,unsigned int addressingmode,uint32_t value)
{
	opcode->addressingmode1=addressingmode;
	opcode->value1=value;
}

void SetRAROpcodeOperand2(RAROpcode *opcode,unsigned int addressingmode,uint32_t value)
{
	opcode->addressingmode2=addressingmode;
	opcode->value2=value;
}

bool IsProgramTerminated(RAROpcode *opcodes,int numopcodes)
{
	return RARInstructionIsUnconditionalJump(opcodes[numopcodes-1].instruction);
}

bool PrepareRAROpcodes(RAROpcode *opcodes,int numopcodes)
{
	void **instructionlabels_32,**instructionlabels_8;

	RunVirtualMachineOrGetLabels(NULL,NULL,0,&instructionlabels_32);
	instructionlabels_8=&instructionlabels_32[RARNumberOfInstructions];

	for(int i=0;i<numopcodes;i++)
	{
		if(opcodes[i].instruction>=RARNumberOfInstructions) return false;

		void **instructionlabels;
		RARSetterFunction *setterfunctions;
		RARGetterFunction *getterfunctions;

		if(opcodes[i].instruction==RARMovsxInstruction||opcodes[i].instruction==RARMovzxInstruction)
		{
			instructionlabels=instructionlabels_32;
			getterfunctions=OperandGetters_8;
			setterfunctions=OperandSetters_32;
		}
		else if(opcodes[i].bytemode)
		{
			if(!RARInstructionHasByteMode(opcodes[i].instruction)) return false;

			instructionlabels=instructionlabels_8;
			getterfunctions=OperandGetters_8;
			setterfunctions=OperandSetters_8;
		}
		else
		{
			instructionlabels=instructionlabels_32;
			getterfunctions=OperandGetters_32;
			setterfunctions=OperandSetters_32;
		}

		opcodes[i].instructionlabel=instructionlabels[opcodes[i].instruction];

		int numoperands=NumberOfRARInstructionOperands(opcodes[i].instruction);

		if(numoperands>=1)
		{
			if(opcodes[i].addressingmode1>=RARNumberOfAddressingModes) return false;
			opcodes[i].operand1getter=getterfunctions[opcodes[i].addressingmode1];
			opcodes[i].operand1setter=setterfunctions[opcodes[i].addressingmode1];

			if(opcodes[i].addressingmode1==RARImmediateAddressingMode)
			{
				if(RARInstructionWritesFirstOperand(opcodes[i].instruction)) return false;
			}
			else if(opcodes[i].addressingmode1==RARAbsoluteAddressingMode)
			{
				opcodes[i].value1&=RARProgramMemoryMask;
			}
		}

		if(numoperands==2)
		{
			if(opcodes[i].addressingmode2>=RARNumberOfAddressingModes) return false;
			opcodes[i].operand2getter=getterfunctions[opcodes[i].addressingmode2];
			opcodes[i].operand2setter=setterfunctions[opcodes[i].addressingmode2];

			if(opcodes[i].addressingmode2==RARImmediateAddressingMode)
			{
				if(RARInstructionWritesSecondOperand(opcodes[i].instruction)) return false;
			}
			else if(opcodes[i].addressingmode2==RARAbsoluteAddressingMode)
			{
				opcodes[i].value2&=RARProgramMemoryMask;
			}
		}
	}

	return true;
}




// Execution

bool ExecuteRARCode(RARVirtualMachine *self,RAROpcode *opcodes,int numopcodes)
{
	if(!IsProgramTerminated(opcodes,numopcodes)) return false;

	self->flags=0; // ?

	return RunVirtualMachineOrGetLabels(self,opcodes,numopcodes,NULL);
}



// Direct-threading implementation function

#define CarryFlag 1
#define ZeroFlag 2
#define SignFlag 0x80000000

#define SignExtend(a) ((uint32_t)((int8_t)(a)))

#define GetOperand1() (opcode->operand1getter(self,opcode->value1))
#define GetOperand2() (opcode->operand2getter(self,opcode->value2))
#define SetOperand1(data) opcode->operand1setter(self,opcode->value1,data)
#define SetOperand2(data) opcode->operand2setter(self,opcode->value2,data)

#define SetFlagsWithCarry(res,carry) ({ uint32_t result=(res); flags=(result==0?ZeroFlag:(result&SignFlag))|(carry); })
#define SetByteFlagsWithCarry(res,carry) ({ uint32_t result=(res); flags=(result==0?ZeroFlag:(SignExtend(result)&SignFlag))|(carry); })
#define SetFlags(res) (SetFlagsWithCarry(res,0))

#define SetOperand1AndFlagsWithCarry(res,carry) ({ uint32_t r=(res); SetFlagsWithCarry(r,carry); SetOperand1(r); })
#define SetOperand1AndByteFlagsWithCarry(res,carry) ({ uint32_t r=(res); SetByteFlagsWithCarry(r,carry); SetOperand1(r); })
#define SetOperand1AndFlags(res) ({ uint32_t r=(res); SetFlags(r); SetOperand1(r); })

//static int count=0;
//#define Debug() ({ printf("Execute: %04x\t%s\n",opcode-opcodes,DescribeRAROpcode(opcode)); })
//#define Debug() ({ printf("%d %04x %08x ",count++,opcode-opcodes,flags); for(int i=0;i<8;i++) printf("%08x(%08x) ",self->registers[i],RARVirtualMachineRead32(self,self->registers[i])); printf("\n"); })
//#define Debug() ({ printf("%d %04x %s\t%08x ",count++,opcode-opcodes,DescribeRAROpcode(opcode),flags); for(int i=0;i<8;i++) printf("%08x(%08x) ",self->registers[i],RARVirtualMachineRead32(self,self->registers[i])); printf("\n"); })
#define Debug() ({ })

#define NextInstruction() ({ opcode++; Debug(); goto *opcode->instructionlabel; })
#define Jump(offs) ({ uint32_t o=(offs); if(o>=numopcodes) return false; opcode=&opcodes[o]; Debug(); goto *opcode->instructionlabel; })

static bool RunVirtualMachineOrGetLabels(RARVirtualMachine *self,
RAROpcode *opcodes,int numopcodes,void ***instructionlabels)
{
	static void *labels[2][RARNumberOfInstructions]=
	{
		[0][RARMovInstruction]=&&MovLabel,[1][RARMovInstruction]=&&MovLabel,
		[0][RARCmpInstruction]=&&CmpLabel,[1][RARCmpInstruction]=&&CmpLabel,
		[0][RARAddInstruction]=&&AddLabel,[1][RARAddInstruction]=&&AddByteLabel,
		[0][RARSubInstruction]=&&SubLabel,[1][RARSubInstruction]=&&SubLabel,
		[0][RARJzInstruction]=&&JzLabel,
		[0][RARJnzInstruction]=&&JnzLabel,
		[0][RARIncInstruction]=&&IncLabel,[1][RARIncInstruction]=&&IncByteLabel,
		[0][RARDecInstruction]=&&DecLabel,[1][RARDecInstruction]=&&DecByteLabel,
		[0][RARJmpInstruction]=&&JmpLabel,
		[0][RARXorInstruction]=&&XorLabel,[1][RARXorInstruction]=&&XorLabel,
		[0][RARAndInstruction]=&&AndLabel,[1][RARAndInstruction]=&&AndLabel,
		[0][RAROrInstruction]=&&OrLabel,[1][RAROrInstruction]=&&OrLabel,
		[0][RARTestInstruction]=&&TestLabel,[1][RARTestInstruction]=&&TestLabel,
		[0][RARJsInstruction]=&&JsLabel,
		[0][RARJnsInstruction]=&&JnsLabel,
		[0][RARJbInstruction]=&&JbLabel,
		[0][RARJbeInstruction]=&&JbeLabel,
		[0][RARJaInstruction]=&&JaLabel,
		[0][RARJaeInstruction]=&&JaeLabel,
		[0][RARPushInstruction]=&&PushLabel,
		[0][RARPopInstruction]=&&PopLabel,
		[0][RARCallInstruction]=&&CallLabel,
		[0][RARRetInstruction]=&&RetLabel,
		[0][RARNotInstruction]=&&NotLabel,[1][RARNotInstruction]=&&NotLabel,
		[0][RARShlInstruction]=&&ShlLabel,[1][RARShlInstruction]=&&ShlLabel,
		[0][RARShrInstruction]=&&ShrLabel,[1][RARShrInstruction]=&&ShrLabel,
		[0][RARSarInstruction]=&&SarLabel,[1][RARSarInstruction]=&&SarLabel,
		[0][RARNegInstruction]=&&NegLabel,[1][RARNegInstruction]=&&NegLabel,
		[0][RARPushaInstruction]=&&PushaLabel,
		[0][RARPopaInstruction]=&&PopaLabel,
		[0][RARPushfInstruction]=&&PushfLabel,
		[0][RARPopfInstruction]=&&PopfLabel,
		[0][RARMovzxInstruction]=&&MovzxLabel,
		[0][RARMovsxInstruction]=&&MovsxLabel,
		[0][RARXchgInstruction]=&&XchgLabel,
		[0][RARMulInstruction]=&&MulLabel,[1][RARMulInstruction]=&&MulLabel,
		[0][RARDivInstruction]=&&DivLabel,[1][RARDivInstruction]=&&DivLabel,
		[0][RARAdcInstruction]=&&AdcLabel,[1][RARAdcInstruction]=&&AdcByteLabel,
		[0][RARSbbInstruction]=&&SbbLabel,[1][RARSbbInstruction]=&&SbbByteLabel,
		[0][RARPrintInstruction]=&&PrintLabel,
	};

	if(instructionlabels)
	{
		*instructionlabels=&labels[0][0];
		return true;
	}

	RAROpcode *opcode;
	uint32_t flags=self->flags;

	Jump(0);

	MovLabel:
		SetOperand1(GetOperand2());
		NextInstruction();

	CmpLabel:
	{
		uint32_t term1=GetOperand1();
		SetFlagsWithCarry(term1-GetOperand2(),result>term1);
		NextInstruction();
	}

	AddLabel:
	{
		uint32_t term1=GetOperand1();
		SetOperand1AndFlagsWithCarry(term1+GetOperand2(),result<term1);
		NextInstruction();
	}
	AddByteLabel:
	{
		uint32_t term1=GetOperand1();
		SetOperand1AndByteFlagsWithCarry(term1+GetOperand2()&0xff,result<term1);
		NextInstruction();
	}

	SubLabel:
	{
		uint32_t term1=GetOperand1();
		SetOperand1AndFlagsWithCarry(term1-GetOperand2(),result>term1);
		NextInstruction();
	}
/*	SubByteLabel: // Not correctly implemented in the RAR VM
	{
		uint32_t term1=GetOperand1();
		SetOperandAndByteFlagsWithCarry(term1-GetOperand2()&0xff,result>term1);
		NextInstruction();
	}*/

	JzLabel:
		if(flags&ZeroFlag) Jump(GetOperand1());
		else NextInstruction();

	JnzLabel:
		if(!(flags&ZeroFlag)) Jump(GetOperand1());
		else NextInstruction();

	IncLabel:
		SetOperand1AndFlags(GetOperand1()+1);
		NextInstruction();
	IncByteLabel:
		SetOperand1AndFlags(GetOperand1()+1&0xff);
		NextInstruction();

	DecLabel:
		SetOperand1AndFlags(GetOperand1()-1);
		NextInstruction();
	DecByteLabel:
		SetOperand1AndFlags(GetOperand1()-1&0xff);
		NextInstruction();

	JmpLabel:
		Jump(GetOperand1());

	XorLabel:
		SetOperand1AndFlags(GetOperand1()^GetOperand2());
		NextInstruction();

	AndLabel:
		SetOperand1AndFlags(GetOperand1()&GetOperand2());
		NextInstruction();

	OrLabel:
		SetOperand1AndFlags(GetOperand1()|GetOperand2());
		NextInstruction();

	TestLabel:
		SetFlags(GetOperand1()&GetOperand2());
		NextInstruction();

	JsLabel:
		if(flags&SignFlag) Jump(GetOperand1());
		else NextInstruction();

	JnsLabel:
		if(!(flags&SignFlag)) Jump(GetOperand1());
		else NextInstruction();

	JbLabel:
		if(flags&CarryFlag) Jump(GetOperand1());
		else NextInstruction();

	JbeLabel:
		if(flags&(CarryFlag|ZeroFlag)) Jump(GetOperand1());
		else NextInstruction();

	JaLabel:
		if(!(flags&(CarryFlag|ZeroFlag))) Jump(GetOperand1());
		else NextInstruction();

	JaeLabel:
		if(!(flags&CarryFlag)) Jump(GetOperand1());
		else NextInstruction();

	PushLabel:
		self->registers[7]-=4;
		RARVirtualMachineWrite32(self,self->registers[7],GetOperand1());
		NextInstruction();

	PopLabel:
		SetOperand1(RARVirtualMachineRead32(self,self->registers[7]));
		self->registers[7]+=4;
		NextInstruction();

	CallLabel:
		self->registers[7]-=4;
		RARVirtualMachineWrite32(self,self->registers[7],opcode-opcodes+1);
		Jump(GetOperand1());

	RetLabel:
	{
		if(self->registers[7]>=RARProgramMemorySize)
		{
			self->flags=flags;
			return true;
		}
		uint32_t retaddr=RARVirtualMachineRead32(self,self->registers[7]);
		self->registers[7]+=4;
		Jump(retaddr);
	}

	NotLabel:
		SetOperand1(~GetOperand1());
		NextInstruction();

	ShlLabel:
	{
		uint32_t op1=GetOperand1();
		uint32_t op2=GetOperand2();
		SetOperand1AndFlagsWithCarry(op1<<op2,((op1<<(op2-1))&0x80000000)!=0);
		NextInstruction();
	}

	ShrLabel:
	{
		uint32_t op1=GetOperand1();
		uint32_t op2=GetOperand2();
		SetOperand1AndFlagsWithCarry(op1>>op2,((op1>>(op2-1))&1)!=0);
		NextInstruction();
	}

	SarLabel:
	{
		uint32_t op1=GetOperand1();
		uint32_t op2=GetOperand2();
		SetOperand1AndFlagsWithCarry(((int32_t)op1)>>op2,((op1>>(op2-1))&1)!=0);
		NextInstruction();
	}

	NegLabel:
		SetOperand1AndFlagsWithCarry(-GetOperand1(),result!=0);
		NextInstruction();

	PushaLabel:
		for(int i=0;i<8;i++) RARVirtualMachineWrite32(self,self->registers[7]-4-i*4,self->registers[i]);
		self->registers[7]-=32;

		NextInstruction();

	PopaLabel:
		for(int i=0;i<8;i++) self->registers[i]=RARVirtualMachineRead32(self,self->registers[7]+28-i*4);
		NextInstruction();

	PushfLabel:
		self->registers[7]-=4;
		RARVirtualMachineWrite32(self,self->registers[7],flags);
		NextInstruction();

	PopfLabel:
		flags=RARVirtualMachineRead32(self,self->registers[7]);
		self->registers[7]+=4;
		NextInstruction();

	MovzxLabel:
		SetOperand1(GetOperand2());
		NextInstruction();

	MovsxLabel:
		SetOperand1(SignExtend(GetOperand2()));
		NextInstruction();

	XchgLabel:
	{
		uint32_t op1=GetOperand1();
		uint32_t op2=GetOperand2();
		SetOperand1(op2);
		SetOperand2(op1);
		NextInstruction();
	}

	MulLabel:
		SetOperand1(GetOperand1()*GetOperand2());
		NextInstruction();

	DivLabel:
	{
		uint32_t denominator=GetOperand2();
		if(denominator!=0) SetOperand1(GetOperand1()/denominator);
		NextInstruction();
	}

	AdcLabel:
	{
		uint32_t term1=GetOperand1();
		uint32_t carry=flags&CarryFlag;
		SetOperand1AndFlagsWithCarry(term1+GetOperand2()+carry,result<term1 || result==term1 && carry);
		NextInstruction();
	}
	AdcByteLabel:
	{
		uint32_t term1=GetOperand1();
		uint32_t carry=flags&CarryFlag;
		SetOperand1AndFlagsWithCarry(term1+GetOperand2()+carry&0xff,result<term1 || result==term1 && carry); // Does not correctly set sign bit.
		NextInstruction();
	}

	SbbLabel:
	{
		uint32_t term1=GetOperand1();
		uint32_t carry=flags&CarryFlag;
		SetOperand1AndFlagsWithCarry(term1-GetOperand2()-carry,result>term1 || result==term1 && carry);
		NextInstruction();
	}
	SbbByteLabel:
	{
		uint32_t term1=GetOperand1();
		uint32_t carry=flags&CarryFlag;
		SetOperand1AndFlagsWithCarry(term1-GetOperand2()-carry&0xff,result>term1 || result==term1 && carry); // Does not correctly set sign bit.
		NextInstruction();
	}

	PrintLabel:
		NextInstruction();

	return false;
}

static uint32_t RegisterGetter0_32(RARVirtualMachine *self,uint32_t value) { return self->registers[0]; }
static uint32_t RegisterGetter1_32(RARVirtualMachine *self,uint32_t value) { return self->registers[1]; }
static uint32_t RegisterGetter2_32(RARVirtualMachine *self,uint32_t value) { return self->registers[2]; }
static uint32_t RegisterGetter3_32(RARVirtualMachine *self,uint32_t value) { return self->registers[3]; }
static uint32_t RegisterGetter4_32(RARVirtualMachine *self,uint32_t value) { return self->registers[4]; }
static uint32_t RegisterGetter5_32(RARVirtualMachine *self,uint32_t value) { return self->registers[5]; }
static uint32_t RegisterGetter6_32(RARVirtualMachine *self,uint32_t value) { return self->registers[6]; }
static uint32_t RegisterGetter7_32(RARVirtualMachine *self,uint32_t value) { return self->registers[7]; }
static uint32_t RegisterGetter0_8(RARVirtualMachine *self,uint32_t value) { return self->registers[0]&0xff; }
static uint32_t RegisterGetter1_8(RARVirtualMachine *self,uint32_t value) { return self->registers[1]&0xff; }
static uint32_t RegisterGetter2_8(RARVirtualMachine *self,uint32_t value) { return self->registers[2]&0xff; }
static uint32_t RegisterGetter3_8(RARVirtualMachine *self,uint32_t value) { return self->registers[3]&0xff; }
static uint32_t RegisterGetter4_8(RARVirtualMachine *self,uint32_t value) { return self->registers[4]&0xff; }
static uint32_t RegisterGetter5_8(RARVirtualMachine *self,uint32_t value) { return self->registers[5]&0xff; }
static uint32_t RegisterGetter6_8(RARVirtualMachine *self,uint32_t value) { return self->registers[6]&0xff; }
static uint32_t RegisterGetter7_8(RARVirtualMachine *self,uint32_t value) { return self->registers[7]&0xff; }

static uint32_t RegisterIndirectGetter0_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,self->registers[0]); }
static uint32_t RegisterIndirectGetter1_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,self->registers[1]); }
static uint32_t RegisterIndirectGetter2_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,self->registers[2]); }
static uint32_t RegisterIndirectGetter3_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,self->registers[3]); }
static uint32_t RegisterIndirectGetter4_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,self->registers[4]); }
static uint32_t RegisterIndirectGetter5_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,self->registers[5]); }
static uint32_t RegisterIndirectGetter6_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,self->registers[6]); }
static uint32_t RegisterIndirectGetter7_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,self->registers[7]); }
static uint32_t RegisterIndirectGetter0_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,self->registers[0]); }
static uint32_t RegisterIndirectGetter1_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,self->registers[1]); }
static uint32_t RegisterIndirectGetter2_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,self->registers[2]); }
static uint32_t RegisterIndirectGetter3_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,self->registers[3]); }
static uint32_t RegisterIndirectGetter4_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,self->registers[4]); }
static uint32_t RegisterIndirectGetter5_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,self->registers[5]); }
static uint32_t RegisterIndirectGetter6_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,self->registers[6]); }
static uint32_t RegisterIndirectGetter7_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,self->registers[7]); }

static uint32_t IndexedAbsoluteGetter0_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,value+self->registers[0]); }
static uint32_t IndexedAbsoluteGetter1_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,value+self->registers[1]); }
static uint32_t IndexedAbsoluteGetter2_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,value+self->registers[2]); }
static uint32_t IndexedAbsoluteGetter3_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,value+self->registers[3]); }
static uint32_t IndexedAbsoluteGetter4_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,value+self->registers[4]); }
static uint32_t IndexedAbsoluteGetter5_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,value+self->registers[5]); }
static uint32_t IndexedAbsoluteGetter6_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,value+self->registers[6]); }
static uint32_t IndexedAbsoluteGetter7_32(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead32(self,value+self->registers[7]); }
static uint32_t IndexedAbsoluteGetter0_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,value+self->registers[0]); }
static uint32_t IndexedAbsoluteGetter1_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,value+self->registers[1]); }
static uint32_t IndexedAbsoluteGetter2_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,value+self->registers[2]); }
static uint32_t IndexedAbsoluteGetter3_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,value+self->registers[3]); }
static uint32_t IndexedAbsoluteGetter4_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,value+self->registers[4]); }
static uint32_t IndexedAbsoluteGetter5_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,value+self->registers[5]); }
static uint32_t IndexedAbsoluteGetter6_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,value+self->registers[6]); }
static uint32_t IndexedAbsoluteGetter7_8(RARVirtualMachine *self,uint32_t value) { return RARVirtualMachineRead8(self,value+self->registers[7]); }

// Note: Absolute addressing is pre-masked in PrepareRAROpcodes.
static uint32_t AbsoluteGetter_32(RARVirtualMachine *self,uint32_t value) { return _RARRead32(&self->memory[value]); }
static uint32_t AbsoluteGetter_8(RARVirtualMachine *self,uint32_t value) { return self->memory[value]; }
static uint32_t ImmediateGetter(RARVirtualMachine *self,uint32_t value) { return value; }

static void RegisterSetter0_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[0]=data; }
static void RegisterSetter1_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[1]=data; }
static void RegisterSetter2_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[2]=data; }
static void RegisterSetter3_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[3]=data; }
static void RegisterSetter4_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[4]=data; }
static void RegisterSetter5_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[5]=data; }
static void RegisterSetter6_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[6]=data; }
static void RegisterSetter7_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[7]=data; }
static void RegisterSetter0_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[0]=data&0xff; }
static void RegisterSetter1_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[1]=data&0xff; }
static void RegisterSetter2_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[2]=data&0xff; }
static void RegisterSetter3_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[3]=data&0xff; }
static void RegisterSetter4_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[4]=data&0xff; }
static void RegisterSetter5_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[5]=data&0xff; }
static void RegisterSetter6_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[6]=data&0xff; }
static void RegisterSetter7_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->registers[7]=data&0xff; }

static void RegisterIndirectSetter0_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,self->registers[0],data); }
static void RegisterIndirectSetter1_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,self->registers[1],data); }
static void RegisterIndirectSetter2_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,self->registers[2],data); }
static void RegisterIndirectSetter3_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,self->registers[3],data); }
static void RegisterIndirectSetter4_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,self->registers[4],data); }
static void RegisterIndirectSetter5_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,self->registers[5],data); }
static void RegisterIndirectSetter6_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,self->registers[6],data); }
static void RegisterIndirectSetter7_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,self->registers[7],data); }
static void RegisterIndirectSetter0_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,self->registers[0],data); }
static void RegisterIndirectSetter1_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,self->registers[1],data); }
static void RegisterIndirectSetter2_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,self->registers[2],data); }
static void RegisterIndirectSetter3_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,self->registers[3],data); }
static void RegisterIndirectSetter4_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,self->registers[4],data); }
static void RegisterIndirectSetter5_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,self->registers[5],data); }
static void RegisterIndirectSetter6_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,self->registers[6],data); }
static void RegisterIndirectSetter7_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,self->registers[7],data); }

static void IndexedAbsoluteSetter0_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,value+self->registers[0],data); }
static void IndexedAbsoluteSetter1_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,value+self->registers[1],data); }
static void IndexedAbsoluteSetter2_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,value+self->registers[2],data); }
static void IndexedAbsoluteSetter3_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,value+self->registers[3],data); }
static void IndexedAbsoluteSetter4_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,value+self->registers[4],data); }
static void IndexedAbsoluteSetter5_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,value+self->registers[5],data); }
static void IndexedAbsoluteSetter6_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,value+self->registers[6],data); }
static void IndexedAbsoluteSetter7_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite32(self,value+self->registers[7],data); }
static void IndexedAbsoluteSetter0_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,value+self->registers[0],data); }
static void IndexedAbsoluteSetter1_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,value+self->registers[1],data); }
static void IndexedAbsoluteSetter2_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,value+self->registers[2],data); }
static void IndexedAbsoluteSetter3_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,value+self->registers[3],data); }
static void IndexedAbsoluteSetter4_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,value+self->registers[4],data); }
static void IndexedAbsoluteSetter5_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,value+self->registers[5],data); }
static void IndexedAbsoluteSetter6_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,value+self->registers[6],data); }
static void IndexedAbsoluteSetter7_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { RARVirtualMachineWrite8(self,value+self->registers[7],data); }

// Note: Absolute addressing is pre-masked in PrepareRAROpcodes.
static void AbsoluteSetter_32(RARVirtualMachine *self,uint32_t value,uint32_t data) { _RARWrite32(&self->memory[value],data); }
static void AbsoluteSetter_8(RARVirtualMachine *self,uint32_t value,uint32_t data) { self->memory[value]=data; }

static RARGetterFunction OperandGetters_32[RARNumberOfAddressingModes]=
{
	[RARRegisterAddressingMode(0)]=RegisterGetter0_32,
	[RARRegisterAddressingMode(1)]=RegisterGetter1_32,
	[RARRegisterAddressingMode(2)]=RegisterGetter2_32,
	[RARRegisterAddressingMode(3)]=RegisterGetter3_32,
	[RARRegisterAddressingMode(4)]=RegisterGetter4_32,
	[RARRegisterAddressingMode(5)]=RegisterGetter5_32,
	[RARRegisterAddressingMode(6)]=RegisterGetter6_32,
	[RARRegisterAddressingMode(7)]=RegisterGetter7_32,
	[RARRegisterIndirectAddressingMode(0)]=RegisterIndirectGetter0_32,
	[RARRegisterIndirectAddressingMode(1)]=RegisterIndirectGetter1_32,
	[RARRegisterIndirectAddressingMode(2)]=RegisterIndirectGetter2_32,
	[RARRegisterIndirectAddressingMode(3)]=RegisterIndirectGetter3_32,
	[RARRegisterIndirectAddressingMode(4)]=RegisterIndirectGetter4_32,
	[RARRegisterIndirectAddressingMode(5)]=RegisterIndirectGetter5_32,
	[RARRegisterIndirectAddressingMode(6)]=RegisterIndirectGetter6_32,
	[RARRegisterIndirectAddressingMode(7)]=RegisterIndirectGetter7_32,
	[RARIndexedAbsoluteAddressingMode(0)]=IndexedAbsoluteGetter0_32,
	[RARIndexedAbsoluteAddressingMode(1)]=IndexedAbsoluteGetter1_32,
	[RARIndexedAbsoluteAddressingMode(2)]=IndexedAbsoluteGetter2_32,
	[RARIndexedAbsoluteAddressingMode(3)]=IndexedAbsoluteGetter3_32,
	[RARIndexedAbsoluteAddressingMode(4)]=IndexedAbsoluteGetter4_32,
	[RARIndexedAbsoluteAddressingMode(5)]=IndexedAbsoluteGetter5_32,
	[RARIndexedAbsoluteAddressingMode(6)]=IndexedAbsoluteGetter6_32,
	[RARIndexedAbsoluteAddressingMode(7)]=IndexedAbsoluteGetter7_32,
	[RARAbsoluteAddressingMode]=AbsoluteGetter_32,
	[RARImmediateAddressingMode]=ImmediateGetter,
};

static RARGetterFunction OperandGetters_8[RARNumberOfAddressingModes]=
{
	[RARRegisterAddressingMode(0)]=RegisterGetter0_8,
	[RARRegisterAddressingMode(1)]=RegisterGetter1_8,
	[RARRegisterAddressingMode(2)]=RegisterGetter2_8,
	[RARRegisterAddressingMode(3)]=RegisterGetter3_8,
	[RARRegisterAddressingMode(4)]=RegisterGetter4_8,
	[RARRegisterAddressingMode(5)]=RegisterGetter5_8,
	[RARRegisterAddressingMode(6)]=RegisterGetter6_8,
	[RARRegisterAddressingMode(7)]=RegisterGetter7_8,
	[RARRegisterIndirectAddressingMode(0)]=RegisterIndirectGetter0_8,
	[RARRegisterIndirectAddressingMode(1)]=RegisterIndirectGetter1_8,
	[RARRegisterIndirectAddressingMode(2)]=RegisterIndirectGetter2_8,
	[RARRegisterIndirectAddressingMode(3)]=RegisterIndirectGetter3_8,
	[RARRegisterIndirectAddressingMode(4)]=RegisterIndirectGetter4_8,
	[RARRegisterIndirectAddressingMode(5)]=RegisterIndirectGetter5_8,
	[RARRegisterIndirectAddressingMode(6)]=RegisterIndirectGetter6_8,
	[RARRegisterIndirectAddressingMode(7)]=RegisterIndirectGetter7_8,
	[RARIndexedAbsoluteAddressingMode(0)]=IndexedAbsoluteGetter0_8,
	[RARIndexedAbsoluteAddressingMode(1)]=IndexedAbsoluteGetter1_8,
	[RARIndexedAbsoluteAddressingMode(2)]=IndexedAbsoluteGetter2_8,
	[RARIndexedAbsoluteAddressingMode(3)]=IndexedAbsoluteGetter3_8,
	[RARIndexedAbsoluteAddressingMode(4)]=IndexedAbsoluteGetter4_8,
	[RARIndexedAbsoluteAddressingMode(5)]=IndexedAbsoluteGetter5_8,
	[RARIndexedAbsoluteAddressingMode(6)]=IndexedAbsoluteGetter6_8,
	[RARIndexedAbsoluteAddressingMode(7)]=IndexedAbsoluteGetter7_8,
	[RARAbsoluteAddressingMode]=AbsoluteGetter_8,
	[RARImmediateAddressingMode]=ImmediateGetter,
};


static RARSetterFunction OperandSetters_32[RARNumberOfAddressingModes]=
{
	[RARRegisterAddressingMode(0)]=RegisterSetter0_32,
	[RARRegisterAddressingMode(1)]=RegisterSetter1_32,
	[RARRegisterAddressingMode(2)]=RegisterSetter2_32,
	[RARRegisterAddressingMode(3)]=RegisterSetter3_32,
	[RARRegisterAddressingMode(4)]=RegisterSetter4_32,
	[RARRegisterAddressingMode(5)]=RegisterSetter5_32,
	[RARRegisterAddressingMode(6)]=RegisterSetter6_32,
	[RARRegisterAddressingMode(7)]=RegisterSetter7_32,
	[RARRegisterIndirectAddressingMode(0)]=RegisterIndirectSetter0_32,
	[RARRegisterIndirectAddressingMode(1)]=RegisterIndirectSetter1_32,
	[RARRegisterIndirectAddressingMode(2)]=RegisterIndirectSetter2_32,
	[RARRegisterIndirectAddressingMode(3)]=RegisterIndirectSetter3_32,
	[RARRegisterIndirectAddressingMode(4)]=RegisterIndirectSetter4_32,
	[RARRegisterIndirectAddressingMode(5)]=RegisterIndirectSetter5_32,
	[RARRegisterIndirectAddressingMode(6)]=RegisterIndirectSetter6_32,
	[RARRegisterIndirectAddressingMode(7)]=RegisterIndirectSetter7_32,
	[RARIndexedAbsoluteAddressingMode(0)]=IndexedAbsoluteSetter0_32,
	[RARIndexedAbsoluteAddressingMode(1)]=IndexedAbsoluteSetter1_32,
	[RARIndexedAbsoluteAddressingMode(2)]=IndexedAbsoluteSetter2_32,
	[RARIndexedAbsoluteAddressingMode(3)]=IndexedAbsoluteSetter3_32,
	[RARIndexedAbsoluteAddressingMode(4)]=IndexedAbsoluteSetter4_32,
	[RARIndexedAbsoluteAddressingMode(5)]=IndexedAbsoluteSetter5_32,
	[RARIndexedAbsoluteAddressingMode(6)]=IndexedAbsoluteSetter6_32,
	[RARIndexedAbsoluteAddressingMode(7)]=IndexedAbsoluteSetter7_32,
	[RARAbsoluteAddressingMode]=AbsoluteSetter_32,
};

static RARSetterFunction OperandSetters_8[RARNumberOfAddressingModes]=
{
	[RARRegisterAddressingMode(0)]=RegisterSetter0_8,
	[RARRegisterAddressingMode(1)]=RegisterSetter1_8,
	[RARRegisterAddressingMode(2)]=RegisterSetter2_8,
	[RARRegisterAddressingMode(3)]=RegisterSetter3_8,
	[RARRegisterAddressingMode(4)]=RegisterSetter4_8,
	[RARRegisterAddressingMode(5)]=RegisterSetter5_8,
	[RARRegisterAddressingMode(6)]=RegisterSetter6_8,
	[RARRegisterAddressingMode(7)]=RegisterSetter7_8,
	[RARRegisterIndirectAddressingMode(0)]=RegisterIndirectSetter0_8,
	[RARRegisterIndirectAddressingMode(1)]=RegisterIndirectSetter1_8,
	[RARRegisterIndirectAddressingMode(2)]=RegisterIndirectSetter2_8,
	[RARRegisterIndirectAddressingMode(3)]=RegisterIndirectSetter3_8,
	[RARRegisterIndirectAddressingMode(4)]=RegisterIndirectSetter4_8,
	[RARRegisterIndirectAddressingMode(5)]=RegisterIndirectSetter5_8,
	[RARRegisterIndirectAddressingMode(6)]=RegisterIndirectSetter6_8,
	[RARRegisterIndirectAddressingMode(7)]=RegisterIndirectSetter7_8,
	[RARIndexedAbsoluteAddressingMode(0)]=IndexedAbsoluteSetter0_8,
	[RARIndexedAbsoluteAddressingMode(1)]=IndexedAbsoluteSetter1_8,
	[RARIndexedAbsoluteAddressingMode(2)]=IndexedAbsoluteSetter2_8,
	[RARIndexedAbsoluteAddressingMode(3)]=IndexedAbsoluteSetter3_8,
	[RARIndexedAbsoluteAddressingMode(4)]=IndexedAbsoluteSetter4_8,
	[RARIndexedAbsoluteAddressingMode(5)]=IndexedAbsoluteSetter5_8,
	[RARIndexedAbsoluteAddressingMode(6)]=IndexedAbsoluteSetter6_8,
	[RARIndexedAbsoluteAddressingMode(7)]=IndexedAbsoluteSetter7_8,
	[RARAbsoluteAddressingMode]=AbsoluteSetter_8,
};





// Instruction properties

#define RAR0OperandsFlag 0
#define RAR1OperandFlag 1
#define RAR2OperandsFlag 2
#define RAROperandsFlag 3
#define RARHasByteModeFlag 4
#define RARIsUnconditionalJumpFlag 8
#define RARIsRelativeJumpFlag 16
#define RARWritesFirstOperandFlag 32
#define RARWritesSecondOperandFlag 64
#define RARReadsStatusFlag 128
#define RARWritesStatusFlag 256

static const int InstructionFlags[40]=
{
	[RARMovInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag,
	[RARCmpInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesStatusFlag,
	[RARAddInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARSubInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARJzInstruction]=RAR1OperandFlag | RARIsUnconditionalJumpFlag | RARIsRelativeJumpFlag | RARReadsStatusFlag,
	[RARJnzInstruction]=RAR1OperandFlag | RARIsRelativeJumpFlag | RARReadsStatusFlag,
	[RARIncInstruction]=RAR1OperandFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARDecInstruction]=RAR1OperandFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARJmpInstruction]=RAR1OperandFlag | RARIsRelativeJumpFlag,
	[RARXorInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARAndInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RAROrInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARTestInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesStatusFlag,
	[RARJsInstruction]=RAR1OperandFlag | RARIsRelativeJumpFlag | RARReadsStatusFlag,
	[RARJnsInstruction]=RAR1OperandFlag | RARIsRelativeJumpFlag | RARReadsStatusFlag,
	[RARJbInstruction]=RAR1OperandFlag | RARIsRelativeJumpFlag | RARReadsStatusFlag,
	[RARJbeInstruction]=RAR1OperandFlag | RARIsRelativeJumpFlag | RARReadsStatusFlag,
	[RARJaInstruction]=RAR1OperandFlag | RARIsRelativeJumpFlag | RARReadsStatusFlag,
	[RARJaeInstruction]=RAR1OperandFlag | RARIsRelativeJumpFlag | RARReadsStatusFlag,
	[RARPushInstruction]=RAR1OperandFlag,
	[RARPopInstruction]=RAR1OperandFlag,
	[RARCallInstruction]=RAR1OperandFlag,
	[RARRetInstruction]=RAR0OperandsFlag | RARIsUnconditionalJumpFlag,
	[RARNotInstruction]=RAR1OperandFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag,
	[RARShlInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARShrInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARSarInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARNegInstruction]=RAR1OperandFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARWritesStatusFlag,
	[RARPushaInstruction]=RAR0OperandsFlag,
	[RARPopaInstruction]=RAR0OperandsFlag,
	[RARPushfInstruction]=RAR0OperandsFlag | RARReadsStatusFlag,
	[RARPopfInstruction]=RAR0OperandsFlag | RARWritesStatusFlag,
	[RARMovzxInstruction]=RAR2OperandsFlag | RARWritesFirstOperandFlag,
	[RARMovsxInstruction]=RAR2OperandsFlag | RARWritesFirstOperandFlag,
	[RARXchgInstruction]=RAR2OperandsFlag | RARWritesFirstOperandFlag | RARWritesSecondOperandFlag | RARHasByteModeFlag,
	[RARMulInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag,
	[RARDivInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag,
	[RARAdcInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARReadsStatusFlag | RARWritesStatusFlag,
	[RARSbbInstruction]=RAR2OperandsFlag | RARHasByteModeFlag | RARWritesFirstOperandFlag | RARReadsStatusFlag | RARWritesStatusFlag,
	[RARPrintInstruction]=RAR0OperandsFlag
};

int NumberOfRARInstructionOperands(unsigned int instruction)
{
	if(instruction>=RARNumberOfInstructions) return 0;
	return InstructionFlags[instruction]&RAROperandsFlag;
}

bool RARInstructionHasByteMode(unsigned int instruction)
{
	if(instruction>=RARNumberOfInstructions) return false;
	return (InstructionFlags[instruction]&RARHasByteModeFlag)!=0;
}

bool RARInstructionIsUnconditionalJump(unsigned int instruction)
{
	if(instruction>=RARNumberOfInstructions) return false;
	return (InstructionFlags[instruction]&RARIsUnconditionalJumpFlag)!=0;
}

bool RARInstructionIsRelativeJump(unsigned int instruction)
{
	if(instruction>=RARNumberOfInstructions) return false;
	return (InstructionFlags[instruction]&RARIsRelativeJumpFlag)!=0;
}

bool RARInstructionWritesFirstOperand(unsigned int instruction)
{
	if(instruction>=RARNumberOfInstructions) return false;
	return (InstructionFlags[instruction]&RARWritesFirstOperandFlag)!=0;
}

bool RARInstructionWritesSecondOperand(unsigned int instruction)
{
	if(instruction>=RARNumberOfInstructions) return false;
	return (InstructionFlags[instruction]&RARWritesSecondOperandFlag)!=0;
}






// Disassembling

char *DescribeRAROpcode(RAROpcode *opcode)
{
	static char string[128];

	int numoperands=NumberOfRARInstructionOperands(opcode->instruction);

	char *instruction=DescribeRARInstruction(opcode);
	strcpy(string,instruction);

	if(numoperands==0) return string;

	strcat(string,"        "+strlen(instruction));
	strcat(string,DescribeRAROperand1(opcode));

	if(numoperands==1) return string;

	strcat(string,", ");
	strcat(string,DescribeRAROperand2(opcode));

	return string;
}

char *DescribeRARInstruction(RAROpcode *opcode)
{
	static const char *InstructionNames[40]=
	{
		[RARMovInstruction]="mov",[RARCmpInstruction]="cmp",[RARAddInstruction]="add",[RARSubInstruction]="sub",
		[RARJzInstruction]="jz",[RARJnzInstruction]="jnz",[RARIncInstruction]="inc",[RARDecInstruction]="dec",
		[RARJmpInstruction]="jmp",[RARXorInstruction]="xor",[RARAndInstruction]="and",[RAROrInstruction]="or",
		[RARTestInstruction]="test",[RARJsInstruction]="js",[RARJnsInstruction]="jns",[RARJbInstruction]="jb",
		[RARJbeInstruction]="jbe",[RARJaInstruction]="ja",[RARJaeInstruction]="jae",[RARPushInstruction]="push",
		[RARPopInstruction]="pop",[RARCallInstruction]="call",[RARRetInstruction]="ret",[RARNotInstruction]="not",
		[RARShlInstruction]="shl",[RARShrInstruction]="shr",[RARSarInstruction]="sar",[RARNegInstruction]="neg",
		[RARPushaInstruction]="pusha",[RARPopaInstruction]="popa",[RARPushfInstruction]="pushf",[RARPopfInstruction]="popf",
		[RARMovzxInstruction]="movzx",[RARMovsxInstruction]="movsx",[RARXchgInstruction]="xchg",[RARMulInstruction]="mul",
		[RARDivInstruction]="div",[RARAdcInstruction]="adc",[RARSbbInstruction]="sbb",[RARPrintInstruction]="print"
	};

	if(opcode->instruction>=RARNumberOfInstructions) return "invalid";

	static char string[8];
	strcpy(string,InstructionNames[opcode->instruction]);
	if(opcode->bytemode) strcat(string,".b");
	return string;
}

static char *DescribeRAROperand(unsigned int addressingmode,uint32_t value)
{
	static char string[16];
	switch(addressingmode)
	{
		case RARRegisterAddressingMode(0): case RARRegisterAddressingMode(1):
		case RARRegisterAddressingMode(2): case RARRegisterAddressingMode(3):
		case RARRegisterAddressingMode(4): case RARRegisterAddressingMode(5):
		case RARRegisterAddressingMode(6): case RARRegisterAddressingMode(7):
			sprintf(string,"r%d",addressingmode-RARRegisterAddressingMode(0));
		break;


		case RARRegisterIndirectAddressingMode(0): case RARRegisterIndirectAddressingMode(1):
		case RARRegisterIndirectAddressingMode(2): case RARRegisterIndirectAddressingMode(3):
		case RARRegisterIndirectAddressingMode(4): case RARRegisterIndirectAddressingMode(5):
		case RARRegisterIndirectAddressingMode(6): case RARRegisterIndirectAddressingMode(7):
			sprintf(string,"(r%d)",addressingmode-RARRegisterIndirectAddressingMode(0));
		break;

		case RARIndexedAbsoluteAddressingMode(0): case RARIndexedAbsoluteAddressingMode(1):
		case RARIndexedAbsoluteAddressingMode(2): case RARIndexedAbsoluteAddressingMode(3):
		case RARIndexedAbsoluteAddressingMode(4): case RARIndexedAbsoluteAddressingMode(5):
		case RARIndexedAbsoluteAddressingMode(6): case RARIndexedAbsoluteAddressingMode(7):
			sprintf(string,"($%x+r%d)",value,addressingmode-RARIndexedAbsoluteAddressingMode(0));
		break;

		case RARAbsoluteAddressingMode:
			sprintf(string,"($%x)",value);
		break;

		case RARImmediateAddressingMode:
			sprintf(string,"$%x",value);
		break;
	}
	return string;
}

char *DescribeRAROperand1(RAROpcode *opcode)
{
	return DescribeRAROperand(opcode->addressingmode1,opcode->value1);
}

char *DescribeRAROperand2(RAROpcode *opcode)
{
	return DescribeRAROperand(opcode->addressingmode2,opcode->value2);
}
