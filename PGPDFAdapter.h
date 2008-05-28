#import <Cocoa/Cocoa.h>
#import "PGContainerAdapter.h"

@interface PGPDFAdapter : PGContainerAdapter
{
	@private
	NSImage       *_image;
	NSPDFImageRep *_rep;
}

@end

@interface PGPDFPageAdapter : PGResourceAdapter

@end
