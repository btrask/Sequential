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
#import <Cocoa/Cocoa.h>

extern NSString *const PGURLConnectionConnectionsDidChangeNotification;

@interface PGURLConnection : NSObject // Wraps NSURLConnection so only a few connections are active at a time.
{
	@private
	id              _delegate;
	BOOL            _loaded;
	NSURLRequest   *_request;
	NSURLResponse  *_response;
	NSMutableData  *_data;
}

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)aString;

+ (NSArray *)connections;
+ (NSArray *)activeConnections;
+ (NSArray *)pendingConnections;

- (id)initWithRequest:(NSURLRequest *)aRequest delegate:(id)anObject;

- (id)delegate;
- (BOOL)loaded;
- (NSURLRequest *)request;
- (NSURLResponse *)response;
- (NSMutableData *)data;

- (float)progress;
- (void)prioritize;
- (void)cancelAndNotify:(BOOL)notify;

@end

@interface NSObject (PGURLConnectionDelegate)

- (void)connectionLoadingDidProgress:(PGURLConnection *)sender;
- (void)connectionDidReceiveResponse:(PGURLConnection *)sender;
- (void)connectionDidSucceed:(PGURLConnection *)sender;
- (void)connectionDidFail:(PGURLConnection *)sender;
- (void)connectionDidCancel:(PGURLConnection *)sender;

@end
