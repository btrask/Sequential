#import "PGPDFAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

@interface PGPDFAdapter (Private)

- (NSImage *)_image;
- (NSPDFImageRep *)_rep;

@end

@implementation PGPDFAdapter

#pragma mark Private Protocol

- (NSImage *)_image
{
	return [[_image retain] autorelease];
}
- (NSPDFImageRep *)_rep
{
	return [[_rep retain] autorelease];
}

#pragma mark PGResourceAdapter

- (void)readFromData:(NSData *)inData
        URLResponse:(NSURLResponse *)response
{
	NSData *data = [inData copy];
	if(!data) {
		data = [[[self dataSource] dataForResourceAdapter:self] copy];
		if(!data && [self needsPassword]) return;
	}
	if(!data) {
		PGResourceIdentifier *const identifier = [self identifier];
		NSParameterAssert([identifier isFileIdentifier]);
		data = [NSData dataWithContentsOfMappedFile:[[identifier URLByFollowingAliases:YES] path]];
	}
	_image = [[NSImage alloc] initWithData:data];
	_rep = (NSPDFImageRep *)[[_image bestRepresentationForDevice:nil] retain];
	if(!_rep || ![_rep isKindOfClass:[NSPDFImageRep class]]) return;
	[_image setCacheMode:NSImageCacheNever]; // Caching is broken for PDFs.

	NSDictionary *const localeDict = [[NSUserDefaults standardUserDefaults] dictionaryRepresentation];
	NSMutableArray *const nodes = [NSMutableArray array];
	int i = 0;
	for(; i < [_rep pageCount]; i++) {
		PGResourceIdentifier *const identifier = [[self identifier] subidentifierWithIndex:i];
		[identifier setDisplayName:[[NSNumber numberWithUnsignedInt:i + 1] descriptionWithLocale:localeDict]];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:self document:nil identifier:identifier adapterClass:[PGPDFPageAdapter class] dataSource:nil load:NO] autorelease];
		if(node) [nodes addObject:node];
	}
	[self setUnsortedChildren:nodes presortedOrder:PGUnsorted];
	if([self shouldReadContents]) [self readContents];
}

#pragma mark NSObject

- (void)dealloc
{
	[_image release];
	[_rep release];
	[super dealloc];
}

@end

@implementation PGPDFPageAdapter

#pragma mark PGResourceAdapter

- (void)readContents
{
	[self setHasReadContents];
	PGPDFAdapter *const adapter = (PGPDFAdapter *)[self parentAdapter];
	NSParameterAssert(adapter);
	[[adapter _rep] setCurrentPage:[[self identifier] index]];
	[self returnImage:[adapter _image] error:nil];
}
- (BOOL)isResolutionIndependent
{
	return YES;
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		[self setIsImage:YES];
	}
	return self;
}

@end
