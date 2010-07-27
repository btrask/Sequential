#import "XADLZHSFXParsers.h"
#import "XADXORHandle.h"
#import "Scanning.h"

@implementation XADLZHAmigaSFXParser

+(int)requiredHeaderSize { return 48; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<48) return NO;

	return CSUInt32BE(&bytes[11*4])==0x53465821;
}

-(void)parse
{
	lha150r=NO;

	CSHandle *fh=[self handle];

	[fh seekToFileOffset:0x34];

	uint32_t offs=[fh readUInt32BE];
	if(offs==0x1914) lha150r=YES;
	[fh seekToFileOffset:offs];

	[super parse];
}

-(CSHandle *)handleAtDataOffsetForDictionary:(NSDictionary *)dict
{
	CSHandle *handle=[super handleAtDataOffsetForDictionary:dict];

	if(lha150r) // Handle obscured archives
	{
		return [[[XADXORHandle alloc] initWithHandle:handle
		password:[NSData dataWithBytes:"BOA\017" length:4]] autorelease];
	}
	else return handle;
}

-(NSString *)formatName { return @"Self-extracting Amiga LhA"; }

@end



@implementation XADLZHCommodore64SFXParser

+(int)requiredHeaderSize { return 0xe90; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<0xe90) return NO;

	return bytes[0]==0x01&&bytes[2]==0x28&&bytes[3]==0x1c&&
	       bytes[0xd30]=='1'&&bytes[0xd44]=='L'&&bytes[0xd45]=='H'&&bytes[0xd46]=='A'&&
		   bytes[0xe8b]=='-'&&bytes[0xe8c]=='l'&&bytes[0xe8d]=='h'&&bytes[0xe8f]=='-';
}

-(void)parse
{
	CSHandle *fh=[self handle];
	[fh seekToFileOffset:0xe89];
	[super parse];
}

-(NSString *)formatName { return @"Self-extracting Commodore 64 LhA"; }

@end



@implementation XADLZHSFXParser

+(int)requiredHeaderSize { return 84; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length>=44&&bytes[9*4]=='L'&&bytes[9*4+1]=='H'&&bytes[9*4+3]==0x27
	&&CSUInt32BE(bytes+10*4)==0x73205346) return YES;

	if(length>=40&&CSUInt32BE(bytes+8*4)==0x4c5a5353&&CSUInt32BE(bytes+9*4)==0x2073656c) return YES;

	if(length>=18&&CSUInt32BE(bytes+6)==0x53465820&&CSUInt32BE(bytes+10)==0x6f66204c
	&&CSUInt32BE(bytes+14)==0x48617263) return YES;

	if(length>=84&&bytes[9*4+1]=='L'&&bytes[9*4+2]=='H'&&CSUInt32BE(bytes+19*4)==0x6e616d65
	&&CSUInt32BE(bytes+20*4)==0x20746f20) return YES;

	return NO;
}

static int MatchLZHSignature(const uint8_t *bytes,int available,off_t offset,void *state)
{
	if(available<5) return NO;
	return bytes[0]=='-'&&bytes[1]=='l'&&(bytes[2]=='h'||bytes[2]=='z')&&bytes[4]=='-';
}

-(void)parse
{
	if(![[self handle] scanUsingMatchingFunction:MatchLZHSignature maximumLength:3])
	[XADException raiseUnknownException];

	[super parse];
}

-(NSString *)formatName { return @"Self-extracting LZH"; }

@end

