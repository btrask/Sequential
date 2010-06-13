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
#import "PGGenericImageAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Other Sources
#import "PGAppKitAdditions.h"

static NSBitmapImageRep *PGImageSourceImageRepAtIndex(CGImageSourceRef source, size_t i)
{
	if(!source) return nil;
	CGImageRef const image = CGImageSourceCreateImageAtIndex(source, i, NULL);
	NSBitmapImageRep *const rep = [[[NSBitmapImageRep alloc] initWithCGImage:image] autorelease];
	CGImageRelease(image);
	return rep;
}

@interface PGGenericImageAdapter(Private)

- (void)_threaded_imageRep;
- (NSDictionary *)_imageSourceOptions;
- (void)_setImageProperties:(NSDictionary *)properties;
- (void)_readFinishedWithImageRep:(NSImageRep *)aRep;

@end

@implementation PGGenericImageAdapter

#pragma mark Private Protocol

- (void)_threaded_imageRep
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	NSData *const data = [[self dataProvider] data];
	NSImageRep *rep = nil;
	if(data) {
		CGImageSourceRef const source = CGImageSourceCreateWithData((CFDataRef)data, (CFDictionaryRef)[self _imageSourceOptions]);
		size_t const imageCount = CGImageSourceGetCount(source);
		if(imageCount) {
			[self performSelectorOnMainThread:@selector(_setImageProperties:) withObject:[(NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, 0, NULL) autorelease] waitUntilDone:NO];
			if(imageCount > 1) rep = [NSBitmapImageRep imageRepWithData:data]; // If the image is animated, we can't use the image source.
			else rep = PGImageSourceImageRepAtIndex(source, 0);
		}
		CFRelease(source);
	}
	[self performSelectorOnMainThread:@selector(_readFinishedWithImageRep:) withObject:rep waitUntilDone:NO];
	[pool drain];
}
- (NSDictionary *)_imageSourceOptions
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[[self dataProvider] UTIType], kCGImageSourceTypeIdentifierHint,
		nil];
}
- (void)_setImageProperties:(NSDictionary *)properties
{
	_orientation = PGOrientationWithTIFFOrientation([[properties objectForKey:(NSString *)kCGImagePropertyOrientation] unsignedIntegerValue]);
	[_imageProperties release];
	_imageProperties = [properties copy];
}
- (void)_readFinishedWithImageRep:(NSImageRep *)aRep
{
	_reading = NO;
	_readFailed = !aRep;
	[[self node] noteIsViewableDidChange];
	[_cachedRep release];
	_cachedRep = [aRep retain];
	[[self document] noteNodeDidCache:[self node]];
	[[self node] readFinishedWithImageRep:aRep];
}

#pragma mark PGResourceAdapting Protocol

- (BOOL)canSaveData
{
	return YES;
}

#pragma mark -

- (void)load
{
	[self clearCache];
	_readFailed = NO;
	[[self node] noteIsViewableDidChange];
	[[self node] loadSucceededForAdapter:self];
}

#pragma mark -

- (NSDictionary *)imageProperties
{
	return [[_imageProperties retain] autorelease];
}
- (PGOrientation)orientationWithBase:(BOOL)flag
{
	return PGAddOrientation(_orientation, [super orientationWithBase:flag]);
}
- (void)clearCache
{
	[_imageProperties release];
	_imageProperties = nil;
	[_cachedRep release];
	_cachedRep = nil;
}

#pragma mark PGResourceAdapter

- (BOOL)adapterIsViewable
{
	return !_readFailed;
}
- (void)read
{
	if(_cachedRep) {
		[[self document] noteNodeDidCache:[self node]];
		[[self node] readFinishedWithImageRep:_cachedRep];
		return;
	}
	if(_reading) return;
	_reading = YES;
	_readFailed = NO;
	[NSThread detachNewThreadSelector:@selector(_threaded_imageRep) toTarget:self withObject:nil];
}
- (BOOL)canGenerateRealThumbnail
{
	return YES;
}

#pragma mark -PGResourceAdapter(PGAbstract)

- (NSImageRep *)threaded_thumbnailRepWithSize:(NSSize)size baseOrientation:(PGOrientation)baseOrientation
{
	NSData *const data = [[self dataProvider] data];
	if(!data) return nil;
	CGImageSourceRef const source = CGImageSourceCreateWithData((CFDataRef)data, (CFDictionaryRef)[self _imageSourceOptions]);
	if(!source) return nil;
	size_t const count = CGImageSourceGetCount(source);
	if(!count) {
		CFRelease(source);
		return nil;
	}
	size_t const thumbnailFrameIndex = count / 10;
	NSBitmapImageRep *const rep = PGImageSourceImageRepAtIndex(source, thumbnailFrameIndex);
	NSDictionary *const properties = [(NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, thumbnailFrameIndex, NULL) autorelease];
	CFRelease(source);
	PGOrientation const orientation = PGOrientationWithTIFFOrientation([[properties objectForKey:(NSString *)kCGImagePropertyOrientation] unsignedIntegerValue]);
	return [rep PG_thumbnailWithMaxSize:size orientation:PGAddOrientation(orientation, baseOrientation) opaque:NO];
}

#pragma mark NSObject

- (void)dealloc
{
	[_imageProperties release];
	[_cachedRep release];
	[super dealloc];
}

@end
