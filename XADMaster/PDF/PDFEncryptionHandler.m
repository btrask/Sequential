#import "PDFEncryptionUtils.h"
#import "PDFParser.h"
#import "NSDictionaryNumberExtension.h"

#import "../CSMemoryHandle.h"
#import "../XADRC4Handle.h"

NSString *PDFUnsupportedEncryptionException=@"PDFUnsupportedEncryptionException";

static const char PDFPasswordPadding[32]=
{
	0x28,0xBF,0x4E,0x5E,0x4E,0x75,0x8A,0x41,0x64,0x00,0x4E,0x56,0xFF,0xFA,0x01,0x08, 
	0x2E,0x2E,0x00,0xB6,0xD0,0x68,0x3E,0x80,0x2F,0x0C,0xA9,0xFE,0x64,0x53,0x69,0x7A
};


@implementation PDFEncryptionHandler

+(BOOL)isEncryptedForTrailerDictionary:(NSDictionary *)trailer
{
	return [trailer objectForKey:@"Encrypt"]!=nil;
}

-(id)initWithEncryptDictionary:(NSDictionary *)encryptdict permanentID:(NSData *)permanentiddata;
{
	if(self=[super init])
	{
		algorithms=nil;
		encrypt=[encryptdict retain];
		permanentid=[permanentiddata retain];
		password=nil;
		keys=[NSMutableDictionary new];

		version=[encrypt intValueForKey:@"V" default:0];
		revision=[encrypt intValueForKey:@"R" default:0];

		// TODO: Figure out resolving and encryption
		NSString *filter=[encrypt objectForKey:@"Filter"];
		if(![filter isEqual:@"Standard"] ||
		(version!=1 && version!=2 && version!=4) ||
		(revision!=2 && revision!=3 && revision!=4))
		{
			[self release];
			[NSException raise:PDFUnsupportedEncryptionException format:@"PDF encryption filter \"%@\" version %d, revision %d is not supported.",filter,version,revision];
		}

		if(version==1||version==2)
		{
			int length;
			if(revision>=3) length=[encrypt intValueForKey:@"Length" default:40];
			else length=40;
			stringalgorithm=streamalgorithm=[[[PDFRC4Algorithm alloc] initWithLength:length/8 handler:self] retain];
		}
		else
		{
			algorithms=[[NSMutableDictionary dictionary] retain];

			NSDictionary *filters=[encrypt objectForKey:@"CF"];
			NSEnumerator *enumerator=[filters keyEnumerator];
			NSString *key;
			while(key=[enumerator nextObject])
			{
				NSDictionary *dict=[filters objectForKey:key];
				NSString *cfm=[dict objectForKey:@"CFM"];
				int length=[dict intValueForKey:@"Length" default:5];

				if([cfm isEqual:@"V2"]) [algorithms setObject:[[[PDFRC4Algorithm alloc] initWithLength:length handler:self] autorelease] forKey:key];
				else if([cfm isEqual:@"AESV2"]) [algorithms setObject:[[[PDFAESAlgorithm alloc] initWithLength:length handler:self] autorelease] forKey:key];
				else [NSException raise:PDFUnsupportedEncryptionException format:@"PDF encryption module \"%@\" is not supported.",cfm];
			}

			[algorithms setObject:[[PDFNoAlgorithm new] autorelease] forKey:@"Identity"];

			stringalgorithm=[[algorithms objectForKey:[encrypt stringForKey:@"StrF" default:@"Identity"]] retain];
			streamalgorithm=[[algorithms objectForKey:[encrypt stringForKey:@"StmF" default:@"Identity"]] retain];
		}

		needspassword=![self setPassword:@""];
	}
	return self;
}

-(void)dealloc
{
	[encrypt release];
	[permanentid release];
	[password release];
	[keys release];
	[algorithms release];
	[super dealloc];
}

-(BOOL)needsPassword { return needspassword; }

-(BOOL)setPassword:(NSString *)newpassword
{
	[password autorelease];
	password=[newpassword retain];

	[keys removeAllObjects];

	NSData *key;
	if(version==1) key=[self documentKeyOfLength:5];
	else if(version==2) key=[self documentKeyOfLength:[encrypt intValueForKey:@"Length" default:40]/8];
	else if(version==4) key=[self documentKeyOfLength:16]; // This is total bullshit, but the specs don't say what to actually do for version 4.

	NSData *udata=[[encrypt objectForKey:@"U"] rawData];

	if(revision==2)
	{
		XADRC4Engine *rc4=[XADRC4Engine engineWithKey:key];
		NSData *test=[rc4 encryptedData:udata];
		return [test length]==32&&!memcmp(PDFPasswordPadding,[test bytes],32);
	}
	else
	{
		PDFMD5Engine *md5=[PDFMD5Engine engine];
		[md5 updateWithBytes:PDFPasswordPadding length:32];
		[md5 updateWithData:permanentid];

		const unsigned char *keybytes=[key bytes];
		NSData *data=[md5 digest];

		for(int i=0;i<20;i++)
		{
			unsigned char newkey[16];
			for(int j=0;j<16;j++) newkey[j]=keybytes[j]^i;

			XADRC4Engine *rc4=[XADRC4Engine engineWithKey:[NSData dataWithBytesNoCopy:newkey length:16 freeWhenDone:NO]];
			data=[rc4 encryptedData:data];
		}

		return !memcmp([data bytes],[udata bytes],16);
	}
}

