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

// Categories
#import "NSObjectAdditions.h"

#define PGMaxSimultaneousConnections 4

static NSString *PGUserAgent = nil;
static NSUInteger PGSimultaneousConnections = 0;

@interface NSObject (PGURLLoadStarting)

- (BOOL)PG_startNextURLLoad;

@end

@interface PGURLLoad (Private)

- (void)_stop;

@end

@implementation PGURLLoad

#pragma mark Class Methods

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

#pragma mark Instance Methods

- (id)initWithRequest:(NSURLRequest *)aRequest
      parentLoad:(id<PGLoading>)parent
      delegate:(NSObject<PGURLLoadDelegate> *)anObject
{
	if((self = [super init])) {
		_parentLoad = parent;
		_delegate = anObject;
		_loaded = NO;
		_request = [aRequest copy];
		_data = [[NSMutableData alloc] init];
		[[self parentLoad] setSubload:self isLoading:YES];
		[[PGLoadManager sharedLoadManager] PG_startNextURLLoad];
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

#pragma mark Private Protocol

- (void)_stop
{
	if(!_connection) return;
	[_connection cancel];
	[_connection release];
	_connection = nil;
	PGSimultaneousConnections--;
	[[self parentLoad] setSubload:self isLoading:NO];
	[[PGLoadManager sharedLoadManager] PG_startNextURLLoad];
}

#pragma mark PGURLLoadStarting Protocol

- (BOOL)PG_startNextURLLoad
{
	if([super PG_startNextURLLoad]) return YES;
	if(_connection || [self loaded]) return NO;
	NSMutableURLRequest *const request = [[_request mutableCopy] autorelease];
	if([[self class] userAgent]) [request setValue:[[self class] userAgent] forHTTPHeaderField:@"User-Agent"];
	_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
	[_connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:(NSString *)kCFRunLoopCommonModes];
	[_connection start];
	PGSimultaneousConnections++;
	return YES;
}

#pragma mark PGLoading Protocol

- (NSString *)loadDescription
{
	return [[_request URL] absoluteString];
}
- (CGFloat)loadProgress
{
	if([self loaded]) return 1.0f;
	if(!_response) return 0.0f;
	long long const expectedLength = [_response expectedContentLength];
	if(-1 == expectedLength) return 0.0f;
	return (CGFloat)[_data length] / (CGFloat)expectedLength;
}
- (id<PGLoading>)parentLoad
{
	return _parentLoad;
}
- (NSArray *)subloads
{
	return nil;
}
- (void)setSubload:(id<PGLoading>)obj isLoading:(BOOL)flag {}
- (void)prioritizeSubload:(id<PGLoading>)obj {}
- (void)cancelLoad
{
	[self cancelAndNotify:YES];
}

#pragma mark NSURLConnectionDelegate Protocol

- (void)connection:(NSURLConnection *)connection
        didReceiveResponse:(NSURLResponse *)response
{
	NSParameterAssert(connection == _connection);
	[_response autorelease];
	_response = [response copy];
	[[self delegate] loadDidReceiveResponse:self];
}
- (void)connection:(NSURLConnection *)connection
	didReceiveData:(NSData *)data
{
	NSParameterAssert(connection == _connection);
	[_data appendData:data];
	[[self delegate] loadLoadingDidProgress:self];
}
- (void)connection:(NSURLConnection *)connection
	didFailWithError:(NSError *)error
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

#pragma mark NSObject

- (void)dealloc
{
	[self _stop];
	[_request release];
	[_response release];
	[_data release];
	[super dealloc];
}

@end

@implementation NSObject(PGURLLoadDelegate)

- (void)loadLoadingDidProgress:(PGURLLoad *)sender {}
- (void)loadDidReceiveResponse:(PGURLLoad *)sender {}
- (void)loadDidSucceed:(PGURLLoad *)sender {}
- (void)loadDidFail:(PGURLLoad *)sender {}
- (void)loadDidCancel:(PGURLLoad *)sender {}

@end

@interface NSObject(PGLoadingCategoryHack) <PGLoading>
@end

@implementation NSObject(PGURLLoadStarting)

- (BOOL)PG_startNextURLLoad
{
	if(PGSimultaneousConnections >= PGMaxSimultaneousConnections) return YES;
	for(NSObject<PGLoading> *const subload in [self subloads]) if([subload PG_startNextURLLoad]) return YES;
	return NO;
}

@end
