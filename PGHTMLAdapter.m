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
#import "PGHTMLAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "DOMNodeAdditions.h"

@implementation PGHTMLAdapter

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
	[_webView stopLoading:self];
	[_webView setFrameLoadDelegate:nil];
	[_webView autorelease];
	_webView = nil;
	_isRendering = NO;
	[self noteIsViewableDidChange];
}

- (void)webView:(WebView *)sender
        didFinishLoadForFrame:(WebFrame *)frame
{
	if(frame != [_webView mainFrame]) return;
	[[self identifier] setDisplayName:[[frame dataSource] pageTitle] notify:YES];
	DOMDocument *const doc = [frame DOMDocument];
	NSMutableArray *const identifiers = [NSMutableArray array];
	[doc AE_getLinkedResourceIdentifiers:identifiers validSchemes:nil extensions:[[PGDocumentController sharedDocumentController] supportedExtensions]];
	if(![identifiers count]) [doc AE_getEmbeddedImageIdentifiers:identifiers];
	if([identifiers count]) {
		NSMutableArray *const pages = [NSMutableArray array];
		PGResourceIdentifier *ident;
		NSEnumerator *const identEnum = [identifiers objectEnumerator];
		while((ident = [identEnum nextObject])) {
			PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:ident] autorelease];
			if(!node) continue;
			[node loadIfNecessaryWithURLResponse:nil];
			[pages addObject:node];
		}
		[self setUnsortedChildren:pages presortedOrder:PGUnsorted];
	}
	[_webView stopLoading:self];
	[_webView setFrameLoadDelegate:nil];
	[_webView autorelease];
	_webView = nil;
	_isRendering = NO;
	[self noteIsViewableDidChange];
}

#pragma mark PGResourceAdapting Protocol

- (BOOL)adapterIsViewable
{
	return _isRendering || [super adapterIsViewable];
}
- (float)loadingProgress
{
	return 1.0;
}

#pragma mark PGContainerAdapter

- (NSArray *)sortedChildren
{
	return [self unsortedChildren];
}

#pragma mark PGResourceAdapter

- (PGLoadingPolicy)descendentLoadingPolicy
{
	return MAX(PGLoadNone, [[self parentAdapter] descendentLoadingPolicy]);
}
- (void)loadWithURLResponse:(NSURLResponse *)response
{
	NSParameterAssert(!_webView);
	NSData *data;
	if([self getData:&data] != PGDataReturned) return;
	_webView = [[WebView alloc] initWithFrame:NSZeroRect];
	[_webView setFrameLoadDelegate:self];
	WebPreferences *const prefs = [WebPreferences standardPreferences];
	[prefs setJavaEnabled:NO];
	[prefs setPlugInsEnabled:NO];
	[prefs setJavaScriptCanOpenWindowsAutomatically:NO];
	[prefs setLoadsImagesAutomatically:NO];
	[_webView setPreferences:prefs];
	[[_webView mainFrame] loadData:data MIMEType:[response MIMEType] textEncodingName:[response textEncodingName] baseURL:[response URL]];
	_isRendering = YES;
	[self noteIsViewableDidChange];
}

- (void)read {}

#pragma mark NSObject

- (void)dealloc
{
	[_webView stopLoading:self];
	[_webView setFrameLoadDelegate:nil];
	[_webView autorelease];
	[super dealloc];
}

@end
