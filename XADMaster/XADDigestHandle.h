#import "CSStreamHandle.h"
#import "Checksums.h"
#import "Progress.h"

#include <openssl/evp.h>

@interface XADDigestHandle:CSStreamHandle
{
	CSHandle *parent;
	NSData *digest;

	const EVP_MD *type;
	EVP_MD_CTX ctx;
	BOOL inited;
}

+(XADDigestHandle *)MD5HandleWithHandle:(CSHandle *)handle length:(off_t)length
correctDigest:(NSData *)correctdigest;
+(XADDigestHandle *)SHA1HandleWithHandle:(CSHandle *)handle length:(off_t)length
correctDigest:(NSData *)correctdigest;
//+(XADDigestHandle *)SHA256HandleWithHandle:(CSHandle *)handle length:(off_t)length
//correctDigest:(NSData *)correctdigest;
+(XADDigestHandle *)digestHandleWithHandle:(CSHandle *)handle length:(off_t)length
digestName:(NSString *)digestname correctDigest:(NSData *)correctdigest;

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
digestType:(const EVP_MD *)digesttype correctDigest:(NSData *)correctdigest;
-(void)dealloc;

-(void)resetStream;
-(int)streamAtMost:(int)num toBuffer:(void *)buffer;

-(BOOL)hasChecksum;
-(BOOL)isChecksumCorrect;

@end

