#import <Cocoa/Cocoa.h>

// Models
@class PGNode;
@class PGResourceIdentifier;

@interface PGBookmark : NSObject <NSCoding>
{
	@private
	PGResourceIdentifier *_documentIdentifier;
	PGResourceIdentifier *_fileIdentifier;
	NSString             *_backupDisplayName;
}

- (id)initWithNode:(PGNode *)aNode;

- (PGResourceIdentifier *)documentIdentifier;
- (PGResourceIdentifier *)fileIdentifier;

- (NSString *)displayName;
- (BOOL)isValid;

@end
