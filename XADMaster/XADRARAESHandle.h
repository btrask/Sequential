#import "CSBlockStreamHandle.h"
#import <openssl/aes.h>

@interface XADRARAESHandle:CSBlockStreamHandle
{
	CSHandle *parent;
	off_t startoffs;

	AES_KEY key;
	uint8_t iv[16],xorblock[16],outblock[16];
}

-(id)initWithHandle:(CSHandle *)handle password:(NSString *)password
salt:(NSData *)salt brokenHash:(BOOL)brokenhash;
-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSString *)password
salt:(NSData *)salt  brokenHash:(BOOL)brokenhash;
-(void)dealloc;

-(void)calculateKeyForPassword:(NSString *)password salt:(NSData *)salt brokenHash:(BOOL)brokenhash;

-(void)resetBlockStream;
-(int)produceBlockAtOffset:(off_t)pos;

@end
