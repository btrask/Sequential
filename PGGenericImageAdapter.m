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
#import "PGExifEntry.h"

// Other Sources
#import "PGAppKitAdditions.h"

static BOOL PGImageSourceGetBestImageIndex(CGImageSourceRef source, size_t *outIndex, NSDictionary **outProperties)
{
	if(!source) return NO;
	NSDictionary *const propOptions = [NSDictionary dictionaryWithObjectsAndKeys:
		[NSNumber numberWithBool:NO], kCGImageSourceShouldCache,
		nil];
	size_t const count = CGImageSourceGetCount(source);
	size_t i = 0;
	BOOL found = NO;
	size_t bestIndex = 0;
	NSDictionary *bestProperties = nil;
	NSUInteger bestRes = 0;
	NSUInteger bestDepth = 0;
	for(; i < count; i++) {
		NSDictionary *const properties = [(NSDictionary *)CGImageSourceCopyPropertiesAtIndex(source, i, (CFDictionaryRef)propOptions) autorelease];
		NSUInteger const res = [[properties objectForKey:(NSString *)kCGImagePropertyPixelWidth] unsignedIntegerValue] * [[properties objectForKey:(NSString *)kCGImagePropertyPixelHeight] unsignedIntegerValue];
		if(res < bestRes) continue;
		NSUInteger const depth = [[properties objectForKey:(NSString *)kCGImagePropertyDepth] unsignedIntegerValue];
		if(depth < bestDepth) continue;
		found = YES;
		bestIndex = i;
		bestProperties = properties;
		bestRes = res;
		bestDepth = depth;
	}
	if(!found) return NO;
	if(outIndex) *outIndex = bestIndex;
	if(outProperties) *outProperties = bestProperties;
	return YES;
}
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
- (void)_readExifWithData:(NSData *)data;
- (void)_readFinishedWithImageRep:(NSImageRep *)aRep;

@end

@implementation PGGenericImageAdapter

#pragma mark Private Protocol

- (void)_threaded_imageRep
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	NSData *const data = [[self dataProvider] data];
	[self performSelectorOnMainThread:@selector(_readExifWithData:) withObject:data waitUntilDone:NO];

	size_t index = 0;
	NSDictionary *properties = nil;
	CGImageSourceRef const source = CGImageSourceCreateWithData((CFDataRef)data, (CFDictionaryRef)[self _imageSourceOptions]);
	if(PGImageSourceGetBestImageIndex(source, &index, &properties)) {
		// TODO: Get the orientation from kCGImagePropertyOrientation instead of -_readExifWithData:.
		[self performSelectorOnMainThread:@selector(_readFinishedWithImageRep:) withObject:PGImageSourceImageRepAtIndex(source, index) waitUntilDone:NO];
		CFRelease(source);
	}
	[pool drain];
}
- (NSDictionary *)_imageSourceOptions
{
	return [NSDictionary dictionaryWithObjectsAndKeys:
		[[self dataProvider] UTIType], kCGImageSourceTypeIdentifierHint,
		nil];
}
- (void)_readExifWithData:(NSData *)data
{
	if(_exifEntries || !data) return;
	PGOrientation const oldOrientation = _orientation;
	[PGExifEntry getEntries:&_exifEntries orientation:&_orientation forImageData:data];
	[_exifEntries retain];
	if(oldOrientation != _orientation) [self invalidateThumbnail];
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

- (NSArray *)exifEntries
{
	return [[_exifEntries retain] autorelease];
}
- (PGOrientation)orientationWithBase:(BOOL)flag
{
	return PGAddOrientation(_orientation, [super orientationWithBase:flag]);
}
- (void)clearCache
{
	[_exifEntries release];
	_exifEntries = nil;
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

- (NSImageRep *)threaded_thumbnailRepWithSize:(NSSize)size orientation:(PGOrientation)orientation
{
	CGImageSourceRef const source = CGImageSourceCreateWithData((CFDataRef)[[self dataProvider] data], (CFDictionaryRef)[self _imageSourceOptions]);
	size_t i = 0;
	if(!PGImageSourceGetBestImageIndex(source, &i, NULL)) return nil;
	NSBitmapImageRep *const rep = PGImageSourceImageRepAtIndex(source, i);
	CFRelease(source);
	return [rep PG_thumbnailWithMaxSize:size orientation:orientation opaque:NO];
}

#pragma mark NSObject

- (void)dealloc
{
	[_exifEntries release];
	[_cachedRep release];
	[super dealloc];
}

@end
