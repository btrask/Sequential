#import "PPMdVariantH.h"

static void RestartModel(PPMdModelVariantH *self);

static void UpdateModel(PPMdModelVariantH *self);
static PPMdContext *CreateSuccessors(PPMdModelVariantH *self,BOOL skip,PPMdState *state);

static void DecodeBinSymbolVariantH(PPMdContext *self,PPMdModelVariantH *model);
static void DecodeSymbol1VariantH(PPMdContext *self,PPMdModelVariantH *model);
static void DecodeSymbol2VariantH(PPMdContext *self,PPMdModelVariantH *model);

void StartPPMdModelVariantH(PPMdModelVariantH *self,CSInputBuffer *input,
PPMdSubAllocatorVariantH *alloc,int maxorder,BOOL sevenzip)
{
	if(sevenzip)
	{
		CSInputSkipBytes(input,1);
		InitializeRangeCoder(&self->core.coder,input,NO,0);
	}
	else InitializeRangeCoder(&self->core.coder,input,YES,0x8000);

	self->alloc=alloc;
	self->core.alloc=&alloc->core;

	self->core.RescalePPMdContext=RescalePPMdContext;

	self->MaxOrder=maxorder;
	self->SevenZip=sevenzip;
	self->core.EscCount=1;

	self->NS2BSIndx[0]=2*0;
	self->NS2BSIndx[1]=2*1;
	for(int i=2;i<11;i++) self->NS2BSIndx[i]=2*2;
	for(int i=11;i<256;i++) self->NS2BSIndx[i]=2*3;

	for(int i=0;i<3;i++) self->NS2Indx[i]=i;
	int m=3,k=1,step=1;
	for(int i=3;i<256;i++)
	{
		self->NS2Indx[i]=m;
		if(!--k) { m++; step++; k=step; }
	}

	memset(self->HB2Flag,0,0x40);
	memset(self->HB2Flag+0x40,0x08,0x100-0x40);

	self->DummySEE2Cont.Shift=PERIOD_BITS;

	RestartModel(self);
}

static void RestartModel(PPMdModelVariantH *self)
{
	InitSubAllocator(self->core.alloc);

	memset(self->core.CharMask,0,sizeof(self->core.CharMask));

	self->core.PrevSuccess=0;
	self->core.OrderFall=self->MaxOrder;
	self->core.RunLength=self->core.InitRL=-((self->MaxOrder<12)?self->MaxOrder:12)-1;

	self->MaxContext=self->MinContext=NewPPMdContext(&self->core); // AllocContext()
	self->MaxContext->LastStateIndex=255;
	self->MaxContext->SummFreq=257;
	self->MaxContext->States=AllocUnits(self->core.alloc,256/2);

	PPMdState *maxstates=PPMdContextStates(self->MaxContext,&self->core);
	for(int i=0;i<256;i++)
	{
		maxstates[i].Symbol=i;
		maxstates[i].Freq=1;
		maxstates[i].Successor=0;
	}

	self->core.FoundState=PPMdContextStates(self->MaxContext,&self->core);

	static const uint16_t InitBinEsc[8]={0x3cdd,0x1f3f,0x59bf,0x48f3,0x64a1,0x5abc,0x6632,0x6051};

	for(int i=0;i<128;i++)
	for(int k=0;k<8;k++)
	for(int m=0;m<64;m+=8)
	self->BinSumm[i][k+m]=BIN_SCALE-InitBinEsc[k]/(i+2);

	for(int i=0;i<25;i++)
	for(int k=0;k<16;k++)
	self->SEE2Cont[i][k]=MakeSEE2(5*i+10,4);
}



int NextPPMdVariantHByte(PPMdModelVariantH *self)
{
//NSLog(@"%x %x",self->core.coder.range,self->core.coder.code);
	if(self->MinContext->LastStateIndex!=0) DecodeSymbol1VariantH(self->MinContext,self);
	else DecodeBinSymbolVariantH(self->MinContext,self);

	while(!self->core.FoundState)
	{
		do
		{
			self->core.OrderFall++;
			self->MinContext=PPMdContextSuffix(self->MinContext,&self->core);
			if(!self->MinContext) return -1;
		}
		while(self->MinContext->LastStateIndex==self->core.LastMaskIndex);

		DecodeSymbol2VariantH(self->MinContext,self);
	}

	uint8_t byte=self->core.FoundState->Symbol;

	if(self->core.OrderFall==0&&(uint8_t *)PPMdStateSuccessor(self->core.FoundState,&self->core)>self->alloc->pText)
	{
		self->MinContext=self->MaxContext=PPMdStateSuccessor(self->core.FoundState,&self->core);
	}
	else
	{
		UpdateModel(self);
		if(self->core.EscCount==0) ClearPPMdModelMask(&self->core);
	}

	return byte;
}



