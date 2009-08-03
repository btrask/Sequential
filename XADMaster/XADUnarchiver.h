#import <Foundation/Foundation.h>

#import "XADArchive.h"


@interface XADUnarchiver:NSObject
{
	XADArchive *archive;
	NSString *dest;
}

+(XADUnarchiver *)unarchiverForArchive:(XADArchive *)archive;
+(XADUnarchiver *)unarchiverForFilename:(NSString *)filename;

-(id)initWithArchive:(XADArchive *)archive;
-(void)dealloc;

-(id)delegate;
-(void)setDelegate:(id)delegate;

-(NSString *)destination;
-(void)setDestination:(NSString *)destination;

-(NSString *)password;
-(void)setPassword:(NSString *)password;

-(NSStringEncoding)encoding;
-(void)setEncoding:(NSStringEncoding)encoding;

-(void)unarchive;

@end



@interface NSObject (XADUnarchiverDelegate)

-(void)unarchiverNeedsPassword:(XADUnrchiver *)unarchiver;

-(BOOL)unarchiver:(XADUnarchiver *)unarchiver shouldStartUnarchivingEntry:(NSDictionary *)dict;
-(void)unarchiver:(XADUnarchiver *)unarchiver willStartUnarchivingEntry:(NSDictionary *)dict;
-(void)unarchiver:(XADUnarchiver *)unarchiver finishedUnarchivingEntry:(NSDictionary *)dict;
//-(void)unarchiver:(XADUnarchiver *)unarchiver failedToUnarchiveEntry:(NSDictionary *)dict;

//-(NSStringEncoding)unarchiver:(XADUnarchiver *)unarchiver encodingForString:(XADString *)data guess:(NSStringEncoding)guess confidence:(float)confidence;

/*-(XADAction)archive:(XADArchive *)archive nameDecodingDidFailForEntry:(int)n data:(NSData *)data;

-(BOOL)archiveExtractionShouldStop:(XADArchive *)archive;
-(BOOL)archive:(XADArchive *)archive shouldCreateDirectory:(NSString *)directory;
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithFile:(NSString *)file newFilename:(NSString **)newname;
-(XADAction)archive:(XADArchive *)archive entry:(int)n collidesWithDirectory:(NSString *)file newFilename:(NSString **)newname;
-(XADAction)archive:(XADArchive *)archive creatingDirectoryDidFailForEntry:(int)n;

-(void)archiveNeedsPassword:(XADArchive *)archive;
*/

-(void)unarchiver:(XADUnarchiver *)unarchiver progressReportForFile:(int)file fileProgress:(double)fileprogress totalProgress:(double)totalprogress;

@end
