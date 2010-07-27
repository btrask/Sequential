#import "NSStringPrinting.h"

#ifdef __MINGW32__
#include <windows.h>
#endif

@implementation NSString (Printing)

-(void)print
{
	[self printToFile:stdout];
}

-(NSString *)stringByEscapingControlCharacters
{
	NSMutableString *res=[NSMutableString string];
	int length=[self length];
	for(int i=0;i<length;i++)
	{
		unichar c=[self characterAtIndex:i];
		if(c<32) [res appendFormat:@"^%c",c+64];
		else [res appendFormat:@"%C",c];
	}
	return res;
}

-(NSArray *)linesWrappedToWidth:(int)width
{
	int length=[self length];
	NSMutableArray *wrapped=[NSMutableArray array];

	int linestartpos=0,lastspacepos=-1;
	for(int i=0;i<length;i++)
	{
		unichar c=[self characterAtIndex:i];
		if(c==' ') lastspacepos=i;

		int linelength=i-linestartpos;
		if(linelength>=width && lastspacepos!=-1)
		{
			[wrapped addObject:[self substringWithRange:NSMakeRange(linestartpos,lastspacepos-linestartpos)]];
			linestartpos=lastspacepos+1;
			lastspacepos=-1;
		}
	}

	if(linestartpos<length)
	[wrapped addObject:[self substringWithRange:NSMakeRange(linestartpos,length-linestartpos)]];

	return wrapped;
}




#ifdef __MINGW32__

+(int)terminalWidth
{
	return 79; // Gah, too lazy to fix the weird Windos printing behaviour.
}

-(void)printToFile:(FILE *)fh
{
	int length=[self length];
	unichar buffer[length];
	[self getCharacters:buffer range:NSMakeRange(0,length)];

	int bufsize=WideCharToMultiByte(GetConsoleOutputCP(),0,buffer,length,NULL,0,NULL,NULL);
	char mbuffer[bufsize]; 
	WideCharToMultiByte(GetConsoleOutputCP(),0,buffer,length,mbuffer,bufsize,NULL,NULL);

	fwrite(mbuffer,bufsize,1,fh);
}

#else

#include <sys/ioctl.h>

+(int)terminalWidth
{
	#ifdef TIOCGSIZE
	struct ttysize ts;
	ioctl(0,TIOCGSIZE,&ts);
	return ts.ts_cols;
	#else
	struct winsize ws;
	ioctl(0,TIOCGWINSZ,&ws);
	return ws.ws_col;
	#endif
}

-(void)printToFile:(FILE *)fh
{
	int length=[self lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
	char buffer[length+1];
	[self getCString:buffer maxLength:length+1 encoding:NSUTF8StringEncoding];

	fwrite(buffer,length,1,fh);
}

#endif

@end
