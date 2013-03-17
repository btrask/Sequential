#import "XADDiskDoublerMethod2Handle.h"
#import "XADException.h"

@implementation XADDiskDoublerMethod2Handle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length numberOfTrees:(int)num
{
	if((self=[super initWithHandle:handle length:length]))
	{
		numtrees=num;
	}
	return self;
}

-(void)resetByteStream
{
	for(int i=0;i<numtrees;i++)
	{
		for(int j=0;j<256;j++)
		{
			trees[i].parents[2*j]=j;
			trees[i].parents[2*j+1]=j;
			trees[i].leftchildren[j]=j*2;
			trees[i].rightchildren[j]=j*2+1;
		}
	}

	currtree=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int node=1;
	for(;;)
	{
		int bit=CSInputNextBit(input);

		if(bit==1) node=trees[currtree].rightchildren[node];
		else node=trees[currtree].leftchildren[node];

		if(node>=0x100)
		{
			int byte=node-0x100;

			[self updateStateForByte:byte];

			return byte;
		}
	}
}

-(void)updateStateForByte:(int)byte
{
	uint8_t *parents=trees[currtree].parents;
	uint16_t *leftchildren=trees[currtree].leftchildren;
	uint16_t *rightchildren=trees[currtree].rightchildren;

	int node=byte+0x100;
	for(;;)
	{
		int parent=parents[node];
		if(parent==1) break;

		int grandparent=parents[parent];

		int uncle=leftchildren[grandparent];
		if(uncle==parent)
		{
			uncle=rightchildren[grandparent];
			rightchildren[grandparent]=node;
		}
		else
		{
			leftchildren[grandparent]=node;
		}

		if(leftchildren[parent]!=node) rightchildren[parent]=uncle;
		else leftchildren[parent]=uncle;

		parents[node]=grandparent;
		parents[uncle]=parent;

		node=grandparent;
		if(node==1) break;
	}

	currtree=byte%numtrees;
}

@end
