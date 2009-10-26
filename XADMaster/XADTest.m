#import <XADMaster/XADArchive.h>

@interface TestDelegate:NSObject
@end

@implementation TestDelegate

#if 0

-(NSStringEncoding)archive:(XADArchive *)archive encodingForName:(const char *)bytes guess:(NSStringEncoding)guess confidence:(float)confidence
{ NSLog(@"archive:encodingForFilename:%s guess:%d:",bytes,guess); return guess; }
-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n bytes:(const char *)bytes
{ NSLog(@"archive:(XADArchive *)archive nameDecodingDidFailForEntry:%d",n); return XADSkip; }

-(BOOL)archiveExtractionShouldStop:(XADArchive *)archive
{ return NO; }
-(BOOL)archive:(XADArchive *)archive shouldCreateDirectory:(NSString *)directory
{ NSLog(@"archive:shouldCreateDirectory:%@",directory); return YES; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname { return XADOverwrite; }
{ NSLog(@"archive:entry:%d collidesWithFile:%@ newFilename:",n,file); return XADSkip; }
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname { return XADSkip; }
{ NSLog(@"archive:entry:%d collidesWithDirectory:%@ newFilename:",n,file); return XADSkip; }
-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n
{ NSLog(@"archive:creatingDirectoryDidFailForEntry:%d",n); return XADSkip; }

-(void)archive:(XADArchive *)archive extractionOfEntryWillStart:(int)n
{ NSLog(@"archive:extractionOfEntryWillStart:%d",n); }
-(void)archive:(XADArchive *)archive extractionProgressForEntry:(int)n bytes:(xadSize)bytes of:(xadSize)total
{ NSLog(@"archive:extractionProgressForEntry:%d bytes:%qu of:%qu",n,bytes,total); }
-(void)archive:(XADArchive *)archive extractionOfEntryDidSucceed:(int)n
{ NSLog(@"archive:extractionOfEntryDidSucceed:%d",n); }

-(void)archive:(XADArchive *)archive extractionProgressBytes:(xadSize)bytes of:(xadSize)total
{ NSLog(@"archive:extractionProgressBytes:%qu of:%qu",bytes,total); }
-(void)archive:(XADArchive *)archive extractionProgressFiles:(int)files of:(int)total
{ NSLog(@"archive:extractionProgressFiles:%d of:%d",files,total); }
-(void)archive:(XADArchive *)archive immediateExtractionInputProgressBytes:(xadSize)bytes of:(xadSize)total {}
{ NSLog(@"archive:immediateExtractionInputProgressBytes:%qu of:%qu",bytes,total); }

#endif

-(XADAction)archive:(XADArchive *)archive extractionOfEntryDidFail:(int)n error:(xadERROR)error
{ NSLog(@"archive:extractionOfEntryDidFail:%d error:%@",n,[archive describeError:error]); return XADSkip; }

-(XADAction)archive:(XADArchive *)archive extractionOfResourceForkForEntryDidFail:(int)n error:(xadERROR)error
{ NSLog(@"archive:extractionOfResourceForkEntryDidFail:%d error:%@",n,[archive describeError:error]); return XADSkip; }

@end

int main(int argc,char **argv)
{
	NSAutoreleasePool *pool=[[NSAutoreleasePool alloc] init];

	if(argc<2)
	{
/*		struct xadMasterBase *xmb=xadOpenLibrary(11);
		struct xadClient *client=xadGetClientInfo(xmb);

		while(client)
		{
			printf("%s\n",client->xc_ArchiverName);
			client=client->xc_Next;
		}

		return 0;*/
	}

	NSString *filename,*destination;
	filename=[NSString stringWithUTF8String:argv[1]];
	if(argc>=3) destination=[NSString stringWithUTF8String:argv[2]];
	else destination=@"";

XADError error;
	XADArchive *archive=archive = [[XADArchive alloc] initWithFile:filename error:&error];
	//XADArchive *archive=[XADArchive recursiveArchiveForFile:filename];

	[archive setDelegate:[[TestDelegate alloc] init]];

	printf("%s\n",[[archive description] UTF8String]);

	int n=[archive numberOfEntries];

	if(n==1&&[[[archive nameOfEntry:0] pathExtension] isEqual:@"tar"])
	{
		[archive extractArchiveEntry:0 to:destination];
	}
	else
	{
		for(int i=0;i<n;i++)
		{
			printf("%s\n",[[archive nameOfEntry:i] UTF8String]);
		}
		[archive extractTo:destination];

//		for(int i=1;i<n;i+=2) [archive extractEntry:i to:destination];
//		for(int i=0;i<n;i+=2) [archive extractEntry:i to:destination];
	}


	[pool release];
	return 0;
}
