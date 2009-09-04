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

// Controllers
#import "PGDocumentController.h"

// Other
#import "PGCancelableProxy.h"

// Categories
#import "NSMutableDictionaryAdditions.h"
#import "NSStringAdditions.h"

static NSString *const PGKnownToBeArchiveKey = @"PGKnownToBeArchive";
static id PGArchiveAdapterList = nil;

@interface PGArchiveAdapter(Private)

- (void)_updateThumbnailsOfChildren;

@end

@interface XADArchive(PGAdditions)

- (NSString *)PG_commonRootPath;
- (NSString *)PG_OSTypeForEntry:(NSInteger)index standardFormat:(BOOL)flag;
- (NSString *)PG_typeForEntry:(NSInteger)index preferOSType:(BOOL)flag;

@end

@implementation PGArchiveAdapter

#pragma mark +PGResourceAdapter

+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	return [[info objectForKey:PGKnownToBeArchiveKey] boolValue] ? PGMatchByIntrinsicAttribute : [super matchPriorityForNode:node withInfo:info];
}

#pragma mark +NSObject

+ (void)initialize
{
	if([PGArchiveAdapter class] == self) PGArchiveAdapterList = [[PGCancelableProxy storage] retain];
}

#pragma mark -PGArchiveAdapter

- (XADArchive *)archive
{
	return [[_archive retain] autorelease];
}
- (NSArray *)nodesUnderPath:(NSString *)path
             parentAdapter:(PGContainerAdapter *)parent
             remainingIndexes:(NSMutableIndexSet *)indexes
{
	NSParameterAssert(path);
	NSParameterAssert(parent);
	NSParameterAssert(_archive);
	NSMutableArray *const children = [NSMutableArray array];
	NSInteger i = [indexes firstIndex];
	for(; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) {
		NSString *const entryPath = [_archive nameOfEntry:i];
		if(_encodingError) return nil;
		if(!entryPath || (![entryPath hasPrefix:path] && ![path isEqualToString:@""])) continue;
		[indexes removeIndex:i];
		if([[entryPath lastPathComponent] hasPrefix:@"."]) continue;
		NSString *const subpath = [path stringByAppendingPathComponent:[[entryPath substringFromIndex:[path length]] AE_firstPathComponent]];
		if([path isEqualToString:entryPath]) continue;
		BOOL const isEntrylessFolder = ![subpath isEqualToString:entryPath];
		BOOL const isFile = !isEntrylessFolder && ![_archive entryIsDirectory:i];
		PGDisplayableIdentifier *const identifier = [[[self identifier] subidentifierWithIndex:(isEntrylessFolder ? NSNotFound : i)] displayableIdentifier];
		[identifier setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:(isEntrylessFolder ? NSFileTypeForHFSTypeCode(kGenericFolderIcon) : [_archive PG_typeForEntry:i preferOSType:YES])]];
		[identifier setNaturalDisplayName:[subpath lastPathComponent]];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:parent document:nil identifier:identifier dataSource:self] autorelease];
		NSMutableDictionary *const info = [NSMutableDictionary dictionaryWithObjectsAndKeys:(isEntrylessFolder ? PGPseudoFileTypeForHFSTypeCode(kGenericFolderIcon) : [_archive PG_OSTypeForEntry:i standardFormat:NO]), PGOSTypeKey, nil];
		if(isFile) [node startLoadWithInfo:info];
		else {
			[info setObject:[PGContainerAdapter class] forKey:PGAdapterClassKey];
			[node startLoadWithInfo:info];
			if(isEntrylessFolder) [indexes addIndex:i]; // We ended up taking care of a folder in its path instead.
			PGContainerAdapter *const adapter = (id)[node resourceAdapter];
			[adapter setUnsortedChildren:[self nodesUnderPath:subpath parentAdapter:adapter remainingIndexes:indexes] presortedOrder:PGUnsorted];
		}
		if(node) [children addObject:node];
	}
	return children;
}

#pragma mark -PGArchiveAdapter(Private)

- (void)_updateThumbnailsOfChildren
{
	[[self document] noteNodeThumbnailDidChange:[self node] recursively:YES];
}

#pragma mark -PGResourceAdapter

