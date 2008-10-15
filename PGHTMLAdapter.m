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
#import "PGHTMLAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "DOMNodeAdditions.h"

NSString *const PGDOMDocumentKey = @"PGDOMDocument";

@interface PGHTMLAdapter (Private)

- (void)_clearWebView;

@end

@implementation PGHTMLAdapter

#pragma mark Private Protocol

- (void)_clearWebView
{
	[_webView stopLoading:self];
	[_webView setFrameLoadDelegate:nil];
	[_webView setPolicyDelegate:nil];
	[_webView autorelease];
	_webView = nil;
}

#pragma mark WebFrameLoadDelegate Protocol

- (void)webView:(WebView *)sender
        didFailProvisionalLoadWithError:(NSError *)error
        forFrame:(WebFrame *)frame
{
	[self webView:sender didFailLoadWithError:error forFrame:frame];
}
- (void)webView:(WebView *)sender
        didFailLoadWithError:(NSError *)error
        forFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[self _clearWebView];
	[[self node] loadFinished];
}

- (void)webView:(WebView *)sender
        didReceiveTitle:(NSString *)title
        forFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[[self identifier] setCustomDisplayName:title notify:YES];
}
- (void)webView:(WebView *)sender
        didReceiveIcon:(NSImage *)image
        forFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[[self identifier] setIcon:image notify:YES];
}

- (void)webView:(WebView *)sender
        didFinishLoadForFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[[self info] setObject:[frame DOMDocument] forKey:PGDOMDocumentKey];
	[[self node] continueLoadWithInfo:[NSDictionary dictionaryWithObjectsAndKeys:[frame DOMDocument], PGDOMDocumentKey, [[frame dataSource] response], PGURLResponseKey, [NSNumber numberWithInt:PGExists], PGDataExistenceKey, nil]];
	[self _clearWebView];
}

#pragma mark WebPolicyDelegate Protocol

- (void)webView:(WebView *)sender
        decidePolicyForNavigationAction:(NSDictionary *)actionInformation
        request:(NSURLRequest *)request
        frame:(WebFrame *)frame
        decisionListener:(id<WebPolicyDecisionListener>)listener
{
	if(frame == [_webView mainFrame]) [listener use];
	else [listener ignore];
}

#pragma mark PGResourceAdapting Protocol

- (float)loadProgress
{
	return 1.0;
}

#pragma mark PGResourceAdapter

- (PGLoadPolicy)descendentLoadPolicy
{
	return PGLoadNone;
}
- (void)load
{
	NSParameterAssert(!_webView);
	NSURLResponse *const response = [[self info] objectForKey:PGURLResponseKey];
	NSData *const data = [self data];
	if(!data) return [[self node] loadFinished];
	_webView = [[WebView alloc] initWithFrame:NSZeroRect];
	[_webView setFrameLoadDelegate:self];
	[_webView setPolicyDelegate:self];
	WebPreferences *const prefs = [WebPreferences standardPreferences];
	[prefs setJavaEnabled:NO];
	[prefs setPlugInsEnabled:NO];
	[prefs setJavaScriptCanOpenWindowsAutomatically:NO];
	[prefs setLoadsImagesAutomatically:NO];
	[_webView setPreferences:prefs];
	[[_webView mainFrame] loadData:data MIMEType:[response MIMEType] textEncodingName:[response textEncodingName] baseURL:[response URL]];
}
- (void)fallbackLoad
{
	DOMHTMLDocument *const doc = [[self info] objectForKey:PGDOMDocumentKey];
	if(!doc) return [self load];
	NSArray *identifiers = [doc AE_linkHrefIdentifiersWithSchemes:nil extensions:[PGResourceAdapter supportedExtensionsWhichMustAlwaysLoad:YES]];
	if(![identifiers count]) identifiers = [doc AE_imageSrcIdentifiers];
	NSMutableArray *const pages = [NSMutableArray array];
	PGResourceIdentifier *ident;
	NSEnumerator *const identEnum = [identifiers objectEnumerator];
	while((ident = [identEnum nextObject])) {
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:ident] autorelease];
		if(!node) continue;
		[node startLoadWithInfo:nil];
		[pages addObject:node];
	}
	[self setUnsortedChildren:pages presortedOrder:PGSortInnateOrder];
	[[self node] loadFinished];
}
- (void)read {}

#pragma mark NSObject

- (void)dealloc
{
	[self _clearWebView];
	[super dealloc];
}

@end
