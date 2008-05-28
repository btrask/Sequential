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

- (BOOL)canGetImageData
{
	return YES;
}
- (PGDataAvailability)getImageData:(out NSData **)outData
{
	NSData *data = [[_imageData retain] autorelease];
	if(!data) {
		data = [[self dataSource] dataForResourceAdapter:self];
		if(!data && [self needsPassword]) return PGWrongPassword;
	}
	if(!data) {
		PGResourceIdentifier *const identifier = [self identifier];
		if([identifier isFileIdentifier]) data = [NSData dataWithContentsOfMappedFile:[[identifier URLByFollowingAliases:YES] path]];
	}
	if(!data) return PGDataUnavailable;
	if(outData) *outData = data;
	return PGDataAvailable;
}
- (NSArray *)exifEntries
{
	if(!_exifEntries && [self canGetImageData]) {
		NSData *data;
		if(PGDataAvailable == [self getImageData:&data]) [PGExifEntry getEntries:&_exifEntries orientation:&_orientation forImageData:data];
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

- (void)readFromData:(NSData *)data
        URLResponse:(NSURLResponse *)response
{
	if(data) _imageData = [data copy];
	else NSParameterAssert([self dataSource] || [[self identifier] isFileIdentifier]);
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
	NSParameterAssert([self canGetImageData]);
	NSData *data = nil;
	PGDataAvailability const availability = [self getImageData:&data];
	[self setHasReadContents];
	if(PGWrongPassword == availability) return [self returnImage:nil error:PGPasswordError];
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
	[_imageData release];
	[_exifEntries release];
	[_cachedImage release];
	[super dealloc];
}

@end
