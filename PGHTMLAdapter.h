#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#import "PGContainerAdapter.h"

@interface PGHTMLAdapter : PGContainerAdapter
{
	@private
	WebView *_webView;
	BOOL     _isLoading;
}

@end
