#import "XADMSZipHandle.h"

#include <zlib.h>

@implementation XADMSZipHandle

-(int)produceCABBlockWithInputBuffer:(uint8_t *)buffer length:(int)length atOffset:(off_t)pos length:(int)uncomplength
{
	z_stream zs;
	memset(&zs,0,sizeof(zs));

	inflateInit2(&zs,-MAX_WBITS);
	if(pos!=0) inflateSetDictionary(&zs,outbuffer,lastlength);

	zs.avail_in=length-2;
	zs.next_in=buffer+2;

	zs.next_out=outbuffer;
	zs.avail_out=uncomplength; //sizeof(outbuffer);

	/*int err=*/inflate(&zs,0);
	inflateEnd(&zs);
	/*if(err==Z_STREAM_END)
	{
		if(seekback) [parent skipBytes:-(off_t)zs.avail_in];
		[self endStream];
		break;
	}
	else if(err!=Z_OK) [self _raiseZlib];*/

	[self setBlockPointer:outbuffer];

	lastlength=sizeof(outbuffer)-zs.avail_out;
	return lastlength;
}

@end
