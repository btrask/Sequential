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
#import "PGFlickrAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"
#import "PGURLConnection.h"
#import "PGXMLParser.h"

// Categories
#import "NSObjectAdditions.h"

static NSString *const PGFlickrAPIKey = @"efba0200d782ae552a34fc78d18c02bc"; // Registered to me for use in Sequential. Do no evil.
static NSString *const PGFlickrImageNameKey = @"PGFlickrImageName";

@interface PGFlickrSizeParser : PGXMLParser
{
	@private
	unsigned  _size;
	NSString *_URL;
	NSString *_error;
}

- (NSURL *)URL;
- (NSString *)error;

@end

@interface PGFlickrInfoParser : PGXMLParser
{
	@private
	NSMutableString *_title;
}

- (NSString *)title;

@end

@implementation PGFlickrAdapter

#pragma mark PGResourceAdapter

+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	NSURL *const URL = [info objectForKey:PGURLKey];
	if(!URL || [URL isFileURL]) return PGNotAMatch;
	if([info objectForKey:PGHasDataKey] || [info objectForKey:PGURLResponseKey]) return PGNotAMatch;
	if(![[URL host] isEqualToString:@"flickr.com"] && ![[URL host] hasSuffix:@"com"]) return PGNotAMatch; // Be careful not to allow domains like thisisnotflickr.com.
	NSArray *const components = [[URL path] pathComponents];
	if([components count] < 4) return PGNotAMatch; // Flickr image paths should be /photos/USER_NAME/IMAGE_NAME.
	if(![@"photos" isEqualToString:[components objectAtIndex:1]]) return PGNotAMatch; // All photos start with /photos.
	if([@"tags" isEqualToString:[components objectAtIndex:2]]) return PGNotAMatch; // Tags are /photos/tags/TAG_NAME.
	if([@"sets" isEqualToString:[components objectAtIndex:3]]) return PGNotAMatch; // Sets are /photos/USER_NAME/sets/SET_NUMBER.
	[info setObject:[components objectAtIndex:3] forKey:PGFlickrImageNameKey];
	return PGMatchByIntrinsicAttribute + 700;
}

#pragma mark PGURLConnectionDelegate Protocol

- (void)connectionLoadingDidProgress:(PGURLConnection *)sender
{
	[[self node] AE_postNotificationName:PGNodeLoadingDidProgressNotification];
}
- (void)connectionDidReceiveResponse:(PGURLConnection *)sender
{
	if(sender != _sizeConnection && sender != _infoConnection) return;
	NSHTTPURLResponse *const resp = (NSHTTPURLResponse *)[sender response];
	if(![@"text/xml" isEqualToString:[resp MIMEType]]) {
		[_sizeConnection cancelAndNotify:NO];
		[_infoConnection cancelAndNotify:NO];
		[[self node] loadFinished];
	} else if([resp respondsToSelector:@selector(statusCode)] && ([resp statusCode] < 200 || [resp statusCode] > 300)) {
		[_sizeConnection cancelAndNotify:NO];
		[_infoConnection cancelAndNotify:NO];
		[[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"The error %u %@ was generated while loading the URL %@.", @"The URL returned a error status code. %u is replaced by the status code, the first %@ is replaced by the human-readable error (automatically localized), the second %@ is replaced by the full URL."), [resp statusCode], [NSHTTPURLResponse localizedStringForStatusCode:[resp statusCode]], [resp URL]] forKey:NSLocalizedDescriptionKey]]];
	}
}
- (void)connectionDidSucceed:(PGURLConnection *)sender
{
	if(![_sizeConnection loaded] || ![_infoConnection loaded]) return;
	PGFlickrSizeParser *const sizeParser = [PGFlickrSizeParser parserWithData:[_sizeConnection data]];
	NSURL *const URL = [sizeParser URL];
	NSString *const title = [[PGFlickrInfoParser parserWithData:[_infoConnection data]] title];
	PGResourceIdentifier *const ident = [URL AE_resourceIdentifier];
	[ident setCustomDisplayName:title notify:NO];
	PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:ident] autorelease];
	[node startLoadWithInfo:nil];
	if(node) [self setUnsortedChildren:[NSArray arrayWithObject:node] presortedOrder:PGUnsorted];
	else if([sizeParser error]) return [[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:[sizeParser error] forKey:NSLocalizedDescriptionKey]]];
	[[self node] loadFinished];
}
- (void)connectionDidFail:(PGURLConnection *)sender
{
	if(sender != _sizeConnection && sender != _infoConnection) return;
	[_sizeConnection cancelAndNotify:NO];
	[_infoConnection cancelAndNotify:NO];
	[[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGGenericError userInfo:[NSDictionary dictionaryWithObject:[NSString stringWithFormat:NSLocalizedString(@"The URL %@ could not be loaded.", @"The URL could not be loaded for an unknown reason. %@ is replaced by the full URL."), [[sender request] URL]] forKey:NSLocalizedDescriptionKey]]];
}
- (void)connectionDidCancel:(PGURLConnection *)sender
{
	if(sender == _sizeConnection || sender == _infoConnection) {
		[_sizeConnection cancelAndNotify:NO];
		[_infoConnection cancelAndNotify:NO];
		[[self node] loadFinished];
	}
}

