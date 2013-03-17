#import <Foundation/Foundation.h>
#import "UniversalDetector.h"

int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	UniversalDetector *detector=[UniversalDetector detector];

	for(int i=1;i<argc;i++)
	{
		NSData *data=[NSData dataWithContentsOfFile:[NSString stringWithUTF8String:argv[i]]];
		[detector analyzeData:data];
	}

	#ifdef __APPLE__
	printf("%s (%d) %f\n",[[detector MIMECharset] UTF8String],(int)[detector encoding],[detector confidence]);
	#else
	printf("%s %f\n",[[detector MIMECharset] UTF8String],[detector confidence]);
	#endif

	[pool release];
	return 0;
}
