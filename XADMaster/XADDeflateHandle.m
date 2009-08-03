#import "XADDeflateHandle.h"
#import "XADException.h"

@implementation XADDeflateHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	return [self initWithHandle:handle length:length variant:XADNormalDeflateVariant];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length variant:(int)deflatevariant
{
	if(self=[super initWithHandle:handle length:length
	windowSize:deflatevariant==XADDeflate64DeflateVariant?65536:32768])
	{
		variant=deflatevariant;
		literalcode=distancecode=nil;
		fixedliteralcode=fixeddistancecode=nil;

		static const int ziporder[19]={16,17,18,0,8,7,9,6,10,5,11,4,12,3,13,2,14,1,15};
		[self setMetaTableOrder:ziporder];
	}
	return self;
}

-(void)dealloc
{
	[literalcode release];
	[distancecode release];
	[fixedliteralcode release];
	[fixeddistancecode release];
	[super dealloc];
}

-(void)setMetaTableOrder:(const int *)neworder { memcpy(order,neworder,sizeof(order)); }

-(void)resetLZSSHandle
{
	[self readBlockHeader];
}

-(int)nextLiteralOrOffset:(int *)offset andLength:(int *)length atPosition:(off_t)pos
{
	if(storedblock)
	{
		if(!storedcount)
		{
			if(lastblock) return XADLZSSEnd;
			if(variant==XADNSISDeflateVariant&&input->eof) return XADLZSSEnd; // kludge - CSInputAtEOF is not enough, there are a few bytes left
			[self readBlockHeader];
			return [self nextLiteralOrOffset:offset andLength:length atPosition:pos];
		}
		storedcount--;
		return CSInputNextByte(input);
	}
	else
	{
		int literal=CSInputNextSymbolUsingCodeLE(input,literalcode);

		if(literal<256) return literal;
		else if(literal==256)
		{
			if(lastblock) return XADLZSSEnd;
			if(variant==XADNSISDeflateVariant&&input->eof) return XADLZSSEnd; // kludge - CSInputAtEOF is not enough, there are a few bytes left
			[self readBlockHeader];
			return [self nextLiteralOrOffset:offset andLength:length atPosition:pos];
		}
		else if(literal<265) *length=literal-254;
		else if(literal<285)
		{
			static const int baselengths[]={11,13,15,17,19,23,27,31,35,43,51,59,67,83,99,115,131,163,195,227};
			int size=(literal-261)/4;
			*length=baselengths[literal-265]+CSInputNextBitStringLE(input,size);
		}
		else // literal==285
		{
			if(variant==XADDeflate64DeflateVariant) *length=3+CSInputNextBitStringLE(input,16);
			else *length=258;
		}

		int distance=CSInputNextSymbolUsingCodeLE(input,distancecode);

		if(distance<4) *offset=distance+1;
		else
		{
			static const int baseoffsets[]={5,7,9,13,17,25,33,49,65,97,129,193,257,
			385,513,769,1025,1537,2049,3073,4097,6145,8193,12289,16385,24577,32769,49153};
			int size=(distance-2)/2;
			*offset=baseoffsets[distance-4]+CSInputNextBitStringLE(input,size);
		}

		return XADLZSSMatch;
	}
}

-(void)readBlockHeader
{
	[literalcode release];
	[distancecode release];
	literalcode=nil;
	distancecode=nil;

	lastblock=CSInputNextBitLE(input);

	int type=CSInputNextBitStringLE(input,2);

	switch(type)
	{
		case 0: // stored
		{
			CSInputSkipToByteBoundary(input);

			int count=CSInputNextUInt16LE(input);

			if(variant!=XADNSISDeflateVariant)
			if(count!=(CSInputNextUInt16LE(input)^0xffff)) [XADException raiseDecrunchException];

			storedcount=count;
			storedblock=YES;
		}
		break;

		case 1: // fixed huffman
			literalcode=[[self fixedLiteralCode] retain];
			distancecode=[[self fixedDistanceCode] retain];
			storedblock=NO;
		break;

		case 2: // dynamic huffman
		{
			int numliterals=CSInputNextBitStringLE(input,5)+257;
			int numdistances=CSInputNextBitStringLE(input,variant==XADStuffItXDeflateVariant?6:5)+1;
			int nummetas=CSInputNextBitStringLE(input,4)+4;

			XADPrefixCode *metacode=[self allocAndParseMetaCodeOfSize:nummetas]; // BUG: might leak if the following throw an exception!
			int total=numliterals+numdistances;
			int lengths[total];
			for(int i=0;i<total;)
			{
				int val=CSInputNextSymbolUsingCodeLE(input,metacode);

				if(val<16) lengths[i++]=val;
				else if(val==16)
				{
					int repeats=CSInputNextBitStringLE(input,2)+3;

					if(i==0||i+repeats>total) [XADException raiseDecrunchException];

					for(int j=0;j<repeats;j++) lengths[i+j]=lengths[i-1];
					i+=repeats;
				}
				else
				{
					int repeats;
					if(val==17) repeats=CSInputNextBitStringLE(input,3)+3;
					else repeats=CSInputNextBitStringLE(input,7)+11;

//if(i+repeats>total) repeats=total-i;
					if(i+repeats>total) [XADException raiseDecrunchException];

					for(int j=0;j<repeats;j++) lengths[i+j]=0;
					i+=repeats;
				}
			}

			literalcode=[[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:numliterals maximumLength:15 shortestCodeIsZeros:YES];
			distancecode=[[XADPrefixCode alloc] initWithLengths:lengths+numliterals numberOfSymbols:numdistances maximumLength:15 shortestCodeIsZeros:YES];

			[metacode release];
			storedblock=NO;
		}
		break;

		default: [XADException raiseDecrunchException];
	}
}

-(XADPrefixCode *)allocAndParseMetaCodeOfSize:(int)size
{
	int lengths[19];
	for(int i=0;i<size;i++) lengths[order[i]]=CSInputNextBitStringLE(input,3);
//for(int i=0;i<size;i++) NSLog(@"%d",lengths[order[i]]);

	for(int i=size;i<19;i++) lengths[order[i]]=0;

//NSLog(@"-----------");
//for(int i=0;i<19;i++) NSLog(@"%d",lengths[i]);

	return [[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:19 maximumLength:7 shortestCodeIsZeros:YES];
}

-(XADPrefixCode *)fixedLiteralCode
{
	if(!fixedliteralcode)
	{
		int lengths[288];
		for(int i=0;i<144;i++) lengths[i]=8;
		for(int i=144;i<256;i++) lengths[i]=9;
		for(int i=256;i<280;i++) lengths[i]=7;
		for(int i=280;i<288;i++) lengths[i]=8;
		fixedliteralcode=[[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:288 maximumLength:9 shortestCodeIsZeros:YES];
	}
	return fixedliteralcode;
}

-(XADPrefixCode *)fixedDistanceCode
{
	if(!fixeddistancecode)
	{
		int lengths[32];
		for(int i=0;i<32;i++) lengths[i]=5;
		fixeddistancecode=[[XADPrefixCode alloc] initWithLengths:lengths numberOfSymbols:32 maximumLength:5 shortestCodeIsZeros:YES];
	}
	return fixeddistancecode;
}

@end
