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
{
	NSParameterAssert(path);
	NSParameterAssert(parent);
	NSParameterAssert(_archive);
	NSParameterAssert(_remainingIndexes);
	NSMutableArray *const children = [NSMutableArray array];
	int i = [_remainingIndexes firstIndex];
	for(; NSNotFound != i; i = [_remainingIndexes indexGreaterThanIndex:i]) {
		NSString *const entryPath = [_archive nameOfEntry:i];
		if([self needsEncoding]) return nil;
		if(!entryPath || (![entryPath hasPrefix:path] && ![path isEqualToString:@""])) continue;
		[_remainingIndexes removeIndex:i];
		if([[entryPath lastPathComponent] hasPrefix:@"."]) continue;
		NSString *const subpath = [path stringByAppendingPathComponent:[[entryPath substringFromIndex:[path length]] AE_firstPathComponent]];
		if([path isEqualToString:entryPath]) continue;
		BOOL const isEntrylessFolder = ![subpath isEqualToString:entryPath];
		BOOL const isFile = !isEntrylessFolder && ![_archive entryIsDirectory:i];
		PGResourceIdentifier *const identifier = [[self identifier] subidentifierWithIndex:(isEntrylessFolder ? NSNotFound : i)];
		[identifier setIcon:[[NSWorkspace sharedWorkspace] iconForFileType:(isFile ? [_archive typeForEntry:i preferHFSTypeCode:YES] : @"'fldr'")] notify:NO];
		[identifier setDisplayName:[subpath lastPathComponent] notify:NO];
		PGNode *const node = [[[PGNode alloc] initWithParentAdapter:parent document:nil identifier:identifier adapterClass:(isFile ? [PGArchiveResourceAdapter class] : [PGContainerAdapter class]) dataSource:self load:YES] autorelease];
		if(!isFile) {
			if(isEntrylessFolder) [_remainingIndexes addIndex:i]; // We ended up taking care of a folder in its path instead.
			PGContainerAdapter *const adapter = (id)[node resourceAdapter];
			[adapter setUnsortedChildren:[self nodesUnderPath:subpath parentAdapter:adapter] presortedOrder:PGUnsorted];
		}
		[children addObject:node];
	}
	return children;
}

#pragma mark XADArchiveDelegate Protocol

- (NSStringEncoding)archive:(XADArchive *)archive
                    encodingForName:(const char *)bytes
                    guess:(NSStringEncoding)guess
                    confidence:(float)confidence
{
	if(confidence >= 0.8) return guess;
	_guessedEncoding = guess;
	[self setNeedsEncoding:YES];
	return guess;
}

#pragma mark PGResourceAdapting Protocol

- (BOOL)isViewable
{
	return (!_hasRead && [self shouldRead:YES]) || [super isViewable];
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
	[self setNeedsEncoding:NO];
	[self readWithURLResponse:nil];
}

#pragma mark PGResourceAdapterDataSource Protocol

- (NSDate *)dateCreatedForResourceAdapter:(PGResourceAdapter *)sender
{
	unsigned const i = [[sender identifier] index];
	if(NSNotFound == i) return nil;
	struct xadFileInfo const *const info = [_archive xadFileInfoForEntry:i];
	xadUINT32 timestamp;
	if(info->xfi_Flags & XADFIF_NODATE || xadConvertDates([_archive xadMasterBase], XAD_DATEXADDATE, &info->xfi_Date, XAD_DATEUNIX, &timestamp, TAG_DONE) != XADERR_OK) return nil;
	return [NSDate dateWithTimeIntervalSince1970:timestamp];
}
- (NSNumber *)dataLengthForResourceAdapter:(PGResourceAdapter *)sender
{
	unsigned const i = [[sender identifier] index];
	return NSNotFound == i || [_archive entryIsDirectory:i] ? nil : [NSNumber numberWithUnsignedLongLong:[_archive xadFileInfoForEntry:i]->xfi_Size];
}
- (NSData *)dataForResourceAdapter:(PGResourceAdapter *)sender
{
	unsigned const i = [[sender identifier] index];
	if(NSNotFound == i) return nil;
	[_archive clearLastError];
	if([sender lastPassword]) [_archive setPassword:[sender lastPassword]];
	NSData *const data = [_archive contentsOfEntry:i];
	[sender setNeedsPassword:([_archive lastError] == XADERR_PASSWORD)];
	return data;
}

#pragma mark PGResourceAdapter

- (PGReadingPolicy)descendentReadingPolicy
{
	return MAX(PGReadAll, [self readingPolicy]);
}
- (void)readWithURLResponse:(NSURLResponse *)response
{
	if(!_archive) {
		XADError error;
		NSData *data;
		switch([self getData:&data]) {
		case PGWrongPassword: return;
		case PGDataUnavailable:
		{
			PGResourceIdentifier *const identifier = [self identifier];
			NSParameterAssert([identifier isFileIdentifier]);
			_archive = [[XADArchive alloc] initWithFile:[[identifier URLByFollowingAliases:YES] path] delegate:self error:&error];
			break;
		}
		case PGDataAvailable:
			_archive = [[XADArchive alloc] initWithData:data error:&error];
			[_archive setDelegate:self];
			break;
		}
		if(!_archive || error != XADERR_OK || [_archive isCorrupted]) return;
	}
	_remainingIndexes = [[[NSMutableIndexSet alloc] initWithIndexesInRange:NSMakeRange(0, [_archive numberOfEntries])] autorelease];
	NSString *const root = [_archive commonTopDirectory];
	NSArray *const children = [self nodesUnderPath:(root ? root : @"") parentAdapter:self];
	[self setUnsortedChildren:children presortedOrder:PGUnsorted];
	_remainingIndexes = nil;
	if(!children) return;
	_hasRead = YES;
	[self noteIsViewableDidChange];
	if([self shouldReadContents]) [self readContents];
}

#pragma mark NSObject

- (void)dealloc
{
	[_archive release];
	[super dealloc];
}

@end

@implementation PGArchiveResourceAdapter

#pragma mark PGResourceAdapter

- (Class)classWithURLResponse:(NSURLResponse *)response
{
	PGDocumentController *const d = [PGDocumentController sharedDocumentController];
	XADArchive *const archive = [(PGArchiveAdapter *)[self dataSource] archive];
	unsigned const index = [[self identifier] index];
	NSParameterAssert(NSNotFound != index);
	Class class = Nil;
	if([archive entryIsArchive:index]) class = [PGArchiveAdapter class];
	if(!class) class = [d resourceAdapterClassWhereAttribute:PGCFBundleTypeOSTypesKey matches:[archive HFSTypeCodeForEntry:index standardFormat:NO]];
	if(!class) class = [d resourceAdapterClassForExtension:[archive typeForEntry:index preferHFSTypeCode:NO]];
	if(!class) class = [super classWithURLResponse:response];
	return class;
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
