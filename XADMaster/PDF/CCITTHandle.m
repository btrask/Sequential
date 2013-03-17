#import "CCITTHandle.h"

#define EOL -1
#define EOFB -2
#define UNCOMPRESSED -3

#define PASS 0
#define HORIZONTAL 1
#define VERTICAL_0 2
#define VERTICAL_L1 3
#define VERTICAL_L2 4
#define VERTICAL_L3 5
#define VERTICAL_R1 6
#define VERTICAL_R2 7
#define VERTICAL_R3 8

typedef int CCITTCodeTable[][2];
//typedef CCITTCodeTable *CCITTCodeTablePointer;
typedef int (*CCITTCodeTablePointer)[2];

//static CCITTCodeTable T41DWhiteCodeTable;
static int T41DWhiteCodeTable[][2];
static int T41DBlackCodeTable[][2];
//static int T42DCodeTable[][2];
static int T62DCodeTable[][2];

NSString *CCITTCodeException=@"CCITTCodeException";

@implementation CCITTFaxHandle

static int ReadLengthWithCodeTable(CSInputBuffer *input,XADPrefixCode *prefixcode)
{
	int code,len=0;

	do
	{
		code=CSInputNextSymbolUsingCode(input,prefixcode);
		if(code<0)
		{
			if(len) [NSException raise:CCITTCodeException format:@"Invalid EOL code in bitstream"];
			else return code;
		}
		else
		{
			len+=code;
		}
	}
	while(code>=64);

	return len;
}



-(id)initWithHandle:(CSHandle *)handle columns:(int)cols white:(int)whitevalue
{
	if(self=[super initWithHandle:handle])
	{
		columns=cols;
		white=whitevalue;
	}
	return self;
}

-(void)resetByteStream
{
	bitsleft=0;
	column=0;
	[self startNewLine];
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	int byte=0;
	int bitsempty=8;

	while(bitsempty && column<columns)
	{
		while(!bitsleft) [self findNextSpanLength];

		if(bitsleft>=bitsempty)
		{
			if(colour!=white) byte|=0xff>>(8-bitsempty);
			bitsleft-=bitsempty;
			column+=bitsempty;
			bitsempty=0;
		}
		else
		{
			if(colour!=white) byte|=(0xff>>(8-bitsleft))<<(bitsempty-bitsleft);
			bitsempty-=bitsleft;
			column+=bitsleft;
			bitsleft=0;
		}
	}

	if(column>=columns)
	{
		//if(bitsleft) // overrun
		[self startNewLine];
		bitsleft=0;
		column=0;
	}

	return byte;
}

-(void)startNewLine {}

-(void)findNextSpanLength {}

@end



@implementation CCITTFaxT41DHandle
static int line=0;
-(id)initWithHandle:(CSHandle *)handle columns:(int)cols white:(int)whitevalue
{
	if(self=[super initWithHandle:handle columns:cols white:whitevalue])
	{
		whitecode=[[XADPrefixCode alloc] initWithStaticTable:T41DWhiteCodeTable];
		blackcode=[[XADPrefixCode alloc] initWithStaticTable:T41DBlackCodeTable];
line=0;
	}
	return self;
}

-(void)dealloc
{
	[whitecode release];
	[blackcode release];
	[super dealloc];
}

-(void)startNewLine
{
	colour=1;
}

-(void)findNextSpanLength
{
	int nextcolour=colour^1;

	int code;
	if(nextcolour==0) code=ReadLengthWithCodeTable(input,blackcode);
	else code=ReadLengthWithCodeTable(input,whitecode);

	if(code==EOL)
	{
		if(column==0) return;
		else bitsleft=columns-column;
	}
	else if(code==UNCOMPRESSED)
	{
		[NSException raise:CCITTCodeException format:@"Uncompressed mode not implemented"];
	}
	else
	{
		bitsleft=code;
	}

	colour=nextcolour;
}

@end



@implementation CCITTFaxT6Handle

