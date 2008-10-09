/* Copyright © 2007-2008 The Sequential Project. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal with the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:
1. Redistributions of source code must retain the above copyright notice,
   this list of conditions and the following disclaimers.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimers in the
   documentation and/or other materials provided with the distribution.
3. Neither the name of The Sequential Project nor the names of its
   contributors may be used to endorse or promote products derived from
   this Software without specific prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGURLLoad.h"

// Other
#import "PGNonretainedObjectProxy.h"

// Categories
#import "NSObjectAdditions.h"

#define PGMaxSimultaneousConnections 4

static NSString *PGUserAgent = nil;
static unsigned PGSimultaneousConnections = 0;

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
      delegate:(id)anObject
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

- (id)delegate
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
	if(PGIsLeopardOrLater()) { // Ensure the connections keep loading in the various run loop modes on Leopard.
		_connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO];
		[_connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:PGCommonRunLoopsMode];
		[_connection start];
	} else _connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	PGSimultaneousConnections++;
	return YES;
}

#pragma mark PGLoading Protocol

- (NSString *)loadDescription
{
	return [[_request URL] absoluteString];
}
- (float)loadProgress
{
	if([self loaded]) return 1;
	if(!_response) return 0;
	long long const expectedLength = [_response expectedContentLength];
	if(-1 == expectedLength) return 0;
	return (float)[_data length] / expectedLength;
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

@implementation NSObject (PGURLLoadDelegate)

- (void)loadLoadingDidProgress:(PGURLLoad *)sender {}
- (void)loadDidReceiveResponse:(PGURLLoad *)sender {}
- (void)loadDidSucceed:(PGURLLoad *)sender {}
- (void)loadDidFail:(PGURLLoad *)sender {}
- (void)loadDidCancel:(PGURLLoad *)sender {}

@end

@interface NSObject (PGLoadingCategoryHack) <PGLoading>
@end

@implementation NSObject (PGURLLoadStarting)

- (BOOL)PG_startNextURLLoad
{
	if(PGSimultaneousConnections >= PGMaxSimultaneousConnections) return YES;
	NSObject<PGLoading> *subload;
	NSEnumerator *const subloadEnum = [[self subloads] objectEnumerator];
	while((subload = [subloadEnum nextObject])) if([subload PG_startNextURLLoad]) return YES;
	return NO;
}

@end
