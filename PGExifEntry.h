#import <Cocoa/Cocoa.h>

enum {
	PGUpright      = 0,
	PGFlippedVert  = 1 << 0,
	PGFlippedHorz  = 1 << 1,
	PGRotated90CC  = 1 << 2, // Counter-Clockwise.
	PGUpsideDown   = PGFlippedVert | PGFlippedHorz,
	PGRotated270CC = PGFlippedVert | PGFlippedHorz | PGRotated90CC
};
typedef unsigned PGOrientation;

PGOrientation PGAddOrientation(PGOrientation o1, PGOrientation o2);

@interface PGExifEntry : NSObject
{
	@private
	NSString *_label;
	NSString *_value;
}

+ (NSData *)exifDataWithImageData:(NSData *)data;
+ (void)getEntries:(out NSArray **)outEntries orientation:(out PGOrientation *)outOrientation forImageData:(NSData *)data;

- (id)initWithLabel:(NSString *)label value:(NSString *)value;
- (NSString *)label;
- (NSString *)value;
- (NSComparisonResult)compare:(PGExifEntry *)anEntry;

@end
