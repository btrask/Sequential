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
#import "PGWebAdapter.h"

// Models
#import "PGNode.h"
#import "PGURLLoad.h"
#import "PGResourceIdentifier.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSObjectAdditions.h"

@implementation PGWebAdapter

#pragma mark PGResourceAdapter

+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	NSURL *const URL = [info objectForKey:PGURLKey];
	return !URL || [info objectForKey:PGHasDataKey] || [info objectForKey:PGURLResponseKey] || [URL isFileURL] ? PGNotAMatch : PGMatchByIntrinsicAttribute;
}

#pragma mark PGURLLoadDelegate Protocol

- (void)loadLoadingDidProgress:(PGURLLoad *)sender
{
	if(sender == _mainLoad) [[self node] AE_postNotificationName:PGNodeLoadingDidProgressNotification];
}
- (void)loadDidReceiveResponse:(PGURLLoad *)sender
{
	if(sender != _mainLoad) return;
	id const resp = [sender response];
	if([resp respondsToSelector:@selector(statusCode)] && ([resp statusCode] < 200 || [resp statusCode] >= 300)) {
		[_mainLoad cancelAndNotify:NO];
		[_faviconLoad cancelAndNotify:NO];
		[[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"The error %u %@ was generated while loading the URL %@.", @"The URL returned a error status code. %u is replaced by the status code, the first %@ is replaced by the human-readable error (automatically localized), the second %@ is replaced by the full URL."), [resp statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[resp statusCode]], [resp URL]] forKey:NSLocalizedDescriptionKey]]];
	} else if(![[PGResourceAdapter adapterClassesInstantiated:NO forNode:[self node] withInfo:[NSDictionary dictionaryWithObjectsAndKeys:[resp MIMEType], PGMIMETypeKey, [NSNumber numberWithBool:YES], PGMayHaveDataKey, nil]] count]) {
		[_mainLoad cancelAndNotify:YES];
		[_faviconLoad cancelAndNotify:YES];
	}
}
- (void)loadDidSucceed:(PGURLLoad *)sender
{
	if(sender == _mainLoad) {
		[_faviconLoad cancelAndNotify:NO];
		NSURLResponse *const resp = [_mainLoad response];
		[[self node] continueLoadWithInfo:[NSDictionary dictionaryWithObjectsAndKeys:resp, PGURLResponseKey, [resp MIMEType], PGMIMETypeKey, [_mainLoad data], PGDataKey, nil]];
	} else if(sender == _faviconLoad) {
		NSImage *const favicon = [[[NSImage alloc] initWithData:[_faviconLoad data]] autorelease];
		if(favicon) [[self identifier] setIcon:favicon notify:YES]; // Don't clear the favicon we already have if we can't load a new one.
	}
}
- (void)loadDidFail:(PGURLLoad *)sender
{
	if(sender != _mainLoad) return;
	[_faviconLoad cancelAndNotify:NO];
	[[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"The URL %@ could not be loaded.", @"The URL could not be loaded for an unknown reason. %@ is replaced by the full URL."), [[_mainLoad request] URL]] forKey:NSLocalizedDescriptionKey]]];
}
- (void)loadDidCancel:(PGURLLoad *)sender
{
	if(sender != _mainLoad) return;
	[_faviconLoad cancelAndNotify:NO];
	[[self node] loadFinished];
}

#pragma mark PGLoading Protocol

- (float)loadProgress
{
	return [_mainLoad loadProgress];
}

#pragma mark PGResourceAdapter

- (void)load
{
	NSParameterAssert(![self canGetData]);
	NSURL *const URL = [[self info] objectForKey:PGURLKey];
	[_faviconLoad cancelAndNotify:NO];
	[_faviconLoad release];
	_faviconLoad = [[PGURLLoad alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"/favicon.ico" relativeToURL:URL] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15.0] parentLoad:self delegate:self];
	[_mainLoad cancelAndNotify:NO];
	[_mainLoad release];
	_mainLoad = [[PGURLLoad alloc] initWithRequest:[NSURLRequest requestWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.0] parentLoad:self delegate:self];
}

#pragma mark NSObject

- (void)dealloc
{
	[_mainLoad cancelAndNotify:NO];
	[_mainLoad release];
	[_faviconLoad cancelAndNotify:NO];
	[_faviconLoad release];
	[super dealloc];
}

@end
