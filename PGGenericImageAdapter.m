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
	if(oldOrientation != _orientation) [self setRealThumbnail:nil];
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