static void UpdateModel(PPMdModelVariantH *self)
{
	PPMdState fs=*self->core.FoundState;
	PPMdState *state=NULL;

	if(fs.Freq<MAX_FREQ/4&&self->MinContext->Suffix)
	{
		PPMdContext *context=PPMdContextSuffix(self->MinContext,&self->core);
		if(context->LastStateIndex!=0)
		{
			state=PPMdContextStates(context,&self->core);

			if(state->Symbol!=fs.Symbol)
			{
				do state++;
				while(state->Symbol!=fs.Symbol);

				if(state[0].Freq>=state[-1].Freq)
				{
					SWAP(state[0],state[-1]);
					state--;
				}
			}

			if(state->Freq<MAX_FREQ-9)
			{
				state->Freq+=2;
				context->SummFreq+=2;
			}
		}
		else
		{
			state=PPMdContextOneState(context);
			if(state->Freq<32) state->Freq++;
		}
	}

	if(self->core.OrderFall==0)
	{
		self->MinContext=self->MaxContext=CreateSuccessors(self,YES,state);
		SetPPMdStateSuccessorPointer(self->core.FoundState,self->MinContext,&self->core);
		if(!self->MinContext) goto RESTART_MODEL;
		return;
	}

	*self->alloc->pText++=fs.Symbol;
	PPMdContext *Successor=(PPMdContext *)self->alloc->pText;

	if(self->alloc->pText>=self->alloc->UnitsStart) goto RESTART_MODEL;

	if(fs.Successor)
	{
		if((uint8_t *)PPMdStateSuccessor(&fs,&self->core)<=self->alloc->pText)
		{
			SetPPMdStateSuccessorPointer(&fs,CreateSuccessors(self,NO,state),&self->core);
			if(!fs.Successor) goto RESTART_MODEL;
		}
		if(--self->core.OrderFall==0)
		{
			Successor=PPMdStateSuccessor(&fs,&self->core);
			if(self->MaxContext!=self->MinContext) self->alloc->pText--;
		}
	}
	else
	{
		SetPPMdStateSuccessorPointer(self->core.FoundState,Successor,&self->core);
		SetPPMdStateSuccessorPointer(&fs,self->MinContext,&self->core);
    }

	int minnum=self->MinContext->LastStateIndex+1;
	int s0=self->MinContext->SummFreq-minnum-(fs.Freq-1);

	for(PPMdContext *currcontext=self->MaxContext;currcontext!=self->MinContext;currcontext=PPMdContextSuffix(currcontext,&self->core))
	{
		int currnum=currcontext->LastStateIndex+1;
		if(currnum!=1)
		{
			if((currnum&1)==0)
			{
				currcontext->States=ExpandUnits(self->core.alloc,currcontext->States,currnum>>1);
				if(!currcontext->States) goto RESTART_MODEL;
			}
			if(4*currnum<=minnum&&currcontext->SummFreq<=8*currnum) currcontext->SummFreq+=2;
			if(2*currnum<minnum) currcontext->SummFreq++;
		}
		else
		{
			PPMdState *states=OffsetToPointer(self->core.alloc,AllocUnits(self->core.alloc,1));
			if(!states) goto RESTART_MODEL;
			states[0]=*(PPMdContextOneState(currcontext));
			SetPPMdContextStatesPointer(currcontext,states,&self->core);

			if(states[0].Freq<MAX_FREQ/4-1) states[0].Freq*=2;
			else states[0].Freq=MAX_FREQ-4;

			currcontext->SummFreq=states[0].Freq+self->core.InitEsc+(minnum>3?1:0);
		}

		unsigned int cf=2*fs.Freq*(currcontext->SummFreq+6);
		unsigned int sf=s0+currcontext->SummFreq;
		unsigned int freq;

		if(cf<6*sf)
		{
			if(cf>=4*sf) freq=3;
			else if(cf>sf) freq=2;
			else freq=1;
			currcontext->SummFreq+=3;
		}
		else
		{
			if(cf>=15*sf) freq=7;
			else if(cf>=12*sf) freq=6;
			else if(cf>=9*sf) freq=5;
			else freq=4;
			currcontext->SummFreq+=freq;
		}

		PPMdState *currstates=PPMdContextStates(currcontext,&self->core);
		PPMdState *new=&currstates[currnum];
		SetPPMdStateSuccessorPointer(new,Successor,&self->core);
		new->Symbol=fs.Symbol;
		new->Freq=freq;
		currcontext->LastStateIndex=currnum;
	}

	self->MaxContext=self->MinContext=PPMdStateSuccessor(&fs,&self->core);

	return;

	RESTART_MODEL:
	RestartModel(self);
	self->core.EscCount=0;
}

