/* Copyright © 2007-2009, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGURLLoad.h"

// Other Sources
#import "PGFoundationAdditions.h"

#define PGMaxSimultaneousConnections 4

static NSString *PGUserAgent = nil;
static NSUInteger PGSimultaneousConnections = 0;

@interface PGActivity(PGURLLoadStarting)

- (BOOL)PG_startNextURLLoad;

@end

@interface PGURLLoad(Private)

- (BOOL)_start;
- (void)_stop;

@end

@implementation PGURLLoad

#pragma mark +PGURLLoad

+ (NSString *)userAgent
{
	return [[PGUserAgent retain] autorelease];
}
+ (void)setUserAgent:(NSString *)aString
{
	if(aString == PGUserAgent) return;
	[PGUserAgent release];
	PGUserAgent = [aString copy];
}

#pragma mark -PGURLLoad

- (id)initWithRequest:(NSURLRequest *)aRequest parent:(id<PGActivityOwner>)parent delegate:(NSObject<PGURLLoadDelegate> *)delegate
{
	if((self = [super init])) {
		_delegate = delegate;
		_loaded = NO;
		_request = [aRequest copy];
		_data = [[NSMutableData alloc] init];
		_activity = [[PGActivity alloc] initWithOwner:self];
		[_activity setParentActivity:[parent activity]];
		[[PGActivity applicationActivity] PG_startNextURLLoad];
	}
	return self;
}

#pragma mark -

- (NSObject<PGURLLoadDelegate> *)delegate
{
	return _delegate;
}
- (NSURLRequest *)request
{
	return [[_request retain] autorelease];
}
- (NSURLResponse *)response
{
	return [[_response retain] autorelease];
}
- (NSMutableData *)data
{
	return [[_data retain] autorelease];
}

#pragma mark -

- (void)cancelAndNotify:(BOOL)notify
{
	if([self loaded]) return;
	[self _stop];
	[_data release];
	_data = nil;
	if(notify) [[self delegate] loadDidCancel:self];
}
- (BOOL)loaded
{
	return _loaded;
}

#pragma mark -PGURLLoad(Private)

- (BOOL)_start
{
	if(_connection || [self loaded]) return NO;
	NSMutableURLRequest *const request = [[_request mutableCopy] autorelease];
	if([[self class] userAgent]) [request setValue:[[self class] userAgent] forHTTPHeaderField:@"User-Agent"];
	_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	[_connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:(NSString *)kCFRunLoopCommonModes];
	[_connection start];
	PGSimultaneousConnections++;
	return YES;
}
- (void)_stop
{
	if(!_connection) return;
	[_connection cancel];
	[_connection release];
	_connection = nil;
	PGSimultaneousConnections--;
	[_activity invalidate];
	[[PGActivity applicationActivity] PG_startNextURLLoad];
}

#pragma mark -NSObject

- (void)dealloc
{
	[self _stop];
	[_request release];
	[_response release];
	[_data release];
	[super dealloc];
}

#pragma mark -NSObject(NSURLConnectionDelegate)

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	NSParameterAssert(connection == _connection);
	[_response autorelease];
	_response = [response copy];
	[[self delegate] loadDidReceiveResponse:self];
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	NSParameterAssert(connection == _connection);
	[_data appendData:data];
	[[self delegate] loadLoadingDidProgress:self];
}
- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
	NSParameterAssert(connection == _connection);
	[self _stop];
	[_data release];
	_data = nil;
	[[self delegate] loadDidFail:self];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	NSParameterAssert(connection == _connection);
	_loaded = YES;
	[self _stop];
	[[self delegate] loadDidSucceed:self];
}

#pragma mark -<PGActivityOwner>

@synthesize activity = _activity;
- (NSString *)descriptionForActivity:(PGActivity *)activity
{
	return [[_request URL] absoluteString];
}
- (BOOL)activityShouldCancel:(PGActivity *)activity
{
	[self cancelAndNotify:YES];
	return YES;
}
- (CGFloat)progressForActivity:(PGActivity *)activity
{
	if([self loaded]) return 1.0f;
	if(!_response) return 0.0f;
	long long const expectedLength = [_response expectedContentLength];
	if(NSURLResponseUnknownLength == expectedLength) return 0.0f;
	return (CGFloat)[_data length] / (CGFloat)expectedLength;
}

@end

@implementation NSObject(PGURLLoadDelegate)

- (void)loadLoadingDidProgress:(PGURLLoad *)sender {}
- (void)loadDidReceiveResponse:(PGURLLoad *)sender {}
- (void)loadDidSucceed:(PGURLLoad *)sender {}
- (void)loadDidFail:(PGURLLoad *)sender {}
- (void)loadDidCancel:(PGURLLoad *)sender {}

@end

@implementation PGActivity(PGURLLoadStarting)

- (BOOL)PG_startNextURLLoad
{
	if(PGSimultaneousConnections >= PGMaxSimultaneousConnections) return YES;
	for(PGActivity *const activity in [self childActivities:NO]) {
		if([[activity owner] isKindOfClass:[PGURLLoad class]] && [(PGURLLoad *)[activity owner] _start]) return YES;
		if([activity PG_startNextURLLoad]) return YES;
	}
	return NO;
}

@end
