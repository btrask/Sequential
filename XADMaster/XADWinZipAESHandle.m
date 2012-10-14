#import "XADWinZipAESHandle.h"
#import "XADException.h"

@implementation XADWinZipAESHandle

-(id)initWithHandle:(CSHandle *)handle length:(off_t)length password:(NSData *)passdata keyLength:(int)keylength
{
	off_t actuallength=length-keylength/2-12;
	if((self=[super initWithName:[handle name] length:actuallength]))
	{
		parent=[handle retain];
		password=[passdata retain];
		keybytes=keylength;
		startoffs=[handle offsetInFile];

		hmac_inited=hmac_done=hmac_correct=NO;
	}
	return self;
}

-(void)dealloc
{
	[parent release];
	[password release];

	if(hmac_inited) HMAC_CTX_cleanup(&hmac);

	[super dealloc];
}

static void DeriveKey(NSData *password,NSData *salt,int iterations,uint8_t *keybuffer,int keylength)
{
	int blocks=(keylength+19)/20;

//	memset(keybuffer,0,keylength);

	for(int i=0;i<blocks;i++)
	{
		HMAC_CTX hmac;
		uint8_t counter[4]={(i+1)>>24,(i+1)>>16,(i+1)>>8,i+1};
		uint8_t buffer[20];

		HMAC_CTX_init(&hmac);
		HMAC_Init(&hmac,[password bytes],[password length],EVP_sha1());
		HMAC_Update(&hmac,[salt bytes],[salt length]);
		HMAC_Update(&hmac,counter,4);
		HMAC_Final(&hmac,buffer,NULL);
		HMAC_CTX_cleanup(&hmac);

		int blocklen=20;
		if(blocklen+i*20>keylength) blocklen=keylength-i*20;
		memcpy(keybuffer,buffer,blocklen);

		for(int j=1;j<iterations;j++)
		{
			HMAC(EVP_sha1(),[password bytes],[password length],buffer,20,buffer,NULL);
			for(int k=0;k<blocklen;k++) keybuffer[k]^=buffer[k];
		}

		keybuffer+=20;
	}
}

-(void)resetStream
{
	[parent seekToFileOffset:startoffs];

	uint8_t keybuf[2*keybytes+2];
	DeriveKey(password,[parent readDataOfLength:keybytes/2],1000,keybuf,sizeof(keybuf));

	if([parent readUInt16LE]!=keybuf[2*keybytes]+(keybuf[2*keybytes+1]<<8)) [XADException raisePasswordException];

	AES_set_encrypt_key(keybuf,keybytes*8,&key);
	memset(counter,0,16);

	if(hmac_inited) HMAC_CTX_cleanup(&hmac);

	HMAC_CTX_init(&hmac);
	HMAC_Init(&hmac,keybuf+keybytes,keybytes,EVP_sha1());

	hmac_inited=YES;
	hmac_done=NO;
	hmac_correct=NO;
}


-(int)streamAtMost:(int)num toBuffer:(void *)buffer
{
	int actual=[parent readAtMost:num toBuffer:buffer];

	HMAC_Update(&hmac,buffer,actual);

	for(int i=0;i<actual;i++)
	{
		int bufoffs=(i+streampos)%16;
		if(bufoffs==0)
		{
			for(int i=0;i<8;i++) if(++counter[i]!=0) break;
			AES_encrypt(counter,aesbuffer,&key);
		}

		((uint8_t *)buffer)[i]^=aesbuffer[bufoffs];
	}

	return actual;
}

-(BOOL)hasChecksum { return YES; }

-(BOOL)isChecksumCorrect
{
	if(!hmac_done && streampos==streamlength)
	{
		uint8_t filedigest[10],calcdigest[20];
		[parent readBytes:10 toBuffer:filedigest];
		HMAC_Final(&hmac,calcdigest,NULL);
		hmac_correct=memcmp(calcdigest,filedigest,10)==0;
		hmac_done=YES;
	}

	return hmac_correct;
}

@end
