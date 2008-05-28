#import <Cocoa/Cocoa.h>

@interface PGURLConnection : NSObject // Wraps NSURLConnection so only a few connections are active at a time.
{
	@private
	NSURLRequest  *_request;
	NSURLResponse *_response;
	NSMutableData *_data;
	BOOL           _isLoaded;
	id             _delegate;
}

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)aString;

- (id)initWithRequest:(NSURLRequest *)aRequest delegate:(id)anObject;
- (NSURLRequest *)request;
- (id)delegate;
- (NSURLResponse *)response;
- (NSMutableData *)data;
- (BOOL)isLoaded;
- (float)progress;
- (void)prioritize;
- (void)cancel;

@end

@interface NSObject (PGURLConnectionDelegate)

- (void)connectionDidReceiveResponse:(PGURLConnection *)sender;
- (void)connectionLoadingDidProgress:(PGURLConnection *)sender;
- (void)connectionDidClose:(PGURLConnection *)sender;

@end
