#import "XADARCCrushHandle.h"
#import "XADException.h"

@implementation XADARCCrushHandle

-(id)initWithHandle:(CSHandle *)handle
{
	return [self initWithHandle:handle length:CSHandleMaxLength];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
{
	if((self=[super initWithHandle:handle length:length]))
	{
		lzw=AllocLZW(8192,1);
	}
	return self;
}

-(void)dealloc
{
	FreeLZW(lzw);
	[super dealloc];
}

-(void)resetByteStream
{
	ClearLZWTable(lzw);
	symbolsize=1;
	nextsizebump=2;
	useliteralbit=YES;

	numrecentstrings=0;
	ringindex=0;
	memset(stringring,0,sizeof(stringring));

	usageindex=0x101;

	currbyte=0;
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(!currbyte)
	{
		// Read the next symbol. How depends on the mode we are operating in.
		int symbol;
		if(useliteralbit)
		{
			// Use codes prefixed by a bit that selects literal or string codes.
			// Literals are always 8 bits, strings vary.
			if(CSInputNextBitLE(input)) symbol=CSInputNextBitStringLE(input,symbolsize)+256;
			else symbol=CSInputNextBitStringLE(input,8);
		}
		else
		{
			// Use same-length codes for both literals and strings.
			// Due to an optimization quirk in the original decruncher,
			// literals have their bits inverted.
			symbol=CSInputNextBitStringLE(input,symbolsize);
			if(symbol<0x100) symbol^=0xff;
		}

		// Code 0x100 is the EOF code.
		if(symbol==0x100) CSByteStreamEOF(self);

		// Walk through the LZW tree, and set the usage count of the current
		// string and all its parents to 4. This is not necessary for literals,
		// but we do it anyway for simplicity.
		LZWTreeNode *nodes=LZWSymbols(lzw);
		int marksymbol=symbol;
		while(marksymbol>=0)
		{
			usage[marksymbol]=4;
			marksymbol=nodes[marksymbol].parent;
		}

		// Adjust the count of recent strings versus literals.
		// Use a ring buffer of length 500 as a window to keep track
		// of how many strings have been encountered lately.

		// First, decrease the count if a string leaves the window.
		if(stringring[ringindex]) numrecentstrings--;

		// The store the current type of symbol in the window, and
		// increase the count if the current symbol is a string.
		if(symbol<0x100)
		{
			stringring[ringindex]=NO;
		}
		else
		{
			stringring[ringindex]=YES;
			numrecentstrings++;
		}

		// Move the window forward.
		ringindex=(ringindex+1)%500;

		// Check the number of strings. If there have been many literals
		// lately, bit-prefixed codes should be used. If we need to change
		// mode, re-calculate the point where we increase the code length.
		BOOL manyliterals=numrecentstrings<375;
		if(manyliterals!=useliteralbit)
		{
			useliteralbit=manyliterals;
			nextsizebump=1<<symbolsize;
			if(!useliteralbit) nextsizebump-=0x100;
		}

		// Update the LZW tree.
		if(!LZWSymbolListFull(lzw))
		{
			// If there is space in the tree, just add a new string a usual.
			if(NextLZWSymbol(lzw,symbol)==LZWInvalidCodeError) [XADException raiseDecrunchException];

			// Set the usage count of the newly created entry.
			usage[LZWSymbolCount(lzw)-1]=2;
		}
		else
		{
			// If the tree is full, find an less-used symbol, and replace it.
			int minindex,minusage=INT_MAX;
			int index=usageindex;
			do
			{
				index++;
				if(index==8192) index=0x101;

				if(usage[index]<minusage)
				{
					minindex=index;
					minusage=usage[index];
				}

				usage[index]--;
				if(usage[index]==0) break;
			}
			while(index!=usageindex);

			usageindex=index;

			if(ReplaceLZWSymbol(lzw,minindex,symbol)==LZWInvalidCodeError) [XADException raiseDecrunchException];

			// Set the usage count of the replaced entry.
			usage[minindex]=2;
		}

		// Extract the data to output.
		currbyte=LZWReverseOutputToBuffer(lzw,buffer);

		// Check if we need to increase the code size. The point at which
		// to increase varies depending on the coding mode.
		if(LZWSymbolCount(lzw)-257>=nextsizebump)
		{
			symbolsize++;
			nextsizebump=1<<symbolsize;
			if(!useliteralbit) nextsizebump-=0x100;
		}
	}

	return buffer[--currbyte];
}

@end