void FindNextOldChangeOfColorAndLargerThan(CCITTFaxT6Handle *self,int column,int pos)
{
	if(self->previndex>0) self->previndex--; // Have to backtrack at most one step.
	if(pos==0) pos=-1; // Kludge because technically the imaginary first change is at -1.

	if((self->previndex&1)==column) self->previndex++; // Align to correct colour.

	while(self->previndex<self->numprevchanges&&self->prevchanges[self->previndex]<=pos)
	{
		self->previndex+=2;
	}

	if(self->previndex<self->numprevchanges) self->prevpos=self->prevchanges[self->previndex];
	else self->prevpos=self->columns;
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)cols white:(int)whitevalue
{
	if(self=[super initWithHandle:handle columns:cols white:whitevalue])
	{
		maincode=[[XADPrefixCode alloc] initWithStaticTable:T62DCodeTable];
		whitecode=[[XADPrefixCode alloc] initWithStaticTable:T41DWhiteCodeTable];
		blackcode=[[XADPrefixCode alloc] initWithStaticTable:T41DBlackCodeTable];

		prevchanges=malloc(sizeof(int)*columns);
		currchanges=malloc(sizeof(int)*columns);
	}
	return self;
}

-(void)dealloc
{
	[maincode release];
	[whitecode release];
	[blackcode release];
	free(prevchanges);
	free(currchanges);
	[super dealloc];
}

-(void)resetByteStream
{
	numcurrchanges=0;
	[super resetByteStream];
}

-(void)startNewLine
{
	currpos=0;
	currcol=0;

	int *tmp=currchanges;
	currchanges=prevchanges;
	prevchanges=tmp;

	numprevchanges=numcurrchanges;
	numcurrchanges=0;
	previndex=0;
	nexthoriz=0;
//NSLog(@"----------------new line-------------------");
}

-(void)findNextSpanLength
{
	if(nexthoriz) // remaining horizontal
	{
		bitsleft=nexthoriz;
		colour=currcol^1;

		currpos+=bitsleft;
		currchanges[numcurrchanges++]=currpos;

		nexthoriz=0;
//NSLog(@"second horiz: %d to %d",bitsleft,currpos);
	}
	else switch(CSInputNextSymbolUsingCode(input,maincode))
	{
		case PASS:
			FindNextOldChangeOfColorAndLargerThan(self,currcol^1,currpos);
			FindNextOldChangeOfColorAndLargerThan(self,currcol,prevpos);

			bitsleft=prevpos-currpos;
			colour=currcol;

			currpos=prevpos;
//NSLog(@"pass to: %d",currpos);
		break;

		case HORIZONTAL:
		{
			if(currcol==0)
			{
				bitsleft=ReadLengthWithCodeTable(input,blackcode);
				nexthoriz=ReadLengthWithCodeTable(input,whitecode);
			}
			else
			{
				bitsleft=ReadLengthWithCodeTable(input,whitecode);
				nexthoriz=ReadLengthWithCodeTable(input,blackcode);
			}

			colour=currcol;

			currpos+=bitsleft;
			currchanges[numcurrchanges++]=currpos;

//NSLog(@"first horiz: %d to %d",bitsleft,currpos);
		}
		break;

		case VERTICAL_0:
			FindNextOldChangeOfColorAndLargerThan(self,currcol^1,currpos);

			bitsleft=prevpos-currpos;
			colour=currcol;

			currpos=prevpos;
			currcol^=1;
			currchanges[numcurrchanges++]=currpos;
//NSLog(@"vertical 0 to %d",currpos);
		break;

		case VERTICAL_L1:
			FindNextOldChangeOfColorAndLargerThan(self,currcol^1,currpos);

			bitsleft=prevpos-currpos-1;
			colour=currcol;

			currpos=prevpos-1;
			currcol^=1;
			currchanges[numcurrchanges++]=currpos;
//NSLog(@"vertical l1 to %d",currpos);
		break;

		case VERTICAL_L2:
			FindNextOldChangeOfColorAndLargerThan(self,currcol^1,currpos);

			bitsleft=prevpos-currpos-2;
			colour=currcol;

			currpos=prevpos-2;
			currcol^=1;
			currchanges[numcurrchanges++]=currpos;
//NSLog(@"vertical l2 to %d",currpos);
		break;

		case VERTICAL_L3:
			FindNextOldChangeOfColorAndLargerThan(self,currcol^1,currpos);

			bitsleft=prevpos-currpos-3;
			colour=currcol;

			currpos=prevpos-3;
			currcol^=1;
			currchanges[numcurrchanges++]=currpos;
//NSLog(@"vertical l3 to %d",currpos);
		break;

		case VERTICAL_R1:
			FindNextOldChangeOfColorAndLargerThan(self,currcol^1,currpos);

			bitsleft=prevpos-currpos+1;
			colour=currcol;

			currpos=prevpos+1;
			currcol^=1;
			currchanges[numcurrchanges++]=currpos;
//NSLog(@"vertical r1 to %d",currpos);
		break;

		case VERTICAL_R2:
			FindNextOldChangeOfColorAndLargerThan(self,currcol^1,currpos);

			bitsleft=prevpos-currpos+2;
			colour=currcol;

			currpos=prevpos+2;
			currcol^=1;
			currchanges[numcurrchanges++]=currpos;
//NSLog(@"vertical r2 to %d",currpos);
		break;

		case VERTICAL_R3:
			FindNextOldChangeOfColorAndLargerThan(self,currcol^1,currpos);

			bitsleft=prevpos-currpos+3;
			colour=currcol;

			currpos=prevpos+3;
			currcol^=1;
			currchanges[numcurrchanges++]=currpos;
//NSLog(@"vertical r3 to %d",currpos);
		break;

		case UNCOMPRESSED:
			[NSException raise:CCITTCodeException format:@"Uncompressed mode not implemented"];
		break;

		case EOFB:
			colour=0;
			bitsleft=columns;
		break;
	}
}

