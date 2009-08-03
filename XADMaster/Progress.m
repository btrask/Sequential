#import "Progress.h"


@implementation CSHandle (Progress)

-(double)estimatedProgress
{
	off_t size=[self fileSize];
	if(size==CSHandleMaxLength) return 0;
	return (double)[self offsetInFile]/(double)size;
}

@end

@implementation CSStreamHandle (progress)

-(double)estimatedProgress
{
	if(streamlength==CSHandleMaxLength)
	{
		if(input) return [input->parent estimatedProgress]; // TODO: better estimation
		else return 0;
	}
	else return (double)streampos/(double)streamlength;
}

@end

@implementation CSZlibHandle (Progress)

-(double)estimatedProgress { return [parent estimatedProgress]; } // TODO: better estimation using buffer?

@end

@implementation CSBzip2Handle (progress)

-(double)estimatedProgress { return [parent estimatedProgress]; } // TODO: better estimation using buffer?

@end

// TODO: more handles like LZMA?
