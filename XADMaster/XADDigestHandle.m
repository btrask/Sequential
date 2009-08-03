#import "XADDigestHandle.h"

@implementation XADDigestHandle

+(XADDigestHandle *)MD5HandleWithHandle:(CSHandle *)handle length:(off_t)length
correctDigest:(NSData *)correctdigest
{
	return [[[self alloc] initWithHandle:handle length:length digestType:EVP_md5() correctDigest:correctdigest] autorelease];
}

+(XADDigestHandle *)SHA1HandleWithHandle:(CSHandle *)handle length:(off_t)length
correctDigest:(NSData *)correctdigest
{
	return [[[self alloc] initWithHandle:handle length:length digestType:EVP_sha1() correctDigest:correctdigest] autorelease];
}

/*+(XADDigestHandle *)SHA256HandleWithHandle:(CSHandle *)handle length:(off_t)length
correctDigest:(NSData *)correctdigest
{
	return [[[self alloc] initWithHandle:handle length:length digestType:EVP_ssha256() correctDigest:correctdigest] autorelease];
}*/

+(XADDigestHandle *)digestHandleWithHandle:(CSHandle *)handle length:(off_t)length
digestName:(NSString *)digestname correctDigest:(NSData *)correctdigest
{
	static BOOL added=NO;
	if(!added)
	{
		OpenSSL_add_all_digests();
		added=YES;
	}

	const EVP_MD *type=EVP_get_digestbyname([digestname UTF8String]);
	if(!type) return nil;

	return [[[self alloc] initWithHandle:handle length:length digestType:type correctDigest:correctdigest] autorelease];
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length
digestType:(const EVP_MD *)digesttype correctDigest:(NSData *)correctdigest
{
	if(self=[super initWithName:[handle name] length:length])
	{
		parent=[handle retain];
		digest=[correctdigest retain];
		type=digesttype;
		inited=NO;
	}
	return self;
}

-(void)dealloc
{
	if(inited) EVP_MD_CTX_cleanup(&ctx);
	[parent release];
	[digest release];
	[super dealloc];
}

-(void)resetStream
{
	if(inited) EVP_MD_CTX_cleanup(&ctx);
	EVP_DigestInit(&ctx,type);
	inited=YES;

	[parent seekToFileOffset:0];
}

-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];
	EVP_DigestUpdate(&ctx,buffer,actual);
	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	int length=EVP_MD_size(type);
	if([digest length]!=length) return NO;

	EVP_MD_CTX copy;
	EVP_MD_CTX_copy(&copy,&ctx);

	uint8_t buf[length];
	EVP_DigestFinal(&ctx,buf,NULL);

	return memcmp([digest bytes],buf,length)==0;
}

-(double)estimatedProgress { return [parent estimatedProgress]; }

@end


