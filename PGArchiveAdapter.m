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

- (NSString *)OSTypeForEntry:(int)index standardFormat:(BOOL)flag;
- (NSString *)typeForEntry:(int)index preferOSType:(BOOL)flag;

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
	int i = [indexes firstIndex];
	for(; NSNotFound != i; i = [indexes indexGreaterThanIndex:i]) {
		NSString *const entryPath = [_archive nameOfEntry:i cleanedUp:NO];
		if(_encodingError) return nil;
		if(!entryPath || (![entryPath hasPrefix:path] && ![path isEqualToString:@""])) continue;
		[indexes removeIndex:i];
		if([[entryPath lastPathComponent] hasPrefix:@"."]) continue;
		NSString *const subpath = [path stringByAppendingPathComponent:[[entryPath substringFromIndex:[path length]] AE_firstPathComponent]];
		if([path isEqualToString:entryPath]) continue;
		BOOL const isEntrylessFolder = ![subpath isEqualToString:entryPath];
		BOOL const isFile = !isEntrylessFolder && ![_archive entryIsDirectory:i];
		PGDisplayableIdentifier *const identifier = [[[self identifier] subidentifierWithIndex:(isEntrylessFolder ? NSNotFound : i)] displayableIdentifier];
		[identifier setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:(isEntrylessFolder ? NSFileTypeForHFSTypeCode(kGenericFolderIcon) : [_archive typeForEntry:i preferOSType:YES])]];
		[identifier setNaturalDisplayName:[subpath lastPathComponent]];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:parent document:nil identifier:identifier dataSource:self] autorelease];
		NSMutableDictionary *const info = [NSMutableDictionary dictionaryWithObjectsAndKeys:(isEntrylessFolder ? PGPseudoFileTypeForHFSTypeCode(kGenericFolderIcon) : [_archive OSTypeForEntry:i standardFormat:NO]), PGOSTypeKey, nil];
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
	[[self document] noteNodeThumbnailDidChange:[self node] children:YES];
}

#pragma mark -PGResourceAdapter

- (PGLoadPolicy)descendentLoadPolicy
{
	return PGLoadAll;
}
- (void)load
{
	if(!_archive) {
		XADError error;
		PGResourceIdentifier *const ident = [[self info] objectForKey:PGIdentifierKey];
		if([ident isFileIdentifier]) _archive = [[XADArchive alloc] initWithFile:[[ident URL] path] delegate:self error:&error]; // -data will return data for file URLs, but it's worth using -[XADArchive initWithFile:...].
		else {
			NSData *const data = [self data];
			if(!data) return [[self node] loadFinished];
			_archive = [[XADArchive alloc] initWithData:data error:&error];
			[_archive setDelegate:self];
		}
		if(!_archive || error != XADERR_OK || [_archive isCorrupted]) return [[self node] loadFinished];
	}
	NSNumber *const encodingNum = [[self info] objectForKey:PGStringEncodingKey];
	if(encodingNum) [_archive setNameEncoding:[encodingNum unsignedIntValue]];
	NSString *const root = [_archive commonTopDirectory];
	NSArray *const children = [self nodesUnderPath:(root ? root : @"") parentAdapter:self remainingIndexes:[NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_archive numberOfEntries])]];
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

#pragma mark -NSObject(PGNodeDataSource)

- (NSDate *)dateCreatedForNode:(PGNode *)sender
{
	unsigned const i = [[sender identifier] index];
	if(NSNotFound == i) return nil;
	struct xadFileInfo const *const info = [_archive xadFileInfoForEntry:i];
	xadUINT32 timestamp;
	if(info->xfi_Flags & XADFIF_NODATE || xadConvertDates([_archive xadMasterBase], XAD_DATEXADDATE, &info->xfi_Date, XAD_DATEUNIX, &timestamp, TAG_DONE) != XADERR_OK) return nil;
	return [NSDate dateWithTimeIntervalSince1970:timestamp];
}
- (NSNumber *)dataLengthForNode:(PGNode *)sender
{
	unsigned const i = [[sender identifier] index];
	return NSNotFound == i || [_archive entryIsDirectory:i] ? nil : [NSNumber numberWithUnsignedLongLong:[_archive xadFileInfoForEntry:i]->xfi_Size];
}
- (void)node:(PGNode *)sender
        willLoadWithInfo:(NSMutableDictionary *)info
{
	unsigned const i = [[sender identifier] index];
	if(NSNotFound == i) return;
	if([_archive entryIsArchive:i]) [info setObject:[NSNumber numberWithBool:YES] forKey:PGKnownToBeArchiveKey];
	if(![info objectForKey:PGOSTypeKey]) [info AE_setObject:[_archive OSTypeForEntry:i standardFormat:NO] forKey:PGOSTypeKey];
	if(![info objectForKey:PGExtensionKey]) [info AE_setObject:[[_archive nameOfEntry:i cleanedUp:NO] pathExtension] forKey:PGExtensionKey];
}
- (BOOL)node:(PGNode *)sender
        getData:(out NSData **)outData
        info:(NSDictionary *)info
        fast:(BOOL)flag
{
	unsigned const i = [[sender identifier] index];
	if(NSNotFound == i || flag) {
		if(outData) *outData = nil;
		return YES;
	}
	NSData *data = nil;
	@synchronized(_archive) {
		[_archive clearLastError];
		NSString *const pass = [info objectForKey:PGPasswordKey];
		if(pass) [_archive setPassword:pass];
		data = [_archive contentsOfEntry:i];
		switch([_archive lastError]) {
			case XADERR_OK:
			{
				if(_needsPassword) {
					_needsPassword = NO;
					[[PGArchiveAdapter PG_performOn:self allowOnce:YES withStorage:PGArchiveAdapterList] performSelectorOnMainThread:@selector(_updateThumbnailsOfChildren) withObject:nil waitUntilDone:NO];
				}
				break;
			}
			case XADERR_PASSWORD:
				_needsPassword = YES;
				[sender performSelectorOnMainThread:@selector(setError:) withObject:[NSError errorWithDomain:PGNodeErrorDomain code:PGPasswordError userInfo:nil] waitUntilDone:NO];
			default:
				return NO;
		}
	}
	if(outData) *outData = data;
	return YES;
}

#pragma mark -NSObject(XADArchiveDelegate)

- (NSStringEncoding)archive:(XADArchive *)archive
                    encodingForName:(const char *)bytes
                    guess:(NSStringEncoding)guess
                    confidence:(float)confidence
{
	if(confidence < 0.8 && !_encodingError) {
		_encodingError = YES;
		[[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGEncodingError userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSData dataWithBytes:bytes length:strlen(bytes)], PGUnencodedStringDataKey, [NSNumber numberWithUnsignedInt:guess], PGDefaultEncodingKey, nil]]];
		[[self node] loadFinished];
	}
	return guess;
}

#pragma mark -<PGResourceAdapting>

- (BOOL)canSaveData
{
	return YES;
}

@end

@implementation XADArchive(PGAdditions)

- (NSString *)OSTypeForEntry:(int)index
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
- (NSString *)typeForEntry:(int)index
              preferOSType:(BOOL)flag
{
	NSString *const osType = flag ? [self OSTypeForEntry:index standardFormat:YES] : nil;
	return osType ? osType : [[self nameOfEntry:index cleanedUp:NO] pathExtension];
}

@end
