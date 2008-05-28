#import <Cocoa/Cocoa.h>
#import "PGResourceAdapter.h"

// Models
#import "PGPrefObject.h"'

@interface PGContainerAdapter : PGResourceAdapter
{
	@private
	NSArray        *_sortedChildren;
	NSArray        *_unsortedChildren;
	PGSortOrder     _unsortedOrder;
}

- (NSArray *)sortedChildren;
- (NSArray *)unsortedChildren;
- (void)setUnsortedChildren:(NSArray *)anArray presortedOrder:(PGSortOrder)order;

- (PGNode *)childForURL:(NSURL *)aURL;
- (unsigned)viewableIndexOfNode:(PGNode *)aNode;
- (PGNode *)next:(BOOL)next sortedViewableNodeBeyond:(PGNode *)node;

@end
