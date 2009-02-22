/* Copyright © 2007-2008, The Sequential Project
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
#import "PGFlickrAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"
#import "PGURLLoad.h"
#import "PGXMLParser.h"

// Categories
#import "NSMutableDictionaryAdditions.h"
#import "NSObjectAdditions.h"
#import "NSScannerAdditions.h"

static NSString *const PGFlickrAPIKey = @"efba0200d782ae552a34fc78d18c02bc"; // Registered to me for use in Sequential. Do no evil.

static NSString *const PGFlickrPhotoNameKey = @"PGFlickrPhotoName";
static NSString *const PGFlickrUserNameKey  = @"PGFlickrUserName";
static NSString *const PGFlickrGroupNameKey = @"PGFlickrGroupName";
static NSString *const PGFlickrTagNameKey   = @"PGFlickrTagName";
static NSString *const PGFlickrSetNameKey   = @"PGFlickrSetName";

enum {
	PGFlickrUserNotFoundErr = 2
};

@interface PGFlickrPhotoListParser : PGXMLParser
{
	@private
	NSString *_title;
}
@end

@interface PGFlickrPhotoParser : PGXMLParser
{
	@private
	NSMutableString *_title;
	NSString *_farm;
	NSString *_server;
	NSString *_id;
	NSString *_secret;
	NSString *_originalFormat;
	NSString *_errorString;
	int       _errorCode;
}

- (int)errorCode;

@end

@implementation PGFlickrAdapter

#pragma mark PGResourceAdapter

+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	PGResourceIdentifier *const ident = [info objectForKey:PGIdentifierKey];
	if(!ident || [ident isFileIdentifier]) return PGNotAMatch;
	NSURL *const URL = [ident URL];
	if([[info objectForKey:PGDataExistenceKey] intValue] != PGDoesNotExist || [info objectForKey:PGURLResponseKey]) return PGNotAMatch;
	if(![[URL host] isEqualToString:@"flickr.com"] && ![[URL host] hasSuffix:@".flickr.com"]) return PGNotAMatch; // Be careful not to allow domains like thisisnotflickr.com.

	NSString *photo = nil;
	NSString *user = nil;
	NSString *group = nil;
	NSString *tag = nil;
	NSString *set = nil;
	NSScanner *const scanner = [NSScanner scannerWithString:[URL path]];
	if([scanner AE_scanFromString:@"/photos/" toString:@"/" intoString:&user]) {
		if([[NSArray arrayWithObjects:@"tags", @"sets", nil] containsObject:user]) user = nil;
		else {
			[scanner scanString:@"/" intoString:NULL];
			[scanner scanUpToString:@"/" intoString:&photo];
			if([[NSArray arrayWithObjects:@"tags", @"sets", @"groups", @"archives", @"favorites", nil] containsObject:photo]) photo = nil;
		}
	}
	[scanner AE_scanFromString:@"/groups/" toString:@"/" intoString:&group];
	[scanner AE_scanFromString:@"/tags/" toString:@"/" intoString:&tag];
	[scanner AE_scanFromString:@"/sets/" toString:@"/" intoString:&set];
	if(!photo && !user && !group && !tag && !set) return PGNotAMatch;

	[info AE_setObject:photo forKey:PGFlickrPhotoNameKey];
	[info AE_setObject:user forKey:PGFlickrUserNameKey];
	[info AE_setObject:group forKey:PGFlickrGroupNameKey];
	[info AE_setObject:tag forKey:PGFlickrTagNameKey];
	[info AE_setObject:set forKey:PGFlickrSetNameKey];
	return PGMatchByIntrinsicAttribute + 700;
}

#pragma mark PGURLLoadDelegate Protocol

- (void)loadLoadingDidProgress:(PGURLLoad *)sender
{
	[[self node] AE_postNotificationName:PGNodeLoadingDidProgressNotification];
}
- (void)loadDidReceiveResponse:(PGURLLoad *)sender
{
	if(sender != _load) return;
	NSHTTPURLResponse *const resp = (NSHTTPURLResponse *)[sender response];
	if(![@"text/xml" isEqualToString:[resp MIMEType]]) {
		[_load cancelAndNotify:NO];
		[[self node] loadFinished];
	} else if([resp respondsToSelector:@selector(statusCode)] && ([resp statusCode] < 200 || [resp statusCode] > 300)) {
		[_load cancelAndNotify:NO];
		[[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"The error %u %@ was generated while loading the URL %@.", @"The URL returned a error status code. %u is replaced by the status code, the first %@ is replaced by the human-readable error (automatically localized), the second %@ is replaced by the full URL."), [resp statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[resp statusCode]], [resp URL]] forKey:NSLocalizedDescriptionKey]]];
	}
}
- (void)loadDidSucceed:(PGURLLoad *)sender
{
	if(sender != _load) return;
	PGXMLParser *const parser = [PGXMLParser parserWithData:[_load data] baseURL:[[[self info] objectForKey:PGIdentifierKey] URL] classes:[NSArray arrayWithObjects:[PGFlickrPhotoListParser class], [PGFlickrPhotoParser class], nil]];
	[[self identifier] setCustomDisplayName:[parser title] notify:YES];
	NSError *const error = [parser error];
	if(error) [[self node] setError:([parser respondsToSelector:@selector(errorCode)] && [(PGFlickrPhotoParser *)parser errorCode] == PGFlickrUserNotFoundErr ? [NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:NSLocalizedString(@"Flickr could not find the user %@. This user may not exist or may have disabled searches in the Flickr privacy settings.", @"Flickr user not found error message. %@ is replaced with the user name/NSID."), [[self info] objectForKey:PGFlickrUserNameKey]], NSLocalizedDescriptionKey, nil]] : error)];
	else if([parser createsMultipleNodes]) {
		[self setUnsortedChildren:[parser nodesWithParentAdapter:self] presortedOrder:PGSortInnateOrder];
		[[self node] loadFinished];
	} else {
		id const info = [parser info];
		if(info && [info count]) [[self node] continueLoadWithInfo:info];
		else [[self node] setError:nil];
	}
}
- (void)loadDidFail:(PGURLLoad *)sender
{
	if(sender != _load) return;
	[_load cancelAndNotify:NO];
	[[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"The URL %@ could not be loaded.", @"The URL could not be loaded for an unknown reason. %@ is replaced by the full URL."), [[sender request] URL]] forKey:NSLocalizedDescriptionKey]]];
}
- (void)loadDidCancel:(PGURLLoad *)sender
{
	if(sender != _load) return;
	[[self node] loadFinished];
}

#pragma mark PGLoading Protocol

- (float)loadProgress
{
	return [_load loadProgress];
}

#pragma mark PGResourceAdapter

- (void)load
{
	[_load cancelAndNotify:NO];
	[_load release];
	NSDictionary *const info = [self info];
	NSMutableString *const URLString = [NSMutableString stringWithFormat:@"http://www.flickr.com/services/rest/?format=rest&api_key=%@", PGFlickrAPIKey];
	NSString *const photoName = [info objectForKey:PGFlickrPhotoNameKey];
	if(photoName) [URLString appendFormat:@"&method=flickr.photos.getInfo&photo_id=%@", photoName];
	else {
		[URLString appendString:@"&per_page=30&extras=original_format,original_secret&media=photos"];
		NSString *const setName = [info objectForKey:PGFlickrSetNameKey];
		if(setName) [URLString appendFormat:@"&method=flickr.photosets.getPhotos&photoset_id=%@", setName];
		else {
			NSString *const user = [info objectForKey:PGFlickrUserNameKey];
			NSString *const group = [info objectForKey:PGFlickrGroupNameKey];
			NSString *const tag = [info objectForKey:PGFlickrTagNameKey];
			if(!user && !group && !tag) return [[self node] loadFinished];
			[URLString appendString:@"&method=flickr.photos.search"];
			if(user) [URLString appendFormat:@"&user_id=%@", user];
			if(group) [URLString appendFormat:@"&group_id=%@", group];
			if(tag) [URLString appendFormat:@"&tags=%@", tag];
		}
	}
	_load = [[PGURLLoad alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:URLString]] parentLoad:self delegate:self];
}
- (BOOL)shouldFallbackOnError
{
	return NO;
}

#pragma mark NSObject

- (void)dealloc
{
	[_load cancelAndNotify:NO];
	[_load release];
	[super dealloc];
}

@end

@implementation PGFlickrPhotoListParser

#pragma mark PGXMLParser

+ (BOOL)canParseTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	return [@"/rsp/photos" isEqualToString:p] || [@"/rsp/photoset" isEqualToString:p];
}

#pragma mark PGXMLParserNodeCreation Protocol

- (BOOL)createsMultipleNodes
{
	return YES;
}
- (NSString *)title
{
	return [[_title retain] autorelease];
}

#pragma mark PGXMLParser

- (void)beganTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	if([@"/rsp/photoset" isEqualToString:p]) {
		[_title release];
		_title = [[attrs objectForKey:@"id"] copy];
	} else if([@"/rsp/photos/photo" isEqualToString:p] || [@"/rsp/photoset/photo" isEqualToString:p]) [self useSubparser:[[[PGFlickrPhotoParser alloc] init] autorelease]];
}

#pragma mark NSObject

- (void)dealloc
{
	[_title release];
	[super dealloc];
}

@end

@implementation PGFlickrPhotoParser

#pragma mark Instance Methods

- (int)errorCode
{
	return _errorCode;
}

#pragma mark PGXMLParser

+ (BOOL)canParseTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	return [@"/rsp/photo" isEqualToString:p] || [@"/rsp/photos/photo" isEqualToString:p] || [@"/rsp/photoset/photo" isEqualToString:p] || [@"/rsp/err" isEqualToString:p];
}

#pragma mark PGXMLParserNodeCreation Protocol

- (BOOL)createsMultipleNodes
{
	return NO;
}
- (NSString *)title
{
	return [[_title retain] autorelease];
}
- (NSString *)URLString
{
	if(!_farm || !_server || !_id || !_secret) return nil;
	if(_originalFormat) return [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@_o.%@", _farm, _server, _id, _secret, _originalFormat];
	return [NSString stringWithFormat:@"http://farm%@.static.flickr.com/%@/%@_%@.jpg", _farm, _server, _id, _secret];
}
- (NSString *)errorString
{
	return _errorString ? [NSString stringWithFormat:NSLocalizedString(@"Flickr returned the error %@.", @"Flickr generic error message. %@ is replaced with the message as returned by Flickr."), ([_errorString hasSuffix:@"."] ? [_errorString substringToIndex:[_errorString length] - 1] : _errorString)] : nil;
}

#pragma mark PGXMLParser

- (void)beganTagPath:(NSString *)p
        attributes:(NSDictionary *)attrs
{
	if([@"/rsp/photo" isEqualToString:p] || [@"/rsp/photos/photo" isEqualToString:p] || [@"/rsp/photoset/photo" isEqualToString:p]) {
		[_farm release];
		_farm = [@"1" copy]; // The docs don't mention this getting sent.
		[_server release];
		_server = [[attrs objectForKey:@"server"] copy];
		[_id release];
		_id = [[attrs objectForKey:@"id"] copy];
		NSString *const originalSecret = [attrs objectForKey:@"originalsecret"];
		if(originalSecret) {
			[_secret release];
			_secret = [originalSecret copy];
		} else if(!_secret) _secret = [[attrs objectForKey:@"secret"] copy];
		NSString *const originalFormat = [attrs objectForKey:@"originalformat"];
		if(originalFormat) {
			[_originalFormat release];
			_originalFormat = [originalFormat copy];
		}
		NSString *const title = [attrs objectForKey:@"title"];
		if(title) [_title setString:title];
	} else if([@"/rsp/err" isEqualToString:p]) {
		[_errorString release];
		_errorString = [[attrs objectForKey:@"msg"] copy];
		_errorCode = [[attrs objectForKey:@"code"] intValue];
	}
}
- (NSMutableString *)contentStringForTagPath:(NSString *)p
{
	return [@"/rsp/photo/title" isEqualToString:p] ? _title : [super contentStringForTagPath:p];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_title = [[NSMutableString alloc] init];
	}
	return self;
}
- (void)dealloc
{
	[_title release];
	[_farm release];
	[_server release];
	[_id release];
	[_secret release];
	[_originalFormat release];
	[_errorString release];
	[super dealloc];
}

@end
