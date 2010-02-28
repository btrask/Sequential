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
#import "PGArchiveAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGResourceIdentifier.h"
#import "PGDataProvider.h"

// Controllers
#import "PGDocumentController.h"

// Other Sources
#import "PGCancelableProxy.h"
#import "PGFoundationAdditions.h"

static id PGArchiveAdapterList = nil;

@interface PGDataProvider(PGArchiveDataProvider)

- (XADArchive *)archive;
- (int)entry;

@end

@interface PGArchiveDataProvider : PGDataProvider
{
	@private
	XADArchive *_archive;
	int _entry;
}

- (id)initWithArchive:(XADArchive *)archive entry:(int)entry;

@end

@interface PGFolderDataProvider : PGDataProvider

@end

@interface PGArchiveAdapter(Private)

- (void)_threaded_setError:(NSError *)error forNode:(PGNode *)node;
- (void)_updateThumbnailsOfChildren;

@end

@interface XADArchive(PGAdditions)

- (NSString *)PG_commonRootPath;
- (OSType)PG_OSTypeForEntry:(int)entry;

@end

@implementation PGArchiveAdapter

#pragma mark +NSObject

+ (void)initialize
{
	if([PGArchiveAdapter class] == self) PGArchiveAdapterList = [[PGCancelableProxy storage] retain];
}

#pragma mark -PGArchiveAdapter

- (NSArray *)nodesUnderPath:(NSString *)path parentAdapter:(PGContainerAdapter *)parent remainingIndexes:(NSMutableIndexSet *)indexes
{
	NSParameterAssert(path);
	NSParameterAssert(parent);
	NSParameterAssert(_archive);
	NSMutableArray *const children = [NSMutableArray array];
	NSUInteger i = [indexes firstIndex];
	for(; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) {
		NSString *const entryPath = [_archive nameOfEntry:i];
		if(_encodingError) return nil;
		if(!entryPath) continue;
		if([path length] && ![entryPath hasPrefix:path]) continue;
		[indexes removeIndex:i];
		if([[entryPath lastPathComponent] hasPrefix:@"."]) continue;
		NSString *const subpath = [path stringByAppendingPathComponent:[[entryPath substringFromIndex:[path length]] PG_firstPathComponent]];
		if(PGEqualObjects(path, entryPath)) continue;
		BOOL const isEntrylessFolder = !PGEqualObjects(subpath, entryPath);
		BOOL const isFile = !isEntrylessFolder && ![_archive entryIsDirectory:i];
		PGDisplayableIdentifier *const identifier = [[[[self node] identifier] subidentifierWithIndex:isEntrylessFolder ? NSNotFound : i] displayableIdentifier];
		[identifier setNaturalDisplayName:[subpath lastPathComponent]];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:parent document:nil identifier:identifier] autorelease];
		if(isFile) [node loadWithDataProvider:[[[PGArchiveDataProvider alloc] initWithArchive:_archive entry:i] autorelease]];
		else {
			[node loadWithDataProvider:[[[PGFolderDataProvider alloc] init] autorelease]];
			if(isEntrylessFolder) [indexes addIndex:i]; // We ended up taking care of a folder in its path instead.
			PGContainerAdapter *const adapter = (PGContainerAdapter *)[node resourceAdapter];
			[adapter setUnsortedChildren:[self nodesUnderPath:subpath parentAdapter:adapter remainingIndexes:indexes] presortedOrder:PGUnsorted];
		}
		[identifier setIcon:[[[node resourceAdapter] dataProvider] icon]];
		if(node) [children addObject:node];
	}
	return children;
}

#pragma mark -PGArchiveAdapter(Private)

- (void)_threaded_setError:(NSError *)error forNode:(PGNode *)node;
{
	// TODO: Figure this out...
//	[node performSelectorOnMainThread:@selector(setError:) withObject:error waitUntilDone:YES];
}
- (void)_updateThumbnailsOfChildren
{
	[[self document] noteNodeThumbnailDidChange:[self node] recursively:YES];
}

#pragma mark -PGResourceAdapter

- (BOOL)canSaveData
{
	return YES;
}

#pragma mark -