@end


static int T41DWhiteCodeTable[][2]=
{
	{4,1},{2,3},{3,3},{2,2},{8,5},{7,6},{4,4},{1,1},{12,9},{10,11},
	{6,6},{5,5},{18,13},{15,14},{7,7},{16,17},{9,9},{8,8},{25,19},
	{22,20},{31,21},{12,12},{23,24},{10,10},{11,11},{43,26},{29,27},
	{40,28},{14,14},{30,37},{13,13},{32,34},{33,77},{15,15},{67,35},
	{51,36},{0,0},{70,38},{105,39},{16,16},{41,58},{42,119},{17,17},
	{53,44},{48,45},{74,46},{179,47},{64,64},{49,61},{50,108},{18,18},
	{52,92},{21,21},{140,54},{64,55},{56,116},{73,57},{1920,1920},
	{85,59},{149,60},{22,22},{80,62},{161,63},{24,24},{65,89},{66,83},
	{1792,1792},{68,111},{69,127},{20,20},{71,94},{72,101},{23,23},
	{1856,1856},{75,158},{76,135},{25,25},{98,78},{131,79},{19,19},
	{168,81},{188,82},{59,59},{172,84},{2048,2048},{86,155},{88,87},
	{31,31},{30,30},{114,90},{123,91},{2304,2304},{93,122},{42,42},
	{95,146},{97,96},{45,45},{44,44},{103,99},{177,100},{27,27},
	{163,102},{51,51},{154,104},{192,192},{106,125},{134,107},{58,58},
	{129,109},{182,110},{55,55},{151,112},{113,124},{38,38},{115,157},
	{2112,2112},{165,117},{133,118},{2560,2560},{138,120},{121,171},
	{62,62},{43,43},{2240,2240},{39,39},{126,145},{61,61},{137,128},
	{35,35},{130,197},{52,52},{132,153},{28,28},{2496,2496},{57,57},
	{199,136},{320,320},{34,34},{139,164},{48,48},{184,141},{0,142},
	{0,143},{0,144},{UNCOMPRESSED,UNCOMPRESSED},{256,256},{147,148},
	{46,46},{47,47},{170,150},{41,41},{167,152},{37,37},{29,29},
	{128,128},{156,173},{32,32},{2176,2176},{174,159},{206,160},{53,53},
	{162,202},{60,60},{50,50},{49,49},{176,166},{2432,2432},{36,36},
	{169,193},{56,56},{40,40},{63,63},{1984,1984},{33,33},{175,178},
	{384,384},{2368,2368},{26,26},{448,448},{180,190},{181,195},{54,54},
	{183,205},{768,768},{185,0},{186,0},{186,187},{EOL,EOL},{211,189},
	{1472,1472},{191,209},{204,192},{1088,1088},{216,194},{1344,1344},
	{215,196},{960,960},{198,201},{640,640},{200,212},{1664,1664},
	{704,704},{213,203},{1600,1600},{1024,1024},{832,832},{208,207},
	{576,576},{512,512},{214,210},{1216,1216},{1408,1408},{1728,1728},
	{1536,1536},{1152,1152},{896,896},{1280,1280},
};