#pragma mark PGResourceAdapting Protocol

- (float)loadingProgress
{
	return ([_sizeConnection progress] + [_infoConnection progress]) / 2.0;
}

#pragma mark PGResourceAdapter

- (void)load
{
	NSString *const name = [[self info] objectForKey:PGFlickrImageNameKey];
	if(!name) return [[self node] loadFinished];
	[_sizeConnection cancelAndNotify:NO];
	[_sizeConnection release];
	_sizeConnection = [[PGURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.flickr.com/services/rest/?method=flickr.photos.getSizes&photo_id=%@&format=rest&api_key=%@", name, PGFlickrAPIKey]]] delegate:self];
	[_infoConnection cancelAndNotify:NO];
	[_infoConnection release];
	_infoConnection = [[PGURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.flickr.com/services/rest/?method=flickr.photos.getInfo&photo_id=%@&format=rest&api_key=%@", name, PGFlickrAPIKey]]] delegate:self];
}

#pragma mark NSObject

- (void)dealloc
{
	[_sizeConnection cancelAndNotify:NO];
	[_sizeConnection release];
	[_infoConnection cancelAndNotify:NO];
	[_infoConnection release];
	[super dealloc];
}

@end

@implementation PGFlickrSizeParser

#pragma mark Instance Methods

- (NSURL *)URL
{
	return _URL ? [NSURL URLWithString:_URL] : nil;
}
- (NSString *)error
{
	return [[_error retain] autorelease];
}

#pragma mark NSXMLParserDelegateEventAdditions Protocol

- (void)beganTagPath:(NSString *)p attributes:(NSDictionary *)attrs
{
	if([@"/rsp/sizes/size" isEqualToString:p]) {
		NSString *const label = [attrs objectForKey:@"label"];
		static NSArray *sizes = nil;
		if(!sizes) sizes = [[NSArray alloc] initWithObjects:@"square", @"thumbnail", @"small", @"medium", @"large", @"original", nil];
		unsigned const size = label ? [sizes indexOfObject:[label lowercaseString]] + 1 : NSNotFound;
		if(NSNotFound != size && size > _size) {
			_size = size;
			[_URL release];
			_URL = [[attrs objectForKey:@"source"] copy];
		}
	} else if([@"/rsp/err" isEqualToString:p]) {
		[_error release];
		_error = [[attrs objectForKey:@"msg"] copy];
	}
}

#pragma mark NSObject

- (void)dealloc
{
	[_URL release];
	[_error release];
	[super dealloc];
}

@end

@implementation PGFlickrInfoParser

#pragma mark Instance Methods

- (NSString *)title
{
	return [[_title retain] autorelease];
}

#pragma mark PGXMLParser

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
	[super dealloc];
}

@end
