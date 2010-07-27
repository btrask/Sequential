#import "CSStreamHandle.h"

#import <openssl/aes.h>
#import <openssl/hmac.h>

@interface XADWinZipAESHandle:CSStreamHandle
{
	CSHandle *parent;
	NSData *password;
	int keybytes;
	off_t startoffs;

	AES_KEY key;
	uint8_t counter[16],aesbuffer[16];
	HMAC_CTX hmac;
	BOOL hmac_inited,hmac_done,hmac_correct;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata keyLength:(int)keylength;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

@end
