#import <Cocoa/Cocoa.h>

enum {
	PGMinXMinYCorner = 0,
	PGMaxXMinYCorner = 1
};
typedef int PGOSDCorner;

@interface PGOSDView : NSView
{
	@private
	NSString   *fMessageText;
	unsigned    fIndex;
	unsigned    fCount;
	PGOSDCorner fOrigin;
	NSSize      fOriginOffset;
}

- (NSAttributedString *)displayText;

- (NSString *)messageText;
- (void)setMessageText:(NSString *)aString;

- (unsigned)index;
- (void)setIndex:(unsigned)anInt;
- (unsigned)count;
- (void)setCount:(unsigned)anInt;
- (BOOL)displaysProgressIndicator;

- (PGOSDCorner)origin;
- (NSSize)originOffset;
- (void)setOrigin:(PGOSDCorner)aSide offset:(NSSize)aSize; // Does NOT actually move the window.

@end
