#import "PGWebAdapter.h"

// Models
#import "PGNode.h"
#import "PGURLConnection.h"
#import "PGResourceIdentifier.h"

// Categories
#import "NSObjectAdditions.h"

@implementation PGWebAdapter

#pragma mark PGURLConnectionDelegate Protocol

- (void)connectionLoadingDidProgress:(PGURLConnection *)sender
{
	[[self node] AE_postNotificationName:PGNodeLoadingDidProgressNotification];
}
- (void)connectionDidClose:(PGURLConnection *)sender
{
	if(![_mainConnection isLoaded] || ![_faviconConnection isLoaded]) return;
	[[self identifier] setIcon:[[[NSImage alloc] initWithData:[_faviconConnection data]] autorelease]];
	[self loadFromData:[_mainConnection data] URLResponse:[_mainConnection response]];
	[_mainConnection release];
	_mainConnection = nil;
	[_faviconConnection release];
	_faviconConnection = nil;
	[self setIsDeterminingType:NO];
}

#pragma mark PGResourceAdapting

- (float)loadingProgress
{
	return [_mainConnection progress];
}

#pragma mark PGResourceAdapter

- (void)readFromData:(NSData *)data
        URLResponse:(NSURLResponse *)response
{
	if(data || response) return;
	NSURL *const URL = [[self identifier] URL];
	_mainConnection = [[PGURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:URL] delegate:self];
	_faviconConnection = [[PGURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"/favicon.ico" relativeToURL:URL] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15.0] delegate:self];
	[self setIsDeterminingType:YES];
}

#pragma mark NSObject

- (void)dealloc
{
	[_mainConnection cancel];
	[_mainConnection release];
	[_faviconConnection cancel];
	[_faviconConnection release];
	[super dealloc];
}

@end
