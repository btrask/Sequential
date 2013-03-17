#import "XADBlockHandle.h"

@implementation XADBlockHandle

-(id)initWithHandle:(CSHandle *)handle blockSize:(int)size
{
	if((self=[super initWithName:[handle name]]))
	{
		parent=[handle retain];
		currpos=0;
		length=CSHandleMaxLength;
		numblocks=0;
		blocksize=size;
		blockoffsets=NULL;
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)maxlength blockSize:(int)size
{
	if((self=[super initWithName:[handle name]]))
	{
		parent=[handle retain];
		currpos=0;
		length=maxlength;
		numblocks=0;
		blocksize=size;
		blockoffsets=NULL;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}


-(void)setBlockChain:(uint32_t *)blocktable numberOfBlocks:(int)totalblocks
firstBlock:(uint32_t)first headerSize:(off_t)headersize
{
	numblocks=0;
	uint32_t block=first;
	while(block<totalblocks)
	{
		block=blocktable[block];
		numblocks++;
	}

	free(blockoffsets);
	blockoffsets=malloc(numblocks*sizeof(off_t));

	block=first;
	for(int i=0;i<numblocks;i++)
	{
		blockoffsets[i]=headersize+block*blocksize;
		block=blocktable[block];
	}
}

-(off_t)fileSize
{
	if(length<numblocks*blocksize) return length;
	return numblocks*blocksize;
}

-(off_t)offsetInFile
{
	return currpos;
}

-(BOOL)atEndOfFile
{
	if(currpos==numblocks*blocksize) return YES;
	if(currpos==length) return YES;
	return NO;
}

-(void)seekToFileOffset:(off_t)offs
{
	if(offs<0) [self _raiseEOF];
	if(offs>numblocks*blocksize) [self _raiseEOF];
	if(offs>length) [self _raiseEOF];

	int block=(offs-1)/blocksize;

	[parent seekToFileOffset:blockoffsets[block]+offs-block*blocksize];
	currpos=offs;
}

-(void)seekToEndOfFile
{
	if(length!=CSHandleMaxLength) [self seekToFileOffset:length];
	else [self seekToFileOffset:numblocks*blocksize];
}

-(int)readAtMost:(int)num toBuffer:(void *)buffer
{
	uint8_t *bytebuffer=(uint8_t *)buffer;
	int total=0;

	if(currpos+num>length) num=length-currpos;

	while(total<num)
	{
		int blockpos=currpos%blocksize;
		if(blockpos==0)
		{
			int block=currpos/blocksize;
			if(block==numblocks) return total;
			[parent seekToFileOffset:blockoffsets[block]];
		}

		int numbytes=num-total;
		if(numbytes>blocksize-blockpos) numbytes=blocksize-blockpos;

		int actual=[parent readAtMost:numbytes toBuffer:&bytebuffer[total]];
		if(actual==0) return total;

		total+=actual;
		currpos+=actual;
	}

	return total;
}

@end