- (PGLoadPolicy)descendentLoadPolicy
{
	return PGLoadAll;
}
- (void)load
{
	if(!_archive) {
		XADError error = XADNoError;
		PGDataProvider *const dataProvider = [self dataProvider];
		PGResourceIdentifier *const ident = [dataProvider identifier];
		if([dataProvider archive]) @synchronized([dataProvider archive]) {
			_archive = [[XADArchive alloc] initWithArchive:[dataProvider archive] entry:[dataProvider entry] delegate:self error:&error];
		} else if([ident isFileIdentifier]) _archive = [[XADArchive alloc] initWithFile:[[ident URL] path] delegate:self error:&error]; // -data will return data for file URLs, but it's worth using -[XADArchive initWithFile:...].
		else {
			NSData *const data = [self data];
			if(data) _archive = [[XADArchive alloc] initWithData:data delegate:self error:&error];
		}
		if(!_archive || error != XADNoError || [_archive isCorrupted]) return [[self node] loadFailedWithError:nil forAdapter:self]; // TODO: Return an appropriate error.
	}
	// TODO: Have some way of dealing with encodings.
	NSNumber *const encodingNum = nil;//[[self info] objectForKey:PGStringEncodingKey];
	if(encodingNum) [_archive setNameEncoding:[encodingNum unsignedIntegerValue]];
	NSArray *const children = [self nodesUnderPath:[_archive PG_commonRootPath] parentAdapter:self remainingIndexes:[NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_archive numberOfEntries])]];
	[self setUnsortedChildren:children presortedOrder:PGUnsorted];
	if(!_encodingError) [[self node] loadSucceededForAdapter:self];
}

#pragma mark -NSObject

- (void)dealloc
{
	[self PG_cancelPerformsWithStorage:PGArchiveAdapterList];
	@synchronized(_archive) {
		[_archive release];
		_archive = nil;
	}
	[super dealloc];
}

#pragma mark -NSObject(XADArchiveDelegate)

- (void)archiveNeedsPassword:(XADArchive *)archive
{
	_needsPassword = YES;
	[self _threaded_setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGPasswordError userInfo:nil] forNode:_currentSubnode];
}
-(NSStringEncoding)archive:(XADArchive *)archive encodingForData:(NSData *)data guess:(NSStringEncoding)guess confidence:(float)confidence
{
	if(confidence < 0.8f && !_encodingError) {
		_encodingError = YES;
		[self _threaded_setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGEncodingError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:data, PGUnencodedStringDataKey, [NSNumber numberWithUnsignedInteger:guess], PGDefaultEncodingKey, nil]] forNode:[self node]];
		[[self node] loadFailedWithError:nil forAdapter:self]; // TODO: Return an appropriate error.
	}
	return guess;
}

//#pragma mark -<PGNodeDataSource>
//
//- (NSDictionary *)fileAttributesForNode:(PGNode *)node
//{
//	NSUInteger const i = [[node identifier] index];
//	if(NSNotFound == i) return nil;
//	NSMutableDictionary *const attributes = [NSMutableDictionary dictionary];
//	[attributes PG_setObject:[[_archive attributesOfEntry:i] objectForKey:XADCreationDateKey] forKey:NSFileCreationDate];
//	if(![_archive entryIsDirectory:i]) [attributes setObject:[NSNumber numberWithUnsignedLongLong:[_archive representativeSizeOfEntry:i]] forKey:NSFileSize];
//	return attributes;
//}
//- (void)node:(PGNode *)sender willLoadWithInfo:(NSMutableDictionary *)info
//{
//	NSUInteger const i = [[sender identifier] index];
//	if(NSNotFound == i) return;
//	if([_archive entryIsArchive:i]) [info setObject:[NSNumber numberWithBool:YES] forKey:PGKnownToBeArchiveKey];
//	if(![info objectForKey:PGOSTypeKey]) [info PG_setObject:[_archive PG_OSTypeForEntry:i standardFormat:NO] forKey:PGOSTypeKey];
//	if(![info objectForKey:PGExtensionKey]) [info PG_setObject:[[_archive nameOfEntry:i] pathExtension] forKey:PGExtensionKey];
//}
//- (BOOL)node:(PGNode *)sender getData:(out NSData **)outData info:(NSDictionary *)info fast:(BOOL)flag
//{
//	NSUInteger const i = [[sender identifier] index];
//	if(NSNotFound == i || flag || [_archive entryIsDirectory:i]) {
//		if(outData) *outData = nil;
//		return YES;
//	}
//	NSData *data = nil;
//	@synchronized(_archive) {
//		NSString *const pass = [info objectForKey:PGPasswordKey];
//		if(pass) [_archive setPassword:pass];
//		BOOL const neededPassword = _needsPassword;
//		_needsPassword = NO;
//		_currentSubnode = sender;
//		[_archive clearLastError];
//		data = [_archive contentsOfEntry:i];
//		switch([_archive lastError]) {
//			case XADNoError:
//			case XADEncodingError:
//				break;
//			case XADPasswordError: 
//				if(!_needsPassword) [self archiveNeedsPassword:_archive];
//				break;
//			default:
//				[self _threaded_setError:[NSError PG_errorWithDomain:PGNodeErrorDomain code:PGGenericError localizedDescription:[NSString stringWithFormat:NSLocalizedString(@"The error “%@” occurred while parsing the archive.", @"XADMaster error reporting. %@ is replaced with the XADMaster error."), [_archive describeLastError]] userInfo:nil] forNode:_currentSubnode];
//				break;
//		}
//		_currentSubnode = nil;
//		if(neededPassword && !_needsPassword) [[PGArchiveAdapter PG_performOn:self allowOnce:YES withStorage:PGArchiveAdapterList] performSelectorOnMainThread:@selector(_updateThumbnailsOfChildren) withObject:nil waitUntilDone:NO];
//	}
//	if(outData) *outData = data;
//	return YES;
//}

