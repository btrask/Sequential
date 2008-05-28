#import <Cocoa/Cocoa.h>
#import "PGResourceAdapter.h"

@interface PGGenericImageAdapter : PGResourceAdapter
{
	@private
	NSData       *_imageData;
	NSArray      *_exifEntries;
	PGOrientation _orientation;
	NSImage      *_cachedImage;
}

@end
