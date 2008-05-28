#import <Cocoa/Cocoa.h>
#import <mac/XADArchive.h>
#import "PGContainerAdapter.h"

@interface PGArchiveAdapter : PGContainerAdapter
{
	@private
	XADArchive        *_archive;
	NSMutableIndexSet *_remainingIndexes;
	NSStringEncoding   _guessedEncoding;
	BOOL               _isSubarchive;
	BOOL               _hasCreatedChildren;
}

- (XADArchive *)archive;
- (NSArray *)nodesUnderPath:(NSString *)path parentAdapter:(PGContainerAdapter *)parent;
- (void)setIsSubarchive:(BOOL)flag;

@end

@interface PGArchiveResourceAdapter : PGResourceAdapter

@end
