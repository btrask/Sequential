#import "PGResourceAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGWebAdapter.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSMenuItemAdditions.h"

@implementation PGResourceAdapter

#pragma mark Instance Methods

- (PGNode *)node
{
	return _node;
}
- (void)setNode:(PGNode *)aNode
{
	if(aNode == _node) return;
	_node = aNode;
	[self noteIsViewableDidChange];
}

#pragma mark -

- (BOOL)isDeterminingType
{
	return _determiningTypeCount > 0;
}
- (BOOL)isImage
{
	return _isImage;
}
- (BOOL)needsPassword
{
	return _needsPassword;
}
- (BOOL)needsEncoding
{
	return _needsEncoding;
}
- (void)setIsDeterminingType:(BOOL)flag
{
	_determiningTypeCount += flag ? 1 : -1;
	[self noteIsViewableDidChange];
}
- (void)setIsImage:(BOOL)flag
{
	if(flag == _isImage) return;
	_isImage = flag;
	[self noteIsViewableDidChange];
}
- (void)setNeedsEncoding:(BOOL)flag
{
	if(flag == _needsEncoding) return;
	_needsEncoding = flag;
	[self noteIsViewableDidChange];
}
- (void)setNeedsPassword:(BOOL)flag
{
	if(flag == _needsPassword) return;
	_needsPassword = flag;
	[self noteIsViewableDidChange];
}
- (void)noteIsViewableDidChange
{
	[[self node] setIsViewable:[self isViewable]];
}

#pragma mark -

- (void)loadFromData:(NSData *)data
        URLResponse:(NSURLResponse *)response
{
	PGResourceAdapter *const adapter = [[self node] setResourceAdapterClass:[self classForData:data URLResponse:response]];
	if([adapter shouldRead]) [adapter readFromData:data URLResponse:response];
	[self replacedWithAdapter:adapter];
}
- (Class)classForData:(NSData *)data
         URLResponse:(NSURLResponse *)response
{
	if([response respondsToSelector:@selector(statusCode)]) {
		int const status = [(NSHTTPURLResponse *)response statusCode];
		if(status < 200 || status >= 300) return Nil;
	}
	PGDocumentController *const d = [PGDocumentController sharedDocumentController];
	NSURL *const URL = [[self identifier] URLByFollowingAliases:YES];
	if(!data && URL) {
		if(![URL isFileURL]) return [PGWebAdapter class];
		BOOL isDir;
		if(![[NSFileManager defaultManager] fileExistsAtPath:[URL path] isDirectory:&isDir]) return Nil;
		if(isDir) return [d resourceAdapterClassWhereAttribute:PGLSTypeIsPackageKey matches:[NSNumber numberWithBool:YES]];
	}
	Class class = Nil;
	if(data || [URL isFileURL]) {
		NSData *const realData = data ? data : [NSData dataWithContentsOfMappedFile:[URL path]];
		if([realData length] >= 4) class = [d resourceAdapterClassWhereAttribute:PGBundleTypeFourCCKey matches:[realData subdataWithRange:NSMakeRange(0, 4)]];
	}
	if(!class && response) class = [d resourceAdapterClassWhereAttribute:PGCFBundleTypeMIMETypesKey matches:[response MIMEType]];
	if(!class && URL) class = [d resourceAdapterClassForExtension:[[URL path] pathExtension]];
	return class;
}
- (void)replacedWithAdapter:(PGResourceAdapter *)newAdapter
{
	[self setIsDeterminingType:NO];
	[newAdapter setIsDeterminingType:NO];
}
- (BOOL)shouldReadAllDescendants
{
	return [[self parentAdapter] shouldReadAllDescendants];
}
- (BOOL)shouldRead
{
	return YES;
}
- (void)readFromData:(NSData *)data URLResponse:(NSURLResponse *)response {}

#pragma mark -

- (BOOL)shouldReadContents
{
	return [self expectsReturnedImage] && !_hasReadContents;
}
- (void)setHasReadContents
{
	NSParameterAssert([self expectsReturnedImage]);
	_hasReadContents = YES;
}
- (void)readContents
{
	if([self isDeterminingType]) return;
	[self setHasReadContents];
	[self returnImage:nil error:nil];
}

#pragma mark -

- (NSString *)sortName
{
	return [[self identifier] displayName];
}
- (NSDate *)dateModified:(BOOL)allowNil
{
	NSDate *date = [[self dataSource] dateModifiedForResourceAdapter:self];
	if(!date) {
		PGResourceIdentifier *const identifier = [self identifier];
		if([identifier isFileIdentifier]) date = [[[NSFileManager defaultManager] fileAttributesAtPath:[[identifier URL] path] traverseLink:NO] fileModificationDate];
	}
	return date || allowNil ? date : [NSDate distantPast];
}
- (NSDate *)dateCreated:(BOOL)allowNil
{
	NSDate *date = [[self dataSource] dateCreatedForResourceAdapter:self];
	if(!date) {
		PGResourceIdentifier *const identifier = [self identifier];
		if([identifier isFileIdentifier]) date = [[[NSFileManager defaultManager] fileAttributesAtPath:[[identifier URL] path] traverseLink:NO] fileCreationDate];
	}
	return date || allowNil ? date : [NSDate distantPast];
}
- (NSNumber *)size:(BOOL)allowNil
{
	NSNumber *size = [[self dataSource] dataLengthForResourceAdapter:self];
	if(!size) {
		NSData *data;
		if([self canGetImageData] && [self getImageData:&data] == PGDataAvailable) size = [NSNumber numberWithUnsignedInt:[data length]];
	}
	if(!size) {
		PGResourceIdentifier *const identifier = [self identifier];
		if([identifier isFileIdentifier]) {
			NSDictionary *const attrs = [[NSFileManager defaultManager] fileAttributesAtPath:[[identifier URL] path] traverseLink:NO];
			if(![NSFileTypeDirectory isEqualToString:[attrs fileType]]) size = [attrs objectForKey:NSFileSize]; // File size is meaningless for folders.
		}
	}
	return size || allowNil ? size : [NSNumber numberWithUnsignedInt:0];
}

