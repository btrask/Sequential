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
#import "PGWebAdapter.h"

// Models
#import "PGNode.h"
#import "PGURLConnection.h"
#import "PGResourceIdentifier.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSObjectAdditions.h"

@implementation PGWebAdapter

#pragma mark PGURLConnectionDelegate Protocol

- (void)connectionDidReceiveResponse:(PGURLConnection *)sender
{
	if(sender != _mainConnection) return;
	Class pendingClass = [[PGDocumentController sharedDocumentController] resourceAdapterClassWhereAttribute:PGCFBundleTypeMIMETypesKey matches:[[sender response] MIMEType]];
	if(pendingClass && ([pendingClass alwaysReads] || [self shouldRead:NO])) return;
	[_mainConnection cancel];
	[self setIsDeterminingType:NO];
	_encounteredLoadingError = YES;
	if([self shouldReadContents]) [self readContents];
}
- (void)connectionLoadingDidProgress:(PGURLConnection *)sender
{
	[[self node] AE_postNotificationName:PGNodeLoadingDidProgressNotification];
}
- (void)connectionDidClose:(PGURLConnection *)sender
{
	if(sender == _mainConnection) {
		if([_mainConnection status] == PGLoaded) [self loadFromData:[_mainConnection data] URLResponse:[_mainConnection response]];
		[self setIsDeterminingType:NO];
		if([_mainConnection status] == PGLoadFailed) _encounteredLoadingError = YES;
		if([self shouldReadContents]) [self readContents];
	} else if(sender == _faviconConnection) [[self identifier] setIcon:[[[NSImage alloc] initWithData:[_faviconConnection data]] autorelease] notify:YES];
}

#pragma mark PGResourceAdapting

- (BOOL)isViewable
{
	return _encounteredLoadingError || [super isViewable];
}
- (float)loadingProgress
{
	return [_mainConnection progress];
}

#pragma mark PGResourceAdapter

- (void)readWithURLResponse:(NSURLResponse *)response
{
	if(response || [self canGetData]) return;
	[self setIsDeterminingType:YES];
	NSURL *const URL = [[self identifier] URL];
	_mainConnection = [[PGURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:URL cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:15.0] delegate:self];
	_faviconConnection = [[PGURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"/favicon.ico" relativeToURL:URL] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:15.0] delegate:self];
}
- (void)readContents
{
	if([self isDeterminingType]) return;
	[self setHasReadContents];
	if(!_encounteredLoadingError) return;
	NSURLResponse *const resp = [_mainConnection response];
	NSString *message = nil;
	if([resp respondsToSelector:@selector(statusCode)]) {
		int const code = [(NSHTTPURLResponse *)resp statusCode];
		if(code < 200 || code >= 300) message = [NSString stringWithFormat:NSLocalizedString(@"The error %u %@ was generated while loading the URL %@.", nil), code, [NSHTTPURLResponse localizedStringForStatusCode:code], [resp URL]];
	} else message = [NSString stringWithFormat:NSLocalizedString(@"The URL %@ could not be loaded.", nil), [[_mainConnection request] URL]];
	[self returnImageRep:nil error:(message ? [NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey]] : nil)];
}

#pragma mark NSObject

- (void)dealloc
{
	[_mainConnection cancel];
	[_mainConnection release];
	[_faviconConnection cancel];
	[_faviconConnection release];
	[super dealloc];
}

@end
