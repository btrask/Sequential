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
#import "PGGenericImageAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGResourceIdentifier.h"
#import "PGExifEntry.h"

// Categories
#import "NSImageRepAdditions.h"

@interface PGGenericImageAdapter (Private)

- (void)_threaded_getImageRepWithInfo:(NSDictionary *)info;
- (void)_readExifWithData:(NSData *)data;
- (void)_readFinishedWithImageRep:(NSImageRep *)aRep;

@end

@implementation PGGenericImageAdapter

#pragma mark Private Protocol

- (void)_threaded_getImageRepWithInfo:(NSDictionary *)info
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	NSData *data;
	@synchronized(self) {
		data = [[self node] dataWithInfo:info fast:NO];
	}
	[self performSelectorOnMainThread:@selector(_readExifWithData:) withObject:data waitUntilDone:NO];
	[self performSelectorOnMainThread:@selector(_readFinishedWithImageRep:) withObject:[NSImageRep AE_bestImageRepWithData:data] waitUntilDone:NO];
	[pool release];
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
	[[self node] readFinishedWithImageRep:aRep error:nil];
}

#pragma mark PGResourceAdapting Protocol

- (BOOL)canExtractData
{
	return YES;
}

#pragma mark -

- (void)load
{
	[self clearCache];
	_readFailed = NO;
	[[self node] noteIsViewableDidChange];
	[[self node] loadFinished];
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
		[[self node] readFinishedWithImageRep:_cachedRep error:nil];
		return;
	}
	if(_reading) return;
	_reading = YES;
	_readFailed = NO;
	[NSThread detachNewThreadSelector:@selector(_threaded_getImageRepWithInfo:) toTarget:self withObject:[[[self info] copy] autorelease]];
}
- (BOOL)canGenerateRealThumbnail
{
	return YES;
}

#pragma mark NSObject

- (void)dealloc
{
	[_exifEntries release];
	[_cachedRep release];
	[super dealloc];
}

@end
