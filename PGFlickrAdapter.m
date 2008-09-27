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
#import "PGURLConnection.h"

static NSString *const PGFlickrAPIKey = @"efba0200d782ae552a34fc78d18c02bc"; // Registered to me for use in Sequential. Do no evil.
static NSString *const PGFlickrImageNameKey = @"PGFlickrImageName";

@implementation PGFlickrAdapter

#pragma mark PGResourceAdapter

+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	NSURL *const URL = [info objectForKey:PGURLKey];
	if([URL isFileURL]) return PGNotAMatch;
	if(![[URL host] isEqualToString:@"flickr.com"] && ![[URL host] hasSuffix:@".flickr.com"]) return PGNotAMatch; // Be careful not to allow domains like thisisnotflickr.com.
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
	if(sender == _sizeConnection) {
	
	} else if(sender == _infoConnection) {
	
	}
}
- (void)connectionDidReceiveResponse:(PGURLConnection *)sender
{
	if(sender == _sizeConnection) {
	
	} else if(sender == _infoConnection) {
	
	}
}
- (void)connectionDidSucceed:(PGURLConnection *)sender
{
	if(sender == _sizeConnection) {
	
	} else if(sender == _infoConnection) {
	
	}
}
- (void)connectionDidFail:(PGURLConnection *)sender
{
	if(sender == _sizeConnection) {
	
	} else if(sender == _infoConnection) {
	
	}
}
- (void)connectionDidCancel:(PGURLConnection *)sender
{
	if(sender == _sizeConnection) {
	
	} else if(sender == _infoConnection) {
	
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
	_sizeConnection = [[PGURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.flickr.com/services/rest/?method=flickr.photos.getSizes&photo_id=%@&format=rest&api_key=%", name, PGFlickrAPIKey]]] delegate:self];
	[_infoConnection cancelAndNotify:NO];
	[_infoConnection release];
	_infoConnection = [[PGURLConnection alloc] initWithRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[NSString stringWithFormat:@"http://www.flickr.com/services/rest/?method=flickr.photos.getInfo&photo_id=%@&format=rest&api_key=%", name, PGFlickrAPIKey]]] delegate:self];
	[[self node] loadFinished];
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