@end

@implementation PGDataProvider(PGArchiveDataProvider)

- (XADArchive *)archive
{
	return nil;
}
- (int)entry
{
	return 0;
}

@end

@implementation PGArchiveDataProvider

#pragma mark -PGArchiveDataProvider

- (id)initWithArchive:(XADArchive *)archive entry:(int)entry;
{
	if((self = [super init])) {
		_archive = [archive retain];
		_entry = entry;
	}
	return self;
}

#pragma mark -PGDataProvider

- (NSData *)data
{
	@synchronized(_archive) {
		return [_archive contentsOfEntry:_entry]; // TODO: Handle encoding and password issues.
	}
}
- (NSDate *)dateCreated
{
	@synchronized(_archive) {
		return [[_archive attributesOfEntry:_entry] objectForKey:XADCreationDateKey];
	}
}

#pragma mark -

- (OSType)typeCode
{
	@synchronized(_archive) {
		return [_archive PG_OSTypeForEntry:_entry];
	}
}
- (NSString *)extension
{
	@synchronized(_archive) {
		return [[[_archive nameOfEntry:_entry] pathExtension] lowercaseString];
	}
}

#pragma mark -

- (NSData *)fourCCData
{
	return nil; // Too slow.
}
- (NSUInteger)size
{
	@synchronized(_archive) {
		return (NSUInteger)[_archive representativeSizeOfEntry:_entry];
	}
}

#pragma mark -PGDataProvider(PGArchiveDataProvider)

- (XADArchive *)archive
{
	return _archive;
}
- (int)entry
{
	return _entry;
}

#pragma mark -PGDataProvider(PGResourceAdapterLoading)

- (NSArray *)adapterClassesForNode:(PGNode *)node
{
	@synchronized(_archive) {
		if([_archive entryIsArchive:_entry]) return [NSArray arrayWithObject:[PGArchiveAdapter class]];
	}
	return [super adapterClassesForNode:node];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_archive release];
	[super dealloc];
}

@end

@implementation PGFolderDataProvider

#pragma mark -PGDataProvider

- (OSType)typeCode
{
	return 'fold';
}

#pragma mark -PGDataProvider(PGResourceAdapterLoading)

- (NSArray *)adapterClassesForNode:(PGNode *)node
{
	return [NSArray arrayWithObject:[PGContainerAdapter class]];
}

@end

@implementation XADArchive(PGAdditions)

- (NSString *)PG_commonRootPath
{
	NSInteger i;
	NSString *root = nil;
	for(i = 0; i < [self numberOfEntries]; i++) {
		NSString *entryName = [self nameOfEntry:i];
		if(![self entryIsDirectory:i]) entryName = [entryName stringByDeletingLastPathComponent];
		else if([entryName hasSuffix:@"/"]) entryName = [entryName substringToIndex:[entryName length] - 1];
		if(!root) root = entryName;
		else while(!PGEqualObjects(root, entryName)) {
			if([root length] > [entryName length]) root = [root stringByDeletingLastPathComponent];
			else entryName = [entryName stringByDeletingLastPathComponent];
		}
	}
	return root ? root : @"";
}
- (OSType)PG_OSTypeForEntry:(int)entry
{
	return [self entryIsDirectory:entry] ? 'fold' : [[[self attributesOfEntry:entry] objectForKey:NSFileHFSTypeCode] unsignedLongValue];
}

@end
