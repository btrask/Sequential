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
// Models
#import "PGActivity.h"

@protocol PGURLLoadDelegate;

@interface PGURLLoad : NSObject <PGActivityOwner>
{
	@private
	NSObject<PGURLLoadDelegate> * _delegate;
	BOOL _loaded;
	NSURLConnection *_connection;
	NSURLRequest *_request;
	NSURLResponse *_response;
	NSMutableData *_data;
	PGActivity *_activity;
}

+ (NSString *)userAgent;
+ (void)setUserAgent:(NSString *)aString;

- (id)initWithRequest:(NSURLRequest *)aRequest parent:(id<PGActivityOwner>)parent delegate:(NSObject<PGURLLoadDelegate> *)delegate;

@property(readonly) NSObject<PGURLLoadDelegate> *delegate;
@property(readonly) NSURLRequest *request;
@property(readonly) NSURLResponse *response;
@property(readonly) NSMutableData *data;

- (void)cancelAndNotify:(BOOL)notify;
- (BOOL)loaded;

@end

@protocol PGURLLoadDelegate <NSObject>

@optional
- (void)loadLoadingDidProgress:(PGURLLoad *)sender;
- (void)loadDidReceiveResponse:(PGURLLoad *)sender;
- (void)loadDidSucceed:(PGURLLoad *)sender;
- (void)loadDidFail:(PGURLLoad *)sender;
- (void)loadDidCancel:(PGURLLoad *)sender;

@end