#pragma mark -

- (void)fileResourceDidChange:(unsigned)flags {}

#pragma mark PGResourceAdapting Protocol

- (PGContainerAdapter *)parentAdapter
{
	return [_node parentAdapter];
}
- (PGDocument *)document
{
	return [_node document];
}
- (PGNode *)parentNode
{
	return [[self parentAdapter] node];
}

#pragma mark -

- (PGResourceIdentifier *)identifier
{
	return [_node identifier];
}
- (id)dataSource
{
	return [_node dataSource];
}

#pragma mark -

- (BOOL)isViewable
{
	return [self isDeterminingType] || [self isImage] || [self needsPassword] || [self needsEncoding];
}
- (float)loadingProgress
{
	return 0;
}
- (BOOL)canGetImageData
{
	return NO;
}
- (PGDataAvailability)getImageData:(out NSData **)outData
{
	return PGDataUnavailable;
}
- (NSArray *)exifEntries
{
	return nil;
}
- (PGOrientation)orientation
{
	return [[self document] baseOrientation];
}
- (BOOL)isResolutionIndependent
{
	return NO;
}
- (void)clearCache {}
- (BOOL)isContainer
{
	return NO;
}

#pragma mark -

- (NSString *)lastPassword
{
	return [[self node] lastPassword];
}
- (BOOL)expectsReturnedImage
{
	return [[self node] expectsReturnedImage];
}
- (void)returnImage:(NSImage *)anImage
        error:(NSString *)error
{
	NSParameterAssert(_hasReadContents);
	_hasReadContents = NO;
	[[self node] returnImage:anImage error:error];
}

#pragma mark -

- (BOOL)hasViewableNodes
{
	return [self isViewable];
}
- (BOOL)hasImageDataNodes
{
	return [self canGetImageData];
}
- (unsigned)viewableNodeIndex
{
	return [[self parentAdapter] viewableIndexOfNode:[self node]];
}
- (unsigned)viewableNodeCount
{
	return [self isViewable] ? 1 : 0;
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)first
{
	return [self isViewable] ? [self node] : nil;
}
- (PGNode *)sortedViewableNodeNext:(BOOL)next
{
	return [[self parentAdapter] next:next sortedViewableNodeBeyond:[self node]];
}
- (PGNode *)nodeEquivalentToNode:(PGNode *)aNode
{
	return [aNode isEqual:[self node]] ? [self node] : nil;
}
- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident
{
	return [[self identifier] isEqual:ident] ? [self node] : nil;
}
- (BOOL)isDescendantOfNode:(PGNode *)aNode
{
	PGNode *const parent = [self parentNode];
	if(aNode == parent) return YES;
	if(!parent) return NO;
	return [parent isDescendantOfNode:aNode];
}

#pragma mark -

- (void)addMenuItemsToMenu:(NSMenu *)aMenu
{
	[[[self node] menuItem] AE_removeFromMenu];
	[aMenu addItem:[[self node] menuItem]];
}

#pragma mark -

- (char const *)unencodedSampleString
{
	return NULL;
}
- (NSStringEncoding)defaultEncoding
{
	return 0;
}
- (void)setEncoding:(NSStringEncoding)encoding {}

#pragma mark -

- (BOOL)canBookmark
{
	return [self isViewable];
}
- (PGBookmark *)bookmark
{
	return [[[PGBookmark alloc] initWithNode:[self node]] autorelease];
}
- (PGNode *)nodeForBookmark:(PGBookmark *)aBookmark
{
	return [[self identifier] isEqual:[aBookmark fileIdentifier]] ? [self node] : nil;
}

#pragma mark -

- (void)sortOrderDidChange {}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		[self setIsDeterminingType:YES];
	}
	return self;
}

@end

@implementation NSObject (PGResourceAdapterDataSource)

- (NSDate *)dateModifiedForResourceAdapter:(PGResourceAdapter *)sender
{
	return nil;
}
- (NSDate *)dateCreatedForResourceAdapter:(PGResourceAdapter *)sender
{
	return nil;
}
- (NSNumber *)dataLengthForResourceAdapter:(PGResourceAdapter *)sender
{
	return nil;
}
- (NSData *)dataForResourceAdapter:(PGResourceAdapter *)sender
{
	return nil;
}

@end
