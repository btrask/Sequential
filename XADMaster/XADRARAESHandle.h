#import "CSBlockStreamHandle.h"
#import <openssl/aes.h>

@interface XADRARAESHandle:CSBlockStreamHandle
{
	CSHandle *parent;
	off_t startoffs;

	AES_KEY key;
	uint8_t iv[16],xorblock[16],buffer[65536];
}

+(NSData *)keyForPassword:(NSString *)password salt:(NSData *)salt brokenHash:(BOOL)brokenhash;

-(id)initWithHandle:(CSHandle *)handle key:(NSData *)keydata;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length key:(NSData *)keydata;
-(void)dealloc;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
