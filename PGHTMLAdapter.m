#import "PGHTMLAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "DOMNodeAdditions.h"

@implementation PGHTMLAdapter

#pragma mark WebFrameLoadDelegate Protocol

- (void)webView:(WebView *)sender
        didFailProvisionalLoadWithError:(NSError *)error
        forFrame:(WebFrame *)frame
{
	[self webView:sender didFailLoadWithError:error forFrame:frame];
}
- (void)webView:(WebView *)sender
        didFailLoadWithError:(NSError *)error
        forFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[_webView release];
	_webView = nil;
	_isLoading = NO;
	[self noteIsViewableDidChange];
}

- (void)webView:(WebView *)sender
        didFinishLoadForFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[[self identifier] setDisplayName:[[frame dataSource] pageTitle]];
	DOMDocument *const doc = [frame DOMDocument];
	NSMutableArray *const URLs = [NSMutableArray array];
	[doc AE_getLinkedURLs:URLs validExtensions:[[PGDocumentController sharedDocumentController] supportedExtensions]];
	if(![URLs count]) [doc AE_getEmbeddedImageURLs:URLs];
	if([URLs count]) {
		NSMutableArray *const pages = [NSMutableArray array];
		NSURL *URL;
		NSEnumerator *const URLEnum = [URLs objectEnumerator];
		while((URL = [URLEnum nextObject])) {
			PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:[PGResourceIdentifier resourceIdentifierWithURL:URL] adapterClass:nil dataSource:nil load:YES] autorelease];
			if(node) [pages addObject:node];
		}
		[self setUnsortedChildren:pages presortedOrder:PGUnsorted];
	}
	[_webView autorelease];
	_webView = nil;
	_isLoading = NO;
	[self noteIsViewableDidChange];
}

#pragma mark PGResourceAdapting

- (BOOL)isViewable
{
	return _isLoading || [super isViewable];
}

#pragma mark PGResourceAdapter

- (void)readFromData:(NSData *)data
        URLResponse:(NSURLResponse *)response
{
	NSParameterAssert(!_webView);
	_webView = [[WebView alloc] initWithFrame:NSZeroRect];
	[_webView setFrameLoadDelegate:self];
	WebPreferences *const prefs = [WebPreferences standardPreferences];
	[prefs setPlugInsEnabled:NO];
	[prefs setJavaScriptCanOpenWindowsAutomatically:NO];
	[prefs setLoadsImagesAutomatically:NO];
	[_webView setPreferences:prefs];
	[[_webView mainFrame] loadData:data MIMEType:[response MIMEType] textEncodingName:[response textEncodingName] baseURL:[response URL]];
	_isLoading = YES;
	[self noteIsViewableDidChange];
}

#pragma mark NSObject

- (void)dealloc
{
	[_webView release];
	[super dealloc];
}

@end
