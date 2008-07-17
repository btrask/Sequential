#import <Cocoa/Cocoa.h>
#import "XADArchive.h"

@interface XADArchivePipe:NSObject
{
	XADArchive *sourcearchive;
	int entry;

	struct Hook inhook,outhook;

	unsigned char *buf;
	int bufsize;

	xadSize fullsize;
	volatile xadSize bufstart,buflen;
	volatile xadSize readpos,writepos;
	volatile xadPTR requestbuffer;
	volatile xadSize requeststart,requestlength;
	volatile BOOL resetwrite,writefailed;

	NSLock *writelock,*readlock;
}

-(id)initWithArchive:(XADArchive *)archive entry:(int)n bufferSize:(int)buffersize;
-(void)dealloc;
-(void)dismantle;
-(struct Hook *)outHook;
-(struct Hook *)inHook;

-(void)decompress:(id)dummy;

-(xadUINT32)writeStarted;
-(void)writeStopped;
-(xadUINT32)writeBytes:(xadPTR)bytes length:(xadSize)length newPosition:(xadSize *)newpos;

-(xadUINT32)readStarted;
-(void)readStopped;
-(xadUINT32)readBytes:(xadPTR)bytes length:(xadSize)length newPosition:(xadSize *)newpos;
-(xadUINT32)seekReadPosition:(xadSize)offset newPosition:(xadSize *)newpos;
-(xadSize)fullSize;

-(xadUINT32)issueRequestAndWait;
-(void)waitForRequest;
-(void)readBytesFromBufferTo:(xadPTR)destbuf length:(xadSize)length;
-(void)writeBytesToBuffer:(xadPTR)bytes length:(xadSize)length;

@end
