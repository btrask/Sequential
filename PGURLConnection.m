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
#import "PGURLConnection.h"

// Other
#import "PGNonretainedObjectProxy.h"

// Categories
#import "NSObjectAdditions.h"

NSString *const PGURLConnectionConnectionsDidChangeNotification = @"PGURLConnectionConnectionsDidChange";

static NSString       *PGUserAgent          = nil;
static NSMutableArray *PGConnections        = nil;
static NSMutableArray *PGActiveConnections  = nil;
static NSMutableArray *PGPendingConnections = nil;

#define PGMaxSimultaneousConnections 4

@interface PGURLConnection (Private)

+ (void)_startConnection;
- (void)_stop;

@end

@implementation PGURLConnection

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

#pragma mark -

+ (NSArray *)connections
{
	return [PGActiveConnections arrayByAddingObjectsFromArray:PGPendingConnections];
}
+ (NSArray *)activeConnections
{
	return [[PGActiveConnections copy] autorelease];
}
+ (NSArray *)pendingConnections
{
	return [[PGPendingConnections copy] autorelease];
}

#pragma mark Private Protocol

+ (void)_startConnection
{
	if([PGActiveConnections count] < PGMaxSimultaneousConnections && [PGPendingConnections count]) {
		if(!PGConnections) PGConnections = [[NSMutableArray alloc] init];
		if(!PGActiveConnections) PGActiveConnections = [[NSMutableArray alloc] init];
		PGURLConnection *const connection = [PGPendingConnections objectAtIndex:0];
		NSMutableURLRequest *const request = [[[connection request] mutableCopy] autorelease];
		if([self userAgent]) [request setValue:[self userAgent] forHTTPHeaderField:@"User-Agent"];
		NSURLConnection *underlyingConnection = nil;
		if(PGIsLeopardOrLater()) { // Ensure the connections keep loading in the various run loop modes on Leopard.
			underlyingConnection = [[NSURLConnection alloc] initWithRequest:request delegate:[connection PG_nonretainedObjectValue] startImmediately:NO];
			[underlyingConnection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:PGCommonRunLoopsMode];
			[underlyingConnection start];
		} else underlyingConnection = [[NSURLConnection alloc] initWithRequest:request delegate:[connection PG_nonretainedObjectValue]];
		[PGConnections addObject:[underlyingConnection autorelease]];
		[PGActiveConnections addObject:connection];
		[PGPendingConnections removeObjectAtIndex:0];
	}
	[PGURLConnection AE_postNotificationName:PGURLConnectionConnectionsDidChangeNotification];
}

#pragma mark Instance Methods

- (id)initWithRequest:(NSURLRequest *)aRequest
      delegate:(id)anObject
{
	if((self = [super init])) {
		_delegate = anObject;
		_loaded = NO;
		_request = [aRequest copy];
		_data = [[NSMutableData alloc] init];
		if(!PGPendingConnections) PGPendingConnections = [[NSMutableArray alloc] init];
		[PGPendingConnections addObject:[self PG_nonretainedObjectProxy]];
		[[self class] _startConnection];
	}
	return self;
}

#pragma mark -

- (id)delegate
{
	return _delegate;
}
- (BOOL)loaded
{
	return _loaded;
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

- (float)progress
{
	if([self loaded]) return 1;
	if(!_response) return 0;
	long long const expectedLength = [_response expectedContentLength];
	if(-1 == expectedLength) return 0;
	return (float)[_data length] / expectedLength;
}
- (void)prioritize
{
	if([self loaded]) return;
	if(![PGPendingConnections containsObject:self]) return;
	[PGPendingConnections removeObject:self];
	[PGPendingConnections insertObject:[self PG_nonretainedObjectProxy] atIndex:0];
	[PGURLConnection AE_postNotificationName:PGURLConnectionConnectionsDidChangeNotification];
}
- (void)cancelAndNotify:(BOOL)notify
{
	if([self loaded]) return;
	[self _stop];
	[_data release];
	_data = nil;
	if(notify) [[self delegate] connectionDidCancel:self];
}
- (void)cancel
{
	[self cancelAndNotify:YES];
}

#pragma mark Private Protocol

- (void)_stop
{
	[PGPendingConnections removeObject:self];
	unsigned i = [PGActiveConnections indexOfObject:self];
	if(NSNotFound == i) return;
	[PGActiveConnections removeObjectAtIndex:i];
	[[PGConnections objectAtIndex:i] cancel];
	[PGConnections removeObjectAtIndex:i];
	[[self class] _startConnection];
}

#pragma mark NSURLConnectionDelegate Protocol

- (void)connection:(NSURLConnection *)connection
        didReceiveResponse:(NSURLResponse *)response
{
	[_response autorelease];
	_response = [response copy];
	[[self delegate] connectionDidReceiveResponse:self];
}
- (void)connection:(NSURLConnection *)connection
	didReceiveData:(NSData *)data
{
	[_data appendData:data];
	[[self delegate] connectionLoadingDidProgress:self];
	[PGURLConnection AE_postNotificationName:PGURLConnectionConnectionsDidChangeNotification];
}
- (void)connection:(NSURLConnection *)connection
	didFailWithError:(NSError *)error
{
	[self _stop];
	[_data release];
	_data = nil;
	[[self delegate] connectionDidFail:self];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	[self _stop];
	_loaded = YES;
	[[self delegate] connectionDidSucceed:self];
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

@implementation NSObject (PGURLConnectionDelegate)

- (void)connectionLoadingDidProgress:(PGURLConnection *)sender {}
- (void)connectionDidReceiveResponse:(PGURLConnection *)sender {}
- (void)connectionDidSucceed:(PGURLConnection *)sender {}
- (void)connectionDidFail:(PGURLConnection *)sender {}
- (void)connectionDidCancel:(PGURLConnection *)sender {}

@end
