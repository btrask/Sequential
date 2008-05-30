/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGURLConnection.h"

// Categories
#import "NSObjectAdditions.h"

static NSString        *PGUserAgent          = nil;
static PGURLConnection *PGActiveConnection   = nil;
static NSURLConnection *PGConnection         = nil;
static NSMutableArray  *PGPendingConnections = nil;

@interface PGURLConnection (Private)

+ (void)_startConnection;
+ (void)_stopConnection:(PGURLConnection *)aConnection;

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

#pragma mark Private Protocol

+ (void)_startConnection
{
	if(PGActiveConnection) return;
	NSParameterAssert(!PGConnection);
	if(![PGPendingConnections count]) return;
	PGActiveConnection = [[PGPendingConnections objectAtIndex:0] nonretainedObjectValue];
	[PGPendingConnections removeObjectAtIndex:0];
	NSMutableURLRequest *const request = [[[PGActiveConnection request] mutableCopy] autorelease];
	if([self userAgent]) [request setValue:[self userAgent] forHTTPHeaderField:@"User-Agent"];
	PGConnection = [[NSURLConnection alloc] initWithRequest:request delegate:PGActiveConnection];
}
+ (void)_stopConnection:(PGURLConnection *)aConnection
{
	[PGPendingConnections removeObject:[NSValue valueWithNonretainedObject:aConnection]];
	if(aConnection != PGActiveConnection) return;
	PGActiveConnection = nil;
	[PGConnection cancel];
	[PGConnection release]; PGConnection = nil;
	[self AE_performSelector:@selector(_startConnection) withObject:nil afterDelay:0];
}

#pragma mark Instance Methods

- (id)initWithRequest:(NSURLRequest *)aRequest
      delegate:(id)anObject
{
	if((self = [super init])) {
		_request = [aRequest copy];
		_data = [[NSMutableData alloc] init];
		_delegate = anObject;
		if(!PGPendingConnections) PGPendingConnections = [[NSMutableArray alloc] init];
		[PGPendingConnections addObject:[NSValue valueWithNonretainedObject:self]];
		[[self class] _startConnection];
	}
	return self;
}
- (NSURLRequest *)request
{
	return [[_request retain] autorelease];
}
- (id)delegate
{
	return _delegate;
}

- (NSURLResponse *)response
{
	return [[_response retain] autorelease];
}
- (NSMutableData *)data
{
	return [[_data retain] autorelease];
}
- (BOOL)isLoaded
{
	return _isLoaded;
}
- (float)progress
{
	if(_isLoaded) return 1;
	if(!_response) return 0;
	long long const expectedLength = [_response expectedContentLength];
	if(-1 == expectedLength) return 0;
	return (float)[_data length] / expectedLength;
}

- (void)prioritize
{
	NSValue *const value = [NSValue valueWithNonretainedObject:self];
	if(![PGPendingConnections containsObject:value]) return;
	[PGPendingConnections removeObject:value];
	[PGPendingConnections insertObject:value atIndex:0];
}
- (void)cancel
{
	[[self class] _stopConnection:self];
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
}
- (void)connection:(NSURLConnection *)connection
	didFailWithError:(NSError *)error
{
	[_data release];
	_data = nil;
	[self connectionDidFinishLoading:connection];
}
- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
	_isLoaded = YES;
	[[self class] _stopConnection:self];
	[[self delegate] connectionDidClose:self];
}

#pragma mark NSObject

- (void)dealloc
{
	NSParameterAssert(![PGPendingConnections containsObject:[NSValue valueWithNonretainedObject:self]]);
	NSParameterAssert(PGActiveConnection != self);
	[_request release];
	[_response release];
	[_data release];
	[super dealloc];
}

@end

@implementation NSObject (PGURLConnectionDelegate)

- (void)connectionDidReceiveResponse:(PGURLConnection *)sender {}
- (void)connectionLoadingDidProgress:(PGURLConnection *)sender {}
- (void)connectionDidClose:(PGURLConnection *)sender {}

@end
