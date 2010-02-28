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
#import "PGHTMLAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Controllers
#import "PGDocumentController.h"

// Other Sources
#import "PGWebKitAdditions.h"

NSString *const PGDOMDocumentKey = @"PGDOMDocument";

@interface PGHTMLAdapter(Private)

- (void)_clearWebView;

@end

@implementation PGHTMLAdapter

#pragma mark -PGHTMLAdapter(Private)

- (void)_clearWebView
{
	[_webView stopLoading:self];
	[_webView setFrameLoadDelegate:nil];
	[_webView autorelease];
	_webView = nil;
}

#pragma mark -PGResourceAdapter

- (PGLoadPolicy)descendentLoadPolicy
{
	return PGLoadNone;
}
- (void)load
{
	// TODO: Rewrite PGHTMLAdapter so that it does its own loading. That means that we will be able to report a more accurate status, as well as work with local files.
//	NSParameterAssert(!_webView);
//	NSURLResponse *const response = [[self info] objectForKey:PGURLResponseKey];
//	NSData *const data = [self data];
//	if(!data) return [[self node] loadFinished];
//	_webView = [[WebView alloc] initWithFrame:NSZeroRect];
//	[_webView setFrameLoadDelegate:self];
//	WebPreferences *const prefs = [WebPreferences standardPreferences];
//	[prefs setJavaEnabled:NO];
//	[prefs setPlugInsEnabled:NO];
//	[prefs setJavaScriptEnabled:NO];
//	[prefs setJavaScriptCanOpenWindowsAutomatically:NO];
//	[prefs setLoadsImagesAutomatically:NO];
//	[_webView setPreferences:prefs];
//	[[_webView mainFrame] loadData:data MIMEType:[response MIMEType] textEncodingName:[response textEncodingName] baseURL:[response URL]];
}
- (void)read {}

#pragma mark -NSObject

- (void)dealloc
{
	[self _clearWebView];
	[super dealloc];
}

#pragma mark -NSObject(WebFrameLoadDelegate)

- (void)webView:(WebView *)sender didFailProvisionalLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	[self webView:sender didFailLoadWithError:error forFrame:frame];
}
- (void)webView:(WebView *)sender didFailLoadWithError:(NSError *)error forFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[self _clearWebView];
	[[self node] loadFailedWithError:error forAdapter:self];
}

- (void)webView:(WebView *)sender didReceiveTitle:(NSString *)title forFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[[[self node] identifier] setCustomDisplayName:title];
}
- (void)webView:(WebView *)sender didReceiveIcon:(NSImage *)image forFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[[[self node] identifier] setIcon:image];
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;

	DOMHTMLDocument *const doc = (DOMHTMLDocument *)[frame DOMDocument];
	if(!doc) return [self load];
	NSArray *providers = [doc PG_providersForLinkHrefsWithSchemes:nil];
	if(![providers count]) providers = [doc PG_providersForImageSrcs];
	NSMutableArray *const pages = [NSMutableArray array];
	for(PGDataProvider *const provider in providers) {
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:[[provider identifier] displayableIdentifier]] autorelease];
		if(!node) continue;
		[node loadWithDataProvider:provider];
		[pages addObject:node];
	}
	[self setUnsortedChildren:pages presortedOrder:PGSortInnateOrder];
	[[self node] loadSucceededForAdapter:self];

	[self _clearWebView];
}

#pragma mark -<PGResourceAdapting>

- (CGFloat)loadProgress
{
	return 1.0f;
}

@end
