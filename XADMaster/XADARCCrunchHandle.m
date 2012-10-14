#import "XADARCCrunchHandle.h"
#import "XADException.h"

@implementation XADARCCrunchHandle

-(id)initWithHandle:(CSHandle *)handle useFastHash:(BOOL)usefast
{
	return [self initWithHandle:handle length:CSHandleMaxLength useFastHash:usefast];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length useFastHash:(BOOL)usefast
{
	if((self=[super initWithHandle:handle length:length]))
	{
		fast=usefast;
	}
	return self;
}


-(void)resetByteStream
{
    sp=0;
    numfreecodes=4096-256;

	for(int i=0;i<256;i++) [self updateTableWithParent:-1 byteValue:i];

	int code=CSInputNextBitString(input,12);
	int byte=table[code].byte;

	stack[sp++]=byte;

	lastcode=code;
	lastbyte=byte;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!sp)
	{
		if(CSInputAtEOF(input)) CSByteStreamEOF(self);

		int code=CSInputNextBitString(input,12);

		XADARCCrunchEntry *entry=&table[code];

		if(!entry->used)
		{
			entry=&table[lastcode];
			stack[sp++]=lastbyte;
		}

		while(entry->parent!=-1)
		{
			if(sp>=4095) [XADException raiseDecrunchException];

			stack[sp++]=entry->byte;
			entry=&table[entry->parent];
		}

		uint8_t byte=entry->byte;
		stack[sp++]=byte;

		if(numfreecodes!=0)
		{
			[self updateTableWithParent:lastcode byteValue:byte];
			numfreecodes--;
		}

		lastcode=code;
		lastbyte=byte;
	}

	return stack[--sp];
}

-(void)updateTableWithParent:(int)parent byteValue:(int)byte
{
	// Find hash table position.
	int index;
	if(fast) index=(((parent+byte)&0xffff)*15073)&0xfff;
	else
	{
		index=((parent+byte)|0x0800)&0xffff;
		index=(index*index>>6)&0xfff;
	}

	if(table[index].used) // Check for collision.
	{
		// Go through the list of already marked collisions.
		while(table[index].next) index=table[index].next;

		// Then skip ahead, and do a linear search for an unused index.
		int next=(index+101)&0xfff;
		while(table[next].used) next=(next+1)&0xfff;

		// Save the new index so we can skip the process next time.
		table[index].next=next;

		index=next;
	}

	table[index].used=YES;
	table[index].next=0;
	table[index].parent=parent;
	table[index].byte=byte;
}

@end
