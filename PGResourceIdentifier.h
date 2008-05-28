#import <Cocoa/Cocoa.h>

// Models
@class PGSubscription;

extern NSString *const PGResourceIdentifierIconDidChangeNotification;
extern NSString *const PGResourceIdentifierDisplayNameDidChangeNotification;

@interface PGResourceIdentifier : NSObject <NSCoding>
{
	@private
	NSImage  *_icon;
	NSString *_displayName;
}

+ (id)resourceIdentifierWithURL:(NSURL *)URL;
+ (id)resourceIdentifierWithAliasData:(const uint8_t *)data length:(unsigned)length; // For backward compatability.

- (PGResourceIdentifier *)subidentifierWithIndex:(int)index;
- (PGResourceIdentifier *)superidentifier;

- (NSURL *)superURLByFollowingAliases:(BOOL)flag; // Our URL, or our superidentifier's otherwise.
- (NSURL *)URLByFollowingAliases:(BOOL)flag;
- (NSURL *)URL; // Equivalent to -URLByFollowingAliases:NO.
- (int)index;

- (BOOL)isFileIdentifier;

- (NSImage *)icon;
- (void)setIcon:(NSImage *)icon;
- (NSString *)displayName;
- (void)setDisplayName:(NSString *)aString;

- (PGSubscription *)subscription;
- (NSAttributedString *)attributedStringWithWithAncestory:(BOOL)flag;

@end