static int T41DBlackCodeTable[][2]=
{
	{5,1},{2,9},{15,3},{26,4},{4,4},{19,6},{23,7},{50,8},{2,2},{13,10},
	{12,11},{7,7},{6,6},{14,17},{5,5},{16,28},{3,3},{31,18},{64,64},
	{33,20},{44,21},{68,22},{10,10},{24,37},{25,55},{11,11},{27,40},
	{9,9},{29,30},{128,128},{8,8},{42,32},{15,15},{47,34},{76,35},
	{71,36},{1,1},{63,38},{86,39},{192,192},{43,41},{17,17},{14,14},
	{16,16},{45,73},{46,53},{12,12},{58,48},{66,49},{13,13},{51,79},
	{52,97},{1664,1664},{119,54},{26,26},{61,56},{158,57},{18,18},
	{126,59},{146,60},{22,22},{62,112},{27,27},{82,64},{89,65},{25,25},
	{67,137},{23,23},{69,91},{70,116},{28,28},{72,107},{19,19},{94,74},
	{100,75},{21,21},{77,122},{78,84},{20,20},{142,80},{172,81},
	{256,256},{83,130},{24,24},{85,125},{33,33},{87,140},{149,88},
	{56,56},{90,148},{51,51},{104,92},{93,133},{320,320},{110,95},
	{96,118},{41,41},{102,98},{175,99},{640,640},{101,106},{43,43},
	{103,109},{448,448},{115,105},{0,0},{44,44},{108,114},{31,31},
	{512,512},{121,111},{40,40},{113,153},{59,59},{32,32},{63,63},
	{129,117},{62,62},{42,42},{132,120},{54,54},{39,39},{134,123},
	{139,124},{38,38},{34,34},{182,127},{128,145},{29,29},{61,61},
	{136,131},{50,50},{53,53},{384,384},{152,135},{36,36},{49,49},
	{150,138},{48,48},{37,37},{151,141},{58,58},{143,155},{144,168},
	{576,576},{30,30},{154,147},{46,46},{52,52},{55,55},{47,47},{57,57},
	{35,35},{60,60},{45,45},{156,165},{157,171},{960,960},{159,162},
	{160,161},{1472,1472},{1536,1536},{163,164},{1600,1600},{1728,1728},
	{166,167},{1088,1088},{1152,1152},{170,169},{896,896},{832,832},
	{1024,1024},{173,179},{174,178},{1216,1216},{176,177},{704,704},
	{768,768},{1280,1280},{181,180},{1408,1408},{1344,1344},{203,183},
	{187,184},{185,198},{190,186},{1920,1920},{188,193},{189,191},
	{1792,1792},{1856,1856},{211,192},{2048,2048},{196,194},{201,195},
	{2304,2304},{197,208},{2112,2112},{209,199},{202,200},{2560,2560},
	{2240,2240},{2496,2496},{213,204},{0,205},{0,206},{0,207},
	{UNCOMPRESSED,UNCOMPRESSED},{2176,2176},{212,210},{2432,2432},
	{1984,1984},{2368,2368},{214,0},{215,0},{215,216},{EOL,EOL},
};

// TODO: implement
/*static int T42DCodeTable[][2]=
{
	{2,1},{VERTICAL_0,VERTICAL_0},{5,3},{7,4},{VERTICAL_R1,VERTICAL_R1},
	{8,6},{HORIZONTAL,HORIZONTAL},{VERTICAL_L1,VERTICAL_L1},{10,9},
	{PASS,PASS},{14,11},{12,13},{VERTICAL_L2,VERTICAL_L2},
	{VERTICAL_R2,VERTICAL_R2},{18,15},{16,17},{VERTICAL_L3,VERTICAL_L3},
	{VERTICAL_R3,VERTICAL_R3},{23,19},{0,20},{0,21},{0,22},
	{UNCOMPRESSED,UNCOMPRESSED},{24,0},{25,0},{26,0},{27,0},{27,28},
	{EOL,EOL},
};*/

static int T62DCodeTable[][2]=
{
	{2,1},{VERTICAL_0,VERTICAL_0},{5,3},{7,4},{VERTICAL_R1,VERTICAL_R1},
	{8,6},{HORIZONTAL,HORIZONTAL},{VERTICAL_L1,VERTICAL_L1},{10,9},
	{PASS,PASS},{14,11},{12,13},{VERTICAL_L2,VERTICAL_L2},
	{VERTICAL_R2,VERTICAL_R2},{18,15},{16,17},{VERTICAL_L3,VERTICAL_L3},
	{VERTICAL_R3,VERTICAL_R3},{19,0},{20,0},{21,0},{22,0},{23,0},{0,24},
	{25,0},{26,0},{27,0},{28,0},{29,0},{30,0},{31,0},{32,0},{33,0},
	{34,0},{35,0},{0,36},{EOFB,EOFB},
};

