#import "XADBzip2Parser.h"
#import "CSBzip2Handle.h"

@implementation XADBzip2Parser

+(int)requiredHeaderSize { return 10; }

+(BOOL)recognizeFileWithHandle:(CSHandle *)handle firstBytes:(NSData *)data name:(NSString *)name;
{
	const uint8_t *bytes=[data bytes];
	int length=[data length];

	if(length<10) return NO;

	if(bytes[0]=='B'&&bytes[1]=='Z'&&bytes[2]=='h'&&bytes[3]>='1'&&bytes[3]<='9')
	{
		if(bytes[4]==0x31&&bytes[5]==0x41&&bytes[6]==0x59
		&&bytes[7]==0x26&&bytes[8]==0x53&&bytes[9]==0x59) return YES;

		if(bytes[4]==0x17&&bytes[5]==0x72&&bytes[6]==0x45
		&&bytes[7]==0x38&&bytes[8]==0x50&&bytes[9]==0x90) return YES;
	}
	return NO;
}

-(void)parse
{
	NSString *name=[self name];
	NSString *extension=[[name pathExtension] lowercaseString];
	NSString *contentname;
	if([extension isEqual:@"tbz"]||[extension isEqual:@"tbz2"]) contentname=[[name stringByDeletingPathExtension] stringByAppendingPathExtension:@"tar"];
	else contentname=[name stringByDeletingPathExtension];

	// TODO: set no filename flag
	NSMutableDictionary *dict=[NSMutableDictionary dictionaryWithObjectsAndKeys:
		[self XADPathWithUnseparatedString:contentname],XADFileNameKey,
		[self XADStringWithString:@"Bzip2"],XADCompressionNameKey,
	nil];

	if([contentname matchedByPattern:@"\\.(tar|cpio)$" options:REG_ICASE])
	[dict setObject:[NSNumber numberWithBool:YES] forKey:XADIsArchiveKey];

	off_t filesize=[[self handle] fileSize];
	if(filesize!=CSHandleMaxLength)
	[dict setObject:[NSNumber numberWithUnsignedLongLong:filesize] forKey:XADCompressedSizeKey];

	[self addEntryWithDictionary:dict];
}

-(CSHandle *)handleForEntryWithDictionary:(NSDictionary *)dictionary wantChecksum:(BOOL)checksum
{
	CSHandle *handle=[self handle];
	[handle seekToFileOffset:0];
	return [CSBzip2Handle bzip2HandleWithHandle:handle];
}

-(NSString *)formatName { return @"Bzip2"; }

@end

/*

#define BZIP2SFX_SEARCHSIZE (5000)
TODO: SFX

XADRECOGDATA(bzip2SFX) {
  if(data[0] == '#' && data[1] == '!') {
    int i;
    if (size < 17) return 0;
    if (size > BZIP2SFX_SEARCHSIZE) size = BZIP2SFX_SEARCHSIZE;
    size -= 10;
    for (i = 2; i < (int) size; i++) {
      const xadUINT8 *p = &data[i];
      if ((p[0] == 'B') && (p[1] == 'Z') && (p[2] == 'h') &&
          ((p[3] >=  '1') && (p[3] <= '9')) &&
          (((p[4] == 0x31) && (p[5] == 0x41) && (p[6] == 0x59) &&
            (p[7] == 0x26) && (p[8] == 0x53) && (p[9] == 0x59)) ||
           ((p[4] == 0x17) && (p[5] == 0x72) && (p[6] == 0x45) &&
            (p[7] == 0x38) && (p[8] == 0x50) && (p[9] == 0x90))
          )
         )
      {
        return 1;
      }
    }
  }
  return 0;
}*/