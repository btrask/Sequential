#import "XADPPMdHandles.h"




@implementation XADPPMdVariantGHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if((self=[super initWithHandle:handle length:length]))
	{
		alloc=CreateSubAllocatorVariantG(suballocsize);
		max=maxorder;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorVariantG(alloc);
	[super dealloc];
}

-(void)resetByteStream { StartPPMdModelVariantG(&model,(PPMdReadFunction *)CSInputNextByte,input,&alloc->core,max,NO); }

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantGByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end




@implementation XADPPMdVariantHHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if((self=[super initWithHandle:handle length:length]))
	{
		alloc=CreateSubAllocatorVariantH(suballocsize);
		max=maxorder;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorVariantH(alloc);
	[super dealloc];
}

-(void)resetByteStream { StartPPMdModelVariantH(&model,(PPMdReadFunction *)CSInputNextByte,input,alloc,max,NO); }

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantHByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end




@implementation XADPPMdVariantIHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize modelRestorationMethod:mrmethod];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize modelRestorationMethod:(int)mrmethod
{
	if((self=[super initWithHandle:handle length:length]))
	{
		alloc=CreateSubAllocatorVariantI(suballocsize);
		max=maxorder;
		method=mrmethod;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorVariantI(alloc);
	[super dealloc];
}

-(void)resetByteStream { StartPPMdModelVariantI(&model,(PPMdReadFunction *)CSInputNextByte,input,alloc,max,method); }

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantIByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end




@implementation XADStuffItXBrimstoneHandle

-(id)initWithHandle:(CSHandle *)handle maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	return [self initWithHandle:handle length:CSHandleMaxLength maxOrder:maxorder subAllocSize:suballocsize];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length maxOrder:(int)maxorder subAllocSize:(int)suballocsize
{
	if((self=[super initWithHandle:handle length:length]))
	{
		alloc=CreateSubAllocatorBrimstone(suballocsize);
		max=maxorder;
	}
	return self;
}

-(void)dealloc
{
	FreeSubAllocatorBrimstone(alloc);
	[super dealloc];
}

-(void)resetByteStream { StartPPMdModelVariantG(&model,(PPMdReadFunction *)CSInputNextByte,input,&alloc->core,max,YES); }

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=NextPPMdVariantGByte(&model);
	if(byte<0) CSByteStreamEOF(self);
	return byte;
}

@end



@implementation XAD7ZipPPMdHandle

-(void)resetByteStream { StartPPMdModelVariantH(&model,(PPMdReadFunction *)CSInputNextByte,input,alloc,max,YES); }

@end
