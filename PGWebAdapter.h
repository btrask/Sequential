#import <Cocoa/Cocoa.h>
#import "PGResourceAdapter.h"

// Models
@class PGURLConnection;

@interface PGWebAdapter : PGResourceAdapter
{
	@private
	PGURLConnection *_mainConnection;
	PGURLConnection *_faviconConnection;
}

@end
