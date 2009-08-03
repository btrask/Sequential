#import "XADRARAESHandle.h"
#import "RARBug.h"

#import <openssl/sha.h>

@implementation XADRARAESHandle

-(id)initWithHandle:(CSHandle *)handle password:(NSString *)password
salt:(NSData *)salt brokenHash:(BOOL)brokenhash
{
	if(self=[super initWithName:[handle name]])
	{
		parent=[handle retain];
		startoffs=[handle offsetInFile];
		[self calculateKeyForPassword:password salt:salt brokenHash:brokenhash];
	}
	return self;
}

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSString *)password
salt:(NSData *)salt brokenHash:(BOOL)brokenhash
{
	if(self=[super initWithName:[handle name] length:length])
	{
		parent=[handle retain];
		startoffs=[handle offsetInFile];
		[self calculateKeyForPassword:password salt:salt brokenHash:brokenhash];
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[super dealloc];
}

-(void)calculateKeyForPassword:(NSString *)password salt:(NSData *)salt brokenHash:(BOOL)brokenhash
{
	int length=[password length];
	if(length>126) length=126;

	uint8_t passbuf[length*2+8];
	for(int i=0;i<length;i++)
	{
		int c=[password characterAtIndex:i];
		passbuf[2*i]=c;
		passbuf[2*i+1]=c>>8;
	}

	int buflength=length*2;

	if(salt)
	{
		memcpy(passbuf+2*length,[salt bytes],8);
		buflength+=8;
	}

	SHA_CTX sha;
	SHA1_Init(&sha);

	for(int i=0;i<0x40000;i++)
	{
		SHA1_Update_WithRARBug(&sha,passbuf,buflength,brokenhash);

		uint8_t num[3]={i,i>>8,i>>16};
		SHA1_Update_WithRARBug(&sha,num,3,brokenhash);

		if(i%0x4000==0)
		{
			SHA_CTX tmpsha=sha;
			uint8_t digest[20];
			SHA1_Final(digest,&tmpsha);
			iv[i/0x4000]=digest[19];
		}
	}

	uint8_t digest[20],keybuf[16];
	SHA1_Final(digest,&sha);

	for(int i=0;i<16;i++) keybuf[i]=digest[i^3];

/*NSLog(@"%@",salt);
NSLog(@"%02x%02x%02x%02x %02x%02x%02x%02x %02x%02x%02x%02x %02x%02x%02x%02x",
keybuf[0],keybuf[1],keybuf[2],keybuf[3],keybuf[4],keybuf[5],keybuf[6],keybuf[7],
keybuf[8],keybuf[9],keybuf[10],keybuf[11],keybuf[12],keybuf[13],keybuf[14],keybuf[15]
);*/

	AES_set_decrypt_key(keybuf,128,&key);
}

-(void)resetBlockStream
{
	[parent seekToFileOffset:startoffs];
	memcpy(xorblock,iv,16);
	[self setBlockPointer:outblock];
}

-(int)produceBlockAtOffset:(off_t)pos
{
	uint8_t inblock[16];

	int actual=[parent readAtMost:16 toBuffer:inblock];
	if(actual!=16) return -1;

	AES_decrypt(inblock,outblock,&key);

	for(int i=0;i<16;i++) outblock[i]^=xorblock[i];
	memcpy(xorblock,inblock,16);

	return 16;
}

@end
