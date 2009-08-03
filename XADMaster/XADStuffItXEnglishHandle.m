#import "XADStuffItXEnglishHandle.h"
#import "XADException.h"
#import "SystemSpecific.h"

@implementation XADStuffItXEnglishHandle

+(NSData *)dictionaryData
{
	static NSData *dictionary=nil;
	if(!dictionary) dictionary=[[NSData alloc] initWithContentsOfFile:PathForExternalResource(@"sitx_english.dat")];
	return dictionary;
}

-(void)resetByteStream
{
	caseflag=YES;
	wordoffs=wordlen=0;

	esccode=CSInputNextByte(input);
	wordcode=CSInputNextByte(input);
	firstcode=CSInputNextByte(input);
	uppercode=CSInputNextByte(input);
}

-(uint8_t)produceByteAtOffset:(off_t)pos
{
	if(wordoffs<wordlen) return wordbuf[wordoffs++];

	if(CSInputAtEOF(input)) CSByteStreamEOF(self);

	int c=CSInputNextByte(input);

	if(c==esccode)
	{
		caseflag=NO;
		return CSInputNextByte(input);
	}
	else if(c==wordcode||c==firstcode||c==uppercode)
	{
		int c2,index=0;
		for(;;)
		{
			if(CSInputAtEOF(input)) { c2=-1; break; }

			c2=CSInputNextByte(input);
			if((c2<'A'||c2>'Z')&&(c2<'a'||c2>'z')) break;

			index*=52;
			if(c2<='Z') index+=c2-'A'+26+1;
			else index+=c2-'a'+1;
		}

		NSData *dictionary=[XADStuffItXEnglishHandle dictionaryData];
		if(!dictionary) [XADException raiseNotSupportedException];

		const uint8_t *dictptr=[dictionary bytes];
		int numentries=CSUInt32BE(dictptr);

		if(index>=numentries) [XADException raiseIllegalDataException];

		int dictval=(dictptr[index*3+4]<<16)|(dictptr[index*3+5]<<8)|dictptr[index*3+6];
		int dictoffs=dictval&0x7ffff;
		wordlen=dictval>>19;

		memcpy(wordbuf,&dictptr[4+3*numentries+dictoffs],wordlen);
		wordoffs=0;

		if(c==uppercode)
		{
			for(int i=0;i<wordlen;i++) wordbuf[i]-=32;
		}
		else if(c==firstcode)
		{
			wordbuf[0]-=32;
		}

		if(caseflag)
		{
			if(wordbuf[0]>='A'&&wordbuf[0]<='Z') wordbuf[0]+=32;
			else if(wordbuf[0]>='a'&&wordbuf[0]<='z') wordbuf[0]-=32;
		}

		if(c2==esccode) c2=CSInputNextByte(input);

		if(c2!=-1) wordbuf[wordlen++]=c2;

		if(c2=='.'||c2=='?'||c2=='!') caseflag=YES;
		else caseflag=NO;

		return wordbuf[wordoffs++];
	}
	else
	{
		if(caseflag)
		{
			if(c>='A'&&c<='Z')
			{
				c+=32;
				caseflag=NO;
			}
			else if(c>='a'&&c<='z')
			{
				c-=32;
				caseflag=NO;
			}
			else caseflag=YES; // useless
		}

		if(c=='.'||c=='?'||c=='!') caseflag=YES;
		else if(c!=' '&&c!='\n'&&c!='\r'&&c!='\t') caseflag=NO;

		return c;
	}
}

@end
