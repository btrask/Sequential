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
#import "PGGenericImageAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGResourceIdentifier.h"

static NSString *const PGGenericImageAdapterImageRepsKey = @"PGGenericImageAdapterImageReps";

@interface PGGenericImageAdapter (Private)

- (void)_threaded_getImageWithData:(NSData *)data;
- (NSImage *)_threadsafe_imageWithReps:(NSArray *)reps;
- (void)_returnImage:(NSDictionary *)aDict;

@end

@implementation PGGenericImageAdapter

#pragma mark Private Protocol

- (void)_threaded_getImageWithData:(NSData *)data
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	NSArray *reps = [NSBitmapImageRep imageRepsWithData:data];
	NSMutableDictionary *const dict = [NSMutableDictionary dictionary];
	if(PGIsLeopardOrLater()) { // NSImage is thread-safe.
		NSImage *const image = [self _threadsafe_imageWithReps:reps];
		if(image) [dict setObject:image forKey:PGImageKey];
	} else if(reps) [dict setObject:reps forKey:PGGenericImageAdapterImageRepsKey];
	[self performSelectorOnMainThread:@selector(_returnImage:) withObject:dict waitUntilDone:NO];
	[pool release];
}
- (NSImage *)_threadsafe_imageWithReps:(NSArray *)reps
{
	if(![reps count]) return nil;
	NSImage *const image = [[[NSImage alloc] init] autorelease];
	[image addRepresentations:reps];
	[image setDataRetained:YES];
	[image setScalesWhenResized:YES];
	return image;
}
- (void)_returnImage:(NSDictionary *)aDict
{
	NSImage *image = [aDict objectForKey:PGImageKey];
	if(!image) image = [self _threadsafe_imageWithReps:[aDict objectForKey:PGGenericImageAdapterImageRepsKey]];
	[self setIsImage:(image != nil)];
	[_cachedImage release];
	_cachedImage = [image retain];
	[[self document] noteNodeDidCache:[self node]];
	[self returnImage:image error:nil];
}

#pragma mark PGResourceAdapting Protocol

- (BOOL)canGetData
{
	return YES;
}
- (PGDataAvailability)getData:(out NSData **)outData
{
	PGDataAvailability const availability = [super getData:outData];
	if(PGDataUnavailable != availability) return availability;
	NSData *data = nil;
	PGResourceIdentifier *const identifier = [self identifier];
	if([identifier isFileIdentifier]) data = [NSData dataWithContentsOfMappedFile:[[identifier URLByFollowingAliases:YES] path]];
	if(outData) *outData = data;
	return data ? PGDataAvailable : PGDataUnavailable;
}
- (NSArray *)exifEntries
{
	if(!_exifEntries && [self canGetData]) {
		NSData *data;
		if(PGDataAvailable == [self getData:&data]) [PGExifEntry getEntries:&_exifEntries orientation:&_orientation forImageData:data];
		[_exifEntries retain];
	}
	return [[_exifEntries retain] autorelease];
}
- (PGOrientation)orientation
{
	(void)[self exifEntries];
	return PGAddOrientation(_orientation, [super orientation]);
}
- (void)clearCache
{
	[_exifEntries release];
	_exifEntries = nil;
	[_cachedImage release];
	_cachedImage = nil;
}

#pragma mark PGResourceAdapter

- (void)readWithURLResponse:(NSURLResponse *)response
{
	NSParameterAssert([self canGetData] || [self dataSource] || [[self identifier] isFileIdentifier]);
	if([self shouldReadContents]) [self readContents];
}
- (void)readContents
{
	if(_cachedImage) {
		[self setHasReadContents];
		[[self document] noteNodeDidCache:[self node]];
		[self returnImage:_cachedImage error:nil];
		return;
	}
	NSParameterAssert([self canGetData]);
	NSData *data = nil;
	PGDataAvailability const availability = [self getData:&data];
	[self setHasReadContents];
	if(PGWrongPassword == availability) return [self returnImage:nil error:[NSError errorWithDomain:PGNodeErrorDomain code:PGPasswordError userInfo:nil]];
	if(PGDataUnavailable == availability) {
		[self setIsImage:NO];
		[self returnImage:nil error:nil];
		return;
	}
	[NSThread detachNewThreadSelector:@selector(_threaded_getImageWithData:) toTarget:self withObject:data];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		[self setIsImage:YES];
	}
	return self;
}
- (void)dealloc
{
	[_exifEntries release];
	[_cachedImage release];
	[super dealloc];
}

@end
