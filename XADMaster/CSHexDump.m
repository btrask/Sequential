#import "CSHexDump.h"

@implementation NSData (HexDump)

-(NSString *)hexDumpWithColumns:(int)cols
{
	NSMutableString *str=[NSMutableString string];
	unsigned int len=[self length];
	const unsigned char *bytes=[self bytes];
	int lines=(len+cols-1)/cols;

	for(int i=0;i<lines;i++)
	{
		[str appendFormat:@"%08x   ",i*cols];

		for(int j=0;j<cols;j++)
		{
			int offs=i*cols+j;
			if(offs>=len) [str appendString:@"  "];
			else [str appendFormat:@"%02x",bytes[i*cols+j]];
			if(j%4==3&&j!=cols-1) [str appendString:@" "];
		}

		[str appendString:@"   "];

		for(int j=0;j<cols;j++)
		{
			int offs=i*cols+j;
			if(offs>=len) [str appendString:@" "];
			else
			{
				int c=bytes[i*cols+j];
				if(c<0x20||(c>=0x80&&c<0xa0)) c='.';
				[str appendFormat:@"%c",c];
			}
		}

		if(i!=lines-1) [str appendString:@"\n"];
	}
	return str;
}

-(NSString *)description { return [NSString stringWithFormat:@"<\n%@\n>",[self hexDumpWithColumns:16]]; }

@end
