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
#import "PGArchiveAdapter.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSStringAdditions.h"

@interface XADArchive (PGAdditions)

- (NSString *)HFSTypeCodeForEntry:(int)index standardFormat:(BOOL)flag;
- (NSString *)typeForEntry:(int)index preferHFSTypeCode:(BOOL)flag;

@end

@implementation PGArchiveAdapter

#pragma mark Instance Methods

- (XADArchive *)archive
{
	return [[_archive retain] autorelease];
}
- (void)setIsSubarchive:(BOOL)flag
{
	_isSubarchive = flag;
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
		NSString *const entryPath = [_archive nameOfEntry:i];
		if(UINT_MAX != _guessedEncoding) return nil;
		if(!entryPath || (![entryPath hasPrefix:path] && ![path isEqualToString:@""])) continue;
		[indexes removeIndex:i];
		if([[entryPath lastPathComponent] hasPrefix:@"."]) continue;
		NSString *const subpath = [path stringByAppendingPathComponent:[[entryPath substringFromIndex:[path length]] AE_firstPathComponent]];
		if([path isEqualToString:entryPath]) continue;
		BOOL const isEntrylessFolder = ![subpath isEqualToString:entryPath];
		BOOL const isFile = !isEntrylessFolder && ![_archive entryIsDirectory:i];
		PGResourceIdentifier *const identifier = [[self identifier] subidentifierWithIndex:(isEntrylessFolder ? NSNotFound : i)];
		[identifier setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:(isFile ? [_archive typeForEntry:i preferHFSTypeCode:YES] : NSFileTypeForHFSTypeCode('fldr'))] notify:NO];
		[identifier setCustomDisplayName:[subpath lastPathComponent] notify:NO];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:parent document:nil identifier:identifier] autorelease];
		[node setDataSource:self];
		if(isFile) [node loadWithInfo:nil];
		else {
			[node setResourceAdapterClass:[PGContainerAdapter class]];
			if(isEntrylessFolder) [indexes addIndex:i]; // We ended up taking care of a folder in its path instead.
			PGContainerAdapter *const adapter = (id)[node resourceAdapter];
			[adapter setUnsortedChildren:[self nodesUnderPath:subpath parentAdapter:adapter remainingIndexes:indexes] presortedOrder:PGUnsorted];
		}
		if(node) [children addObject:node];
	}
	return children;
}

#pragma mark XADArchiveDelegate Protocol

- (NSStringEncoding)archive:(XADArchive *)archive
                    encodingForName:(const char *)bytes
                    guess:(NSStringEncoding)guess
                    confidence:(float)confidence
{
	if(confidence < 0.8 && UINT_MAX == _guessedEncoding) {
		_guessedEncoding = guess;
		[[self node] setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGEncodingError userInfo:nil]];
		[[self node] loadFinished];
	}
	return guess;
}

#pragma mark PGResourceAdapting Protocol

- (BOOL)canExtractData
{
	return YES;
}
- (char const *)unencodedSampleString
{
	return [_archive numberOfEntries] ? [_archive _undecodedNameOfEntry:0] : NULL;
}
- (NSStringEncoding)defaultEncoding
{
	return _guessedEncoding;
}
- (void)setEncoding:(NSStringEncoding)encoding
{
	[_archive setNameEncoding:encoding];
	_guessedEncoding = UINT_MAX;
	[[self node] loadWithInfo:nil];
}

#pragma mark PGNodeDataSource Protocol

- (Class)classForNode:(PGNode *)sender
{
	PGDocumentController *const d = [PGDocumentController sharedDocumentController];
	unsigned const index = [[sender identifier] index];
	NSParameterAssert(NSNotFound != index);
	Class class = Nil;
	if([_archive entryIsArchive:index]) class = [PGArchiveAdapter class];
	if(!class) class = [d resourceAdapterClassWhereAttribute:PGCFBundleTypeOSTypesKey matches:[_archive HFSTypeCodeForEntry:index standardFormat:NO]];
	if(!class) class = [d resourceAdapterClassForExtension:[_archive typeForEntry:index preferHFSTypeCode:NO]];
	return class;
}
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
- (BOOL)node:(PGNode *)sender
        getData:(out NSData **)outData
{
	unsigned const i = [[sender identifier] index];
	if(NSNotFound == i) return NO;
	[_archive clearLastError];
	if([sender password]) [_archive setPassword:[sender password]];
	NSData *const data = [_archive contentsOfEntry:i];
	if([_archive lastError] == XADERR_PASSWORD) {
		[sender setError:[NSError errorWithDomain:PGNodeErrorDomain code:PGPasswordError userInfo:nil]];
		return NO;
	}
	if(outData) *outData = data;
	return YES;
}

#pragma mark PGResourceAdapter

- (PGLoadPolicy)descendentLoadPolicy
{
	return PGLoadAll;
}
- (void)loadWithInfo:(NSDictionary *)info
{
	if(!_archive) {
		XADError error;
		PGResourceIdentifier *const identifier = [self identifier];
		if([identifier isFileIdentifier]) _archive = [[XADArchive alloc] initWithFile:[[identifier URLByFollowingAliases:YES] path] delegate:self error:&error]; // -getData: will return data for file identifiers, but it's worth using -[XADArchive initWithFile:...].
		else {
			NSData *const data = [self data];
			if(!data) return [[self node] loadFinished];
			_archive = [[XADArchive alloc] initWithData:data error:&error];
			[_archive setDelegate:self];
		}
		if(!_archive || error != XADERR_OK || [_archive isCorrupted]) return [[self node] loadFinished];
	}
	NSString *const root = [_archive commonTopDirectory];
	_guessedEncoding = UINT_MAX;
	NSArray *const children = [self nodesUnderPath:(root ? root : @"") parentAdapter:self remainingIndexes:[NSMutableIndexSet indexSetWithIndexesInRange:NSMakeRange(0, [_archive numberOfEntries])]];
	[self setUnsortedChildren:children presortedOrder:PGUnsorted];
	if(UINT_MAX == _guessedEncoding) [[self node] loadFinished];
}

#pragma mark NSObject

- (void)dealloc
{
	[_archive release];
	[super dealloc];
}

@end

@implementation XADArchive (PGAdditions)

- (NSString *)HFSTypeCodeForEntry:(int)index
              standardFormat:(BOOL)flag
{
	OSType value;
	if([self entryIsDirectory:index]) value = 'fldr';
	else {
		NSNumber *const typeCode = [[self attributesOfEntry:index] objectForKey:NSFileHFSTypeCode];
		if(!typeCode) return nil;
		value = [typeCode unsignedLongValue];
	}
	return flag ? NSFileTypeForHFSTypeCode(value) : PGPseudoFileTypeForHFSTypeCode(value);
}
- (NSString *)typeForEntry:(int)index
              preferHFSTypeCode:(BOOL)flag
{
	NSString *const HFSType = flag ? [self HFSTypeCodeForEntry:index standardFormat:YES] : nil;
	return HFSType ? HFSType : [[self nameOfEntry:index] pathExtension];
}

@end
