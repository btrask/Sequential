#import <Cocoa/Cocoa.h>

// Models
@class PGDocument;
@class PGNode;
@class PGContainerAdapter;
@class PGResourceIdentifier;
#import "PGExifEntry.h"
@class PGBookmark;

enum {
	PGWrongPassword   = -1,
	PGDataUnavailable = 0,
	PGDataAvailable   = 1
};
typedef int PGDataAvailability;

@protocol PGResourceAdapting

- (PGContainerAdapter *)parentAdapter;
- (PGDocument *)document;
- (PGNode *)parentNode;

- (PGResourceIdentifier *)identifier;
- (id)dataSource;

- (BOOL)isViewable;
- (float)loadingProgress;
- (BOOL)canGetImageData;
- (PGDataAvailability)getImageData:(out NSData **)outData;
- (NSArray *)exifEntries;
- (PGOrientation)orientation; // Incorporates the document's -baseOrientation.
- (BOOL)isResolutionIndependent;
- (void)clearCache;
- (BOOL)isContainer;

- (NSString *)lastPassword;
- (BOOL)expectsReturnedImage;
- (void)returnImage:(NSImage *)anImage error:(NSString *)error;

- (BOOL)hasViewableNodes;
- (BOOL)hasImageDataNodes; // Nodes that return YES from -canGetImageData.
- (unsigned)viewableNodeIndex;
- (unsigned)viewableNodeCount;
- (PGNode *)sortedViewableNodeFirst:(BOOL)first;
- (PGNode *)sortedViewableNodeNext:(BOOL)next;
- (PGNode *)nodeEquivalentToNode:(PGNode *)aNode;
- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident;
- (BOOL)isDescendantOfNode:(PGNode *)aNode;

- (void)addMenuItemsToMenu:(NSMenu *)aMenu;

- (char const *)unencodedSampleString;
- (NSStringEncoding)defaultEncoding;
- (void)setEncoding:(NSStringEncoding)encoding;

- (BOOL)canBookmark;
- (PGBookmark *)bookmark;
- (PGNode *)nodeForBookmark:(PGBookmark *)aBookmark;

- (void)sortOrderDidChange;

@end
