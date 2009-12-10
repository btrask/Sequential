#import "XADCABBlockReader.h"
#import "XADException.h"

@implementation XADCABBlockReader

-(id)initWithHandle:(CSHandle *)handle reservedBytes:(int)reserved
{
	if(self=[super init])
	{
		parent=[handle retain];
		extbytes=reserved;
		numfolders=0;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}



-(void)addFolderAtOffset:(off_t)startoffs numberOfBlocks:(int)num
{
	if(numfolders==sizeof(offsets)/sizeof(offsets[0])) [XADException raiseNotSupportedException];

	offsets[numfolders]=startoffs;
	numblocks[numfolders]=num;
	numfolders++;
}

-(void)scanLengths
{
	complen=0;
	uncomplen=0;

	for(int folder=0;folder<numfolders;folder++)
	{
		[parent seekToFileOffset:offsets[folder]];

		for(int block=0;block<numblocks[folder];block++)
		{
			uint32_t check=[parent readUInt32LE];
			int compbytes=[parent readUInt16LE];
			int uncompbytes=[parent readUInt16LE];
			[parent skipBytes:extbytes+compbytes];

			complen+=compbytes;
			uncomplen+=uncompbytes;
		}
	}
}



-(CSHandle *)handle { return parent; }

-(off_t)compressedLength { return complen; }

-(off_t)uncompressedLength { return uncomplen; }

-(void)restart
{
	[parent seekToFileOffset:offsets[0]];
	currentfolder=0;
	currentblock=0;
}

-(BOOL)readNextBlockToBuffer:(uint8_t *)buffer compressedLength:(int *)compptr
uncompressedLength:(int *)uncompptr
{
	if(currentfolder>=numfolders) [XADException raiseDecrunchException];

	uint32_t check=[parent readUInt32LE];
	int compbytes=[parent readUInt16LE];
	int uncompbytes=[parent readUInt16LE];
	[parent skipBytes:extbytes];

	if(compbytes>32768+6144) [XADException raiseIllegalDataException];

	[parent readBytes:compbytes toBuffer:buffer];

	int totalbytes=compbytes;
	while(uncompbytes==0)
	{
		currentblock=0;
		currentfolder++;

		if(currentfolder>=numfolders) [XADException raiseIllegalDataException];

		[parent seekToFileOffset:offsets[currentfolder]];
		check=[parent readUInt32LE];
		compbytes=[parent readUInt16LE];
		uncompbytes=[parent readUInt16LE];
		[parent skipBytes:extbytes];

		if(compbytes+totalbytes>32768+6144) [XADException raiseIllegalDataException];

		[parent readBytes:compbytes toBuffer:&buffer[totalbytes]];
		totalbytes+=compbytes;
	}

	currentblock++;
	if(currentblock>=numblocks[currentfolder])
	{
		// Can this happen? Not sure, supporting it anyway.
		currentblock=0;
		currentfolder++;
		[parent seekToFileOffset:offsets[currentfolder]];
	}

	if(compptr) *compptr=totalbytes;
	if(uncompptr) *uncompptr=uncompbytes;

	return currentfolder>=numfolders;
}

@end