static PPMdContext *CreateSuccessors(PPMdModelVariantH *self,BOOL skip,PPMdState *state)
{
	PPMdContext *context=self->MinContext,*upbranch=PPMdStateSuccessor(self->core.FoundState,&self->core);
	PPMdState *statelist[MAX_O];
	int n=0;

	if(!skip)
	{
		statelist[n++]=self->core.FoundState;
		if(!context->Suffix) goto skip;
	}

	if(state)
	{
		context=PPMdContextSuffix(context,&self->core);
		if(PPMdStateSuccessor(state,&self->core)!=upbranch)
		{
			context=PPMdStateSuccessor(state,&self->core);
			goto skip;
		}
		statelist[n++]=state;
		if(!context->Suffix) goto skip;
	}

	do
	{
		context=PPMdContextSuffix(context,&self->core);
		if(context->LastStateIndex!=0)
		{
			state=PPMdContextStates(context,&self->core);
			while(state->Symbol!=self->core.FoundState->Symbol) state++;
		}
		else state=PPMdContextOneState(context);

		if(PPMdStateSuccessor(state,&self->core)!=upbranch)
		{
			context=PPMdStateSuccessor(state,&self->core);
			break;
		}
		statelist[n++]=state;
	}
	while(context->Suffix);

	skip:

	if(n==0) return context;

	PPMdState upstate;

	upstate.Symbol=*(uint8_t *)upbranch;
	SetPPMdStateSuccessorPointer(&upstate,(PPMdContext *)(((uint8_t *)upbranch)+1),&self->core);

	if(context->LastStateIndex!=0)
	{
		state=PPMdContextStates(context,&self->core);
		while(state->Symbol!=upstate.Symbol) state++;

		int cf=state->Freq-1;
		int s0=context->SummFreq-context->LastStateIndex-1-cf;

		if(2*cf<=s0)
		{
			if(5*cf>s0) upstate.Freq=2;
			else upstate.Freq=1;
		}
		else upstate.Freq=1+((2*cf+3*s0-1)/(2*s0));
    }
	else upstate.Freq=PPMdContextOneState(context)->Freq;

	for(int i=n-1;i>=0;i--)
	{
		context=NewPPMdContextAsChildOf(&self->core,context,statelist[i],&upstate);
		if(!context) return NULL;
	}

    return context;
}




static void DecodeBinSymbolVariantH(PPMdContext *self,PPMdModelVariantH *model)
{
	PPMdState *rs=PPMdContextOneState(self);

	model->HiBitsFlag=model->HB2Flag[model->core.FoundState->Symbol];

	uint16_t *bs=&model->BinSumm[rs->Freq-1][
	model->core.PrevSuccess+model->NS2BSIndx[PPMdContextSuffix(self,&model->core)->LastStateIndex]+
	model->HiBitsFlag+2*model->HB2Flag[rs->Symbol]+((model->core.RunLength>>26)&0x20)];

	PPMdDecodeBinSymbol(self,&model->core,bs,128,model->SevenZip);
}

static void DecodeSymbol1VariantH(PPMdContext *self,PPMdModelVariantH *model)
{
	int lastsym=PPMdDecodeSymbol1(self,&model->core,NO);
	if(lastsym>=0)
	{
		model->HiBitsFlag=model->HB2Flag[lastsym];
	}
}

static void DecodeSymbol2VariantH(PPMdContext *self,PPMdModelVariantH *model)
{
	int diff=self->LastStateIndex-model->core.LastMaskIndex;
	SEE2Context *see;
	if(self->LastStateIndex!=255)
	{
		see=&model->SEE2Cont[model->NS2Indx[diff-1]][
			+(diff<PPMdContextSuffix(self,&model->core)->LastStateIndex-self->LastStateIndex?1:0)
			+(self->SummFreq<11*(self->LastStateIndex+1)?2:0)
			+(model->core.LastMaskIndex+1>diff?4:0)
			+model->HiBitsFlag];
		model->core.scale=GetSEE2Mean(see);
	}
	else
	{
		model->core.scale=1;
		see=&model->DummySEE2Cont;
	}

	PPMdDecodeSymbol2(self,&model->core,see);
}