-(NSData *)documentKeyOfLength:(int)length
{
	if(length<5) length=5;
	if(length>16) length=16;

	NSNumber *num=[NSNumber numberWithInt:length];
	NSData *key=[keys objectForKey:num];
	if(key) return key;

	PDFMD5Engine *md5=[PDFMD5Engine engine];

	NSData *passdata=[password dataUsingEncoding:NSISOLatin1StringEncoding];
	int passlength=[passdata length];
	const unsigned char *passbytes=[passdata bytes];
	if(passlength<32)
	{
		[md5 updateWithBytes:passbytes length:passlength];
		[md5 updateWithBytes:PDFPasswordPadding length:32-passlength];
	}
	else [md5 updateWithBytes:passbytes length:32];

	[md5 updateWithData:[[encrypt objectForKey:@"O"] rawData]];

	unsigned int p=[encrypt unsignedIntValueForKey:@"P" default:0];
	unsigned char pbytes[4]={p&0xff,(p>>8)&0xff,(p>>16)&0xff,p>>24};
	[md5 updateWithBytes:pbytes length:4];

	[md5 updateWithData:permanentid];

	if(revision>=4)
	{
		/*if(!metadataencrypt) [md5 updateWithBytes:"\377\377\377\377" length:4];*/
	}

	NSData *digest=[md5 digest];

	if(revision>=3)
	for(int i=0;i<50;i++) digest=[PDFMD5Engine digestForBytes:[digest bytes] length:length];

	key=[digest subdataWithRange:NSMakeRange(0,length)];
	[keys setObject:key forKey:num];

	return key;
}

-(NSData *)keyOfLength:(int)length forReference:(PDFObjectReference *)ref AES:(BOOL)aes
{
	int num=[ref number];
	int gen=[ref generation];
	unsigned char refbytes[5]={num&0xff,(num>>8)&0xff,(num>>16)&0xff,gen&0xff,(gen>>8)&0xff};

	PDFMD5Engine *md5=[PDFMD5Engine engine];
	[md5 updateWithData:[self documentKeyOfLength:length]];
	[md5 updateWithBytes:refbytes length:5];

	if(aes) [md5 updateWithBytes:"sAlT" length:4];

	if(length<11) return [[md5 digest] subdataWithRange:NSMakeRange(0,length+5)];
	else return [md5 digest];
}




-(NSData *)decryptString:(PDFString *)string
{
	return [stringalgorithm decryptedData:[string rawData] reference:[string reference]];
}

-(CSHandle *)decryptStream:(PDFStream *)stream
{
	NSString *filter=[[[stream dictionary] arrayForKey:@"Filter"] objectAtIndex:0];
	if([filter isEqual:@"Crypt"])
	{
		NSDictionary *decodeparms=[[[stream dictionary] arrayForKey:@"DecodeParms"] objectAtIndex:0];
		PDFEncryptionAlgorithm *algorithm=[algorithms objectForKey:[decodeparms stringForKey:@"Name" default:@"Identity"]];
		return [algorithm decryptedHandle:[stream rawHandle] reference:[stream reference]];
	}
	else
	{
		return [streamalgorithm decryptedHandle:[stream rawHandle] reference:[stream reference]];
	}
}

@end




@implementation PDFEncryptionAlgorithm

-(NSData *)decryptedData:(NSData *)data reference:(PDFObjectReference *)ref { return nil; }

-(CSHandle *)decryptedHandle:(CSHandle *)handle reference:(PDFObjectReference *)ref  { return nil; }

-(void)calculateKeyForPassword:(NSString *)password {};

@end



@implementation PDFNoAlgorithm

-(NSData *)decryptedData:(NSData *)data reference:(PDFObjectReference *)ref { return data; }

-(CSHandle *)decryptedHandle:(CSHandle *)handle reference:(PDFObjectReference *)ref  { return handle; }

@end



@implementation PDFStandardAlgorithm

-(id)initWithLength:(int)length handler:(PDFEncryptionHandler *)handler
{
	if(self=[super init])
	{
		parent=handler;
		keylength=length;
	}
	return self;
}

-(NSData *)keyForReference:(PDFObjectReference *)ref AES:(BOOL)aes
{
	return [parent keyOfLength:keylength forReference:ref AES:aes];
}

@end



@implementation PDFRC4Algorithm 

-(NSData *)decryptedData:(NSData *)data reference:(PDFObjectReference *)ref
{
	XADRC4Engine *rc4=[XADRC4Engine engineWithKey:[self keyForReference:ref AES:NO]];
	return [rc4 encryptedData:data];
}

-(CSHandle *)decryptedHandle:(CSHandle *)handle reference:(PDFObjectReference *)ref
{
	return [[[XADRC4Handle alloc] initWithHandle:handle key:[self keyForReference:ref AES:NO]] autorelease];
}

@end



@implementation PDFAESAlgorithm 

-(NSData *)decryptedData:(NSData *)data reference:(PDFObjectReference *)ref
{
	PDFAESHandle *handle=[[PDFAESHandle alloc] initWithHandle:[CSMemoryHandle memoryHandleForReadingData:data]
	key:[self keyForReference:ref AES:YES]];

	NSData *res=[handle remainingFileContents];

	[handle release];

	return res;
}

-(CSHandle *)decryptedHandle:(CSHandle *)handle reference:(PDFObjectReference *)ref
{
	return [[[PDFAESHandle alloc] initWithHandle:handle key:[self keyForReference:ref AES:YES]] autorelease];
}

@end

