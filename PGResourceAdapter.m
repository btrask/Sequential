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
	[self noteDateModifiedDidChange];
	[self noteDateCreatedDidChange];
	[self noteDataLengthDidChange];
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
	if(!flag) NSParameterAssert(_determiningTypeCount);
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
		if([realData length] < 4) return Nil;
		class = [d resourceAdapterClassWhereAttribute:PGBundleTypeFourCCKey matches:[realData subdataWithRange:NSMakeRange(0, 4)]];
	}
	if(!class && response) class = [d resourceAdapterClassWhereAttribute:PGCFBundleTypeMIMETypesKey matches:[response MIMEType]];
	if(!class && URL) class = [d resourceAdapterClassForExtension:[[URL path] pathExtension]];
	return class;
}
- (void)replacedWithAdapter:(PGResourceAdapter *)newAdapter
{
	if([self isMemberOfClass:[PGResourceAdapter class]]) [self setIsDeterminingType:NO];
}
- (BOOL)shouldReadRegardlessOfDepth
{
	return [[self parentAdapter] shouldReadRegardlessOfDepth];
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

- (void)noteDateModifiedDidChange
{
	[[self node] setDateModified:[self dateModified]];
}
- (void)noteDateCreatedDidChange
{
	[[self node] setDateCreated:[self dateCreated]];
}
- (void)noteDataLengthDidChange
{
	[[self node] setDataLength:[self dataLength]];
}

#pragma mark -

- (void)fileResourceDidChange:(unsigned)flags
{
	[self noteDateModifiedDidChange];
	[self noteDateCreatedDidChange];
	[self noteDataLengthDidChange];
}

#pragma mark PGResourceAdapting Protocol

- (PGContainerAdapter *)parentAdapter
{
	return [_node parentAdapter];
}
- (PGContainerAdapter *)containerAdapter
{
	return [self parentAdapter];
}
- (PGContainerAdapter *)rootContainerAdapter
{
	return [[self parentAdapter] rootContainerAdapter];
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
        error:(NSError *)error
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
	return [[self parentAdapter] viewableIndexOfChild:[self node]];
}
- (unsigned)viewableNodeCount
{
	return [self isViewable] ? 1 : 0;
}

#pragma mark -

- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
{
	return [self sortedViewableNodeFirst:flag stopAtNode:nil];
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
	    stopAtNode:(PGNode *)descendent
{
	return [self isViewable] && [self node] != descendent ? [self node] : nil;
}

- (PGNode *)sortedViewableNodeNext:(BOOL)flag
{
	return [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] withSelector:@selector(sortedViewableNodeFirst:)];
}
- (PGNode *)sotedFirstViewableNodeInFolderNext:(BOOL)flag
{
	PGNode *const node = [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] withSelector:@selector(sortedFirstViewableNodeInFolderFirst:)];
	return node || flag ? node : [[self rootContainerAdapter] sortedViewableNodeFirst:YES stopAtNode:[self node]];
}

- (PGNode *)sortedFirstViewableNodeInFolderFirst:(BOOL)flag
{
	return nil;
}

#pragma mark -

- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident
{
	return ident && [[self identifier] isEqual:ident] ? [self node] : nil;
}
- (PGNode *)ancestorThatIsChildOfNode:(PGNode *)aNode
{
	PGNode *const parent = [self parentNode];
	return aNode == parent ? [self node] : [parent ancestorThatIsChildOfNode:aNode];
}
- (BOOL)isDescendantOfNode:(PGNode *)aNode
{
	return [self ancestorThatIsChildOfNode:aNode] != nil;
}

#pragma mark -

- (NSDate *)dateModified
{
	NSDate *date = [[self dataSource] dateModifiedForResourceAdapter:self];
	if(date) return date;
	PGResourceIdentifier *const identifier = [self identifier];
	if([identifier isFileIdentifier]) date = [[[NSFileManager defaultManager] fileAttributesAtPath:[[identifier URL] path] traverseLink:NO] fileModificationDate];
	return date;
}
- (NSDate *)dateCreated
{
	NSDate *date = [[self dataSource] dateCreatedForResourceAdapter:self];
	if(date) return date;
	PGResourceIdentifier *const identifier = [self identifier];
	if([identifier isFileIdentifier]) date = [[[NSFileManager defaultManager] fileAttributesAtPath:[[identifier URL] path] traverseLink:NO] fileCreationDate];
	return date;
}
- (NSNumber *)dataLength
{
	NSNumber *dataLength = [[self dataSource] dataLengthForResourceAdapter:self];
	if(dataLength) return dataLength;
	NSData *data;
	if([self canGetImageData] && [self getImageData:&data] == PGDataAvailable) dataLength = [NSNumber numberWithUnsignedInt:[data length]];
	if(dataLength) return dataLength;
	PGResourceIdentifier *const identifier = [self identifier];
	if([identifier isFileIdentifier]) {
		NSDictionary *const attrs = [[NSFileManager defaultManager] fileAttributesAtPath:[[identifier URL] path] traverseLink:NO];
		if(![NSFileTypeDirectory isEqualToString:[attrs fileType]]) dataLength = [attrs objectForKey:NSFileSize]; // File size is meaningless for folders.
	}
	return dataLength;
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
	return [self isViewable] && [[self identifier] hasTarget];
}
- (PGBookmark *)bookmark
{
	return [[[PGBookmark alloc] initWithNode:[self node]] autorelease];
}

#pragma mark -

- (void)sortOrderDidChange {}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		if([self isMemberOfClass:[PGResourceAdapter class]]) [self setIsDeterminingType:YES];
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
