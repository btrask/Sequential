#import "../CSByteStreamHandle.h"
#import "../XADPrefixCode.h"

extern NSString *CCITTCodeException;

@interface CCITTFaxHandle:CSByteStreamHandle
{
	int columns,white;
	int column,colour,bitsleft;
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)cols white:(int)whitevalue;

-(void)resetByteStream;
-(uint8_t)produceByteAtOffset:(off_t)pos;

-(void)startNewLine;
-(void)findNextSpanLength;

@end

@interface CCITTFaxT41DHandle:CCITTFaxHandle
{
	XADPrefixCode *whitecode,*blackcode;
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)cols white:(int)whitevalue;
-(void)dealloc;

-(void)startNewLine;
-(void)findNextSpanLength;

@end

@interface CCITTFaxT6Handle:CCITTFaxHandle
{
	int *prevchanges,numprevchanges;
	int *currchanges,numcurrchanges;
	int prevpos,previndex,currpos,currcol,nexthoriz;
	XADPrefixCode *maincode,*whitecode,*blackcode;
}

-(id)initWithHandle:(CSHandle *)handle columns:(int)columns white:(int)whitevalue;
-(void)dealloc;

-(void)resetByteStream;
-(void)startNewLine;
-(void)findNextSpanLength;

@end

