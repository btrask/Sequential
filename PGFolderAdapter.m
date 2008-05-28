#import "PGFolderAdapter.h"
#import <sys/event.h>

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Categories
#import "NSStringAdditions.h"

@implementation PGFolderAdapter

#pragma mark PGResourceAdapter

- (void)readFromData:(NSData *)data
        URLResponse:(NSURLResponse *)response
{
	NSParameterAssert(!data);
	NSParameterAssert(!response);
	NSMutableArray *const oldPages = [[[self unsortedChildren] mutableCopy] autorelease];
	NSMutableArray *const newPages = [NSMutableArray array];
	NSString *const path = [[[self identifier] URLByFollowingAliases:YES] path];
	NSString *pathComponent;
	NSEnumerator *const pathComponentEnum = [[[NSFileManager defaultManager] directoryContentsAtPath:path] objectEnumerator];
	while((pathComponent = [pathComponentEnum nextObject])) {
		NSURL *const pageURL = [[path stringByAppendingPathComponent:pathComponent] AE_fileURL];
		LSItemInfoRecord info;
		if(LSCopyItemInfoForURL((CFURLRef)pageURL, kLSRequestBasicFlagsOnly, &info) != noErr || info.flags & kLSItemInfoIsInvisible) continue;
		PGNode *node = [self childForURL:pageURL];
		if(node) [oldPages removeObjectIdenticalTo:node];
		else node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:[PGResourceIdentifier resourceIdentifierWithURL:pageURL] adapterClass:nil dataSource:nil load:YES] autorelease];
		if(node) [newPages addObject:node];
	}
	[self setUnsortedChildren:newPages presortedOrder:PGUnsorted];
	if([self shouldReadContents]) [self readContents];
}
- (void)fileResourceDidChange:(unsigned)flags
{
//	PGNode *const node = [self node];
	if(flags & (NOTE_DELETE | NOTE_REVOKE)) NSBeep(); // TODO: Remove the node.
	else if(flags & NOTE_WRITE) [self readFromData:nil URLResponse:nil];
}

@end
