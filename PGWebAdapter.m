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

#pragma mark +PGResourceAdapter

+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	PGResourceIdentifier *const ident = [info objectForKey:PGIdentifierKey];
	return !ident || [[info objectForKey:PGDataExistenceKey] intValue] != PGDoesNotExist || [info objectForKey:PGURLResponseKey] || [ident isFileIdentifier] ? PGNotAMatch : PGMatchByIntrinsicAttribute;
}

#pragma mark -PGResourceAdapter

- (void)load
{
	NSParameterAssert(![self canGetData]);
	_triedLoad = YES;
	NSURL *const URL = [[[self info] objectForKey:PGIdentifierKey] URL];
	[_faviconLoad cancelAndNotify:NO];
	[_faviconLoad release];
	_faviconLoad = [[PGURLLoad alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"/favicon.ico" relativeToURL:URL] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15.0] parentLoad:self delegate:self];
	[_mainLoad cancelAndNotify:NO];
	[_mainLoad release];
	_mainLoad = [[PGURLLoad alloc] initWithRequest:[NSURLRequest requestWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.0] parentLoad:self delegate:self];
}
- (void)fallbackLoad
{
	if(_triedLoad) [[self node] setError:nil];
	else [self load];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_mainLoad cancelAndNotify:NO];
	[_mainLoad release];
	[_faviconLoad cancelAndNotify:NO];
	[_faviconLoad release];
	[super dealloc];
}

#pragma mark -NSObject(PGURLLoadDelegate)

- (void)loadLoadingDidProgress:(PGURLLoad *)sender
{
	if(sender == _mainLoad) [[self node] AE_postNotificationName:PGNodeLoadingDidProgressNotification];
}
- (void)loadDidReceiveResponse:(PGURLLoad *)sender
{
	if(sender != _mainLoad) return;
	id const resp = [sender response];
	[[self info] setObject:[resp MIMEType] forKey:PGMIMETypeKey];
	if([resp respondsToSelector:@selector(statusCode)] && ([resp statusCode] < 200 || [resp statusCode] >= 300)) {
		[_mainLoad cancelAndNotify:NO];
		[_faviconLoad cancelAndNotify:NO];
		[[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"The error %u %@ was generated while loading the URL %@.", @"The URL returned a error status code. %u is replaced by the status code, the first %@ is replaced by the human-readable error (automatically localized), the second %@ is replaced by the full URL."), [resp statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[resp statusCode]], [resp URL]] forKey:NSLocalizedDescriptionKey]]];
	} else if(![[PGResourceAdapter adapterClassesInstantiated:NO forNode:[self node] withInfoDicts:[NSArray arrayWithObject:[NSDictionary dictionaryWithObjectsAndKeys:[resp MIMEType], PGMIMETypeKey, [NSNumber numberWithInt:PGWillSoonExist], PGDataExistenceKey, nil]]] count]) {
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
		if(favicon) [[self identifier]	setIcon:favicon]; // Don't clear the favicon we already have if we can't load a new one.
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

#pragma mark -<PGLoading>

- (float)loadProgress
{
	return [_mainLoad loadProgress];
}

@end