- (PGLoadPolicy)descendentLoadPolicy
{
	return PGLoadAll;
}
- (void)load
{
	if(!_archive) {
		XADError error = XADNoError;
		PGResourceIdentifier *const ident = [[self info] objectForKey:PGIdentifierKey];
		id const dataSource = [[self node] dataSource];
		if([dataSource respondsToSelector:@selector(archive)]) {
			_archive = [[XADArchive alloc] initWithArchive:[dataSource archive] entry:[ident index] error:&error];
		} else if([ident isFileIdentifier]) _archive = [[XADArchive alloc] initWithFile:[[ident URL] path] delegate:self error:&error]; // -data will return data for file URLs, but it's worth using -[XADArchive initWithFile:...].
		else {
			NSData *const data = [self data];
			if(!data) return [[self node] loadFinished];
			_archive = [[XADArchive alloc] initWithData:data error:&error];
			[_archive setDelegate:self];
		}
		if(!_archive || error != XADNoError || [_archive isCorrupted]) return [[self node] loadFinished];
	}
	NSNumber *const encodingNum = [[self info] objectForKey:PGStringEncodingKey];
	if(encodingNum) [_archive setNameEncoding:[encodingNum unsignedIntegerValue]];
	NSArray *const children = [self nodesUnderPath:[_archive PG_commonRootPath] parentAdapter:self remainingIndexes:[NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_archive numberOfEntries])]];
	[self setUnsortedChildren:children presortedOrder:PGUnsorted];
	if(!_encodingError) [[self node] loadFinished];
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
	[_currentSubnode performSelectorOnMainThread:@selector(setError:) withObject:[NSError errorWithDomain:PGNodeErrorDomain code:PGPasswordError userInfo:nil] waitUntilDone:NO];
}
- (NSStringEncoding)archive:(XADArchive *)archive encodingForData:(NSData *)data guess:(NSStringEncoding)guess confidence:(CGFloat)confidence
{
	if(confidence < 0.8f && !_encodingError) {
		_encodingError = YES;
		[[self node] performSelectorOnMainThread:@selector(setError:) withObject:[NSError errorWithDomain:PGNodeErrorDomain code:PGEncodingError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:data, PGUnencodedStringDataKey, [NSNumber numberWithUnsignedInteger:guess], PGDefaultEncodingKey, nil]] waitUntilDone:YES];
		[[self node] loadFinished];
	}
	return guess;
}

#pragma mark -<PGNodeDataSource>

- (NSDate *)dateCreatedForNode:(PGNode *)sender
{
	NSUInteger const i = [[sender identifier] index];
	if(NSNotFound == i) return nil;
	return [[_archive attributesOfEntry:i] objectForKey:XADCreationDateKey];
}
- (NSNumber *)dataLengthForNode:(PGNode *)sender
{
	NSUInteger const i = [[sender identifier] index];
	return NSNotFound == i || [_archive entryIsDirectory:i] ? nil : [NSNumber numberWithUnsignedLongLong:[_archive representativeSizeOfEntry:i]];
}
- (void)node:(PGNode *)sender
        willLoadWithInfo:(NSMutableDictionary *)info
{
	NSUInteger const i = [[sender identifier] index];
	if(NSNotFound == i) return;
	if([_archive entryIsArchive:i]) [info setObject:[NSNumber numberWithBool:YES] forKey:PGKnownToBeArchiveKey];
	if(![info objectForKey:PGOSTypeKey]) [info AE_setObject:[_archive PG_OSTypeForEntry:i standardFormat:NO] forKey:PGOSTypeKey];
	if(![info objectForKey:PGExtensionKey]) [info AE_setObject:[[_archive nameOfEntry:i] pathExtension] forKey:PGExtensionKey];
}
- (BOOL)node:(PGNode *)sender
        getData:(out NSData **)outData
        info:(NSDictionary *)info
        fast:(BOOL)flag
{
	NSUInteger const i = [[sender identifier] index];
	if(NSNotFound == i || flag) {
		if(outData) *outData = nil;
		return YES;
	}
	NSData *data = nil;
	@synchronized(_archive) {
		NSString *const pass = [info objectForKey:PGPasswordKey];
		if(pass) [_archive setPassword:pass];
		BOOL const neededPassword = _needsPassword;
		_needsPassword = NO;
		_currentSubnode = sender;
		data = [_archive contentsOfEntry:i];
		_currentSubnode = nil;
		if(neededPassword && !_needsPassword) [[PGArchiveAdapter PG_performOn:self allowOnce:YES withStorage:PGArchiveAdapterList] performSelectorOnMainThread:@selector(_updateThumbnailsOfChildren) withObject:nil waitUntilDone:NO];
	}
	if(outData) *outData = data;
	return YES;
}

#pragma mark -<PGResourceAdapting>

- (BOOL)canSaveData
{
	return YES;
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
		else while(![root isEqualToString:entryName]) {
			if([root length] > [entryName length]) root = [root stringByDeletingLastPathComponent];
			else entryName = [entryName stringByDeletingLastPathComponent];
		}
	}
	return root ? root : @"";
}
- (NSString *)PG_OSTypeForEntry:(NSInteger)index
              standardFormat:(BOOL)flag
{
	OSType value;
	if([self entryIsDirectory:index]) value = kGenericFolderIcon;
	else {
		NSNumber *const typeCode = [[self attributesOfEntry:index] objectForKey:NSFileHFSTypeCode];
		if(!typeCode) return nil;
		value = [typeCode unsignedLongValue];
	}
	return flag ? NSFileTypeForHFSTypeCode(value) : PGPseudoFileTypeForHFSTypeCode(value);
}
- (NSString *)PG_typeForEntry:(NSInteger)index
              preferOSType:(BOOL)flag
{
	NSString *const osType = flag ? [self PG_OSTypeForEntry:index standardFormat:YES] : nil;
	return osType ? osType : [[self nameOfEntry:index] pathExtension];
}

@end
