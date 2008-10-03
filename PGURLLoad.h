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

// Models
#import "PGLoading.h"

@interface PGURLLoad : NSObject <PGLoading>
{
	@private
	id<PGLoading>    _parentLoad;
	id               _delegate;
	BOOL             _loaded;
	NSURLConnection *_connection;
	NSURLRequest    *_request;
	NSURLResponse   *_response;
	NSMutableData   *_data;
}

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)aString;

- (id)initWithRequest:(NSURLRequest *)aRequest parentLoad:(id<PGLoading>)parent delegate:(id)anObject;

- (id)delegate;
- (NSURLRequest *)request;
- (NSURLResponse *)response;
- (NSMutableData *)data;

- (void)cancelAndNotify:(BOOL)notify;
- (BOOL)loaded;

@end

@interface NSObject (PGURLLoadDelegate)

- (void)loadLoadingDidProgress:(PGURLLoad *)sender;
- (void)loadDidReceiveResponse:(PGURLLoad *)sender;
- (void)loadDidSucceed:(PGURLLoad *)sender;
- (void)loadDidFail:(PGURLLoad *)sender;
- (void)loadDidCancel:(PGURLLoad *)sender;

@end
