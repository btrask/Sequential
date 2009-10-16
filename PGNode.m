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
#import "PGNode.h"

// Models
#import "PGDocument.h"
#import "PGResourceAdapter.h"
#import "PGErrorAdapter.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Categories
#import "PGFoundationAdditions.h"

NSString *const PGNodeLoadingDidProgressNotification = @"PGNodeLoadingDidProgress";
NSString *const PGNodeReadyForViewingNotification    = @"PGNodeReadyForViewing";

NSString *const PGImageRepKey       = @"PGImageRep";
NSString *const PGErrorKey          = @"PGError";

NSString *const PGNodeErrorDomain        = @"PGNodeError";
NSString *const PGUnencodedStringDataKey = @"PGUnencodedStringData";
NSString *const PGDefaultEncodingKey     = @"PGDefaultEncoding";

enum {
	PGNodeNothing = 0,
	PGNodeLoading = 1 << 0,
	PGNodeReading = 1 << 1,
	PGNodeLoadingOrReading = PGNodeLoading | PGNodeReading
}; // PGNodeStatus.

@interface PGNode(Private)

- (void)_setResourceAdapter:(PGResourceAdapter *)adapter;
- (NSArray *)_standardizedInfo:(id)info;
- (NSDictionary *)_standardizedInfoDictionary:(NSDictionary *)info;
- (void)_updateMenuItem;
- (void)_updateFileAttributes;
- (void)_setValue:(id)value forSortOrder:(PGSortOrder)order;

@end

@implementation PGNode

#pragma mark +PGNode

+ (NSArray *)pasteboardTypes
{
	return [NSArray arrayWithObjects:NSStringPboardType, NSRTFDPboardType, NSFileContentsPboardType, nil];
}

#pragma mark +NSObject

+ (void)initialize
{
	srandom(time(NULL)); // Used by our shuffle sort.
}

#pragma mark -PGNode

- (id)initWithParentAdapter:(PGContainerAdapter *)parent document:(PGDocument *)doc identifier:(PGDisplayableIdentifier *)ident dataSource:(NSObject<PGNodeDataSource> *)dataSource
{
	if(!(self = [super init])) return nil;
	NSParameterAssert(!parent != !doc);
	if(!ident) {
		[self release];
		return nil;
	}
	_parentAdapter = parent;
	_document = doc;
	_identifier = [ident retain];
	_dataSource = dataSource;
	PGResourceAdapter *const adapter = [[[PGResourceAdapter alloc] init] autorelease];
	_adapters = [[NSMutableArray alloc] initWithObjects:adapter, nil];
	[self _setResourceAdapter:adapter];
	_menuItem = [[NSMenuItem alloc] init];
	[_menuItem setRepresentedObject:[NSValue valueWithNonretainedObject:self]];
	[_menuItem setAction:@selector(jumpToPage:)];
	_allowMenuItemUpdates = YES;
	[self _updateMenuItem];
	[_identifier PG_addObserver:self selector:@selector(identifierIconDidChange:) name:PGDisplayableIdentifierIconDidChangeNotification];
	[_identifier PG_addObserver:self selector:@selector(identifierDisplayNameDidChange:) name:PGDisplayableIdentifierDisplayNameDidChangeNotification];
	return self;
}

#pragma mark -

- (NSObject<PGNodeDataSource> *)dataSource
{
	return _dataSource;
}
- (PGResourceAdapter *)resourceAdapter
{
	return [[_adapter retain] autorelease];
}
- (PGLoadPolicy)ancestorLoadPolicy
{
	PGContainerAdapter *const p = [self parentAdapter];
	return p ? MAX([[p node] ancestorLoadPolicy], [p descendentLoadPolicy]) : PGLoadToMaxDepth;
}
- (NSError *)error
{
	return [[_error retain] autorelease];
}
- (void)setError:(NSError *)error
{
	if(PGNodeNothing == _status) return;
	if(!_error) {
		_error = [error copy];
		_errorPhase = _status;
	}
	if(PGNodeLoading & _status && [_adapters count] > 1) {
		(void)[[[_adapters lastObject] retain] autorelease];
		if([_adapter shouldFallbackOnError]) [_adapters removeLastObject];
		else [_adapters removeObjectsInRange:NSMakeRange(1, [_adapters count] - 1)];
		[self _setResourceAdapter:[_adapters lastObject]];
		[_adapter fallbackLoad];
	}
}
- (NSImage *)thumbnail
{
	return PGNodeLoading & _status ? nil : [[self resourceAdapter] thumbnail];
}
- (BOOL)isViewable
{
	return _viewable;
}
- (NSUInteger)depth
{
	return [self parentNode] ? [[self parentNode] depth] + 1 : 0;
}
- (PGNode *)viewableAncestor
{
	return _viewable ? self : [[self parentNode] viewableAncestor];
}
- (NSMenuItem *)menuItem
{
	return [[_menuItem retain] autorelease];
}
- (BOOL)canBookmark
{
	return [self isViewable] && [[self identifier] hasTarget];
}
- (PGBookmark *)bookmark
{
	return [[[PGBookmark alloc] initWithNode:self] autorelease];
}

#pragma mark -

- (NSDate *)dateModified
{
	return _dateModified ? [[_dateModified retain] autorelease] : [NSDate distantPast];
}
- (NSDate *)dateCreated
{
	return _dateCreated ? [[_dateCreated retain] autorelease] : [NSDate distantPast];
}
- (NSNumber *)dataLength
{
	return _dataLength ? [[_dataLength retain] autorelease] : [NSNumber numberWithUnsignedInteger:0];
}
- (NSString *)kind
{
	return _kind ? [[_kind retain] autorelease] : @"";
}

#pragma mark -

- (NSData *)dataWithInfo:(NSDictionary *)info fast:(BOOL)flag
{
	NSData *data = [[[info objectForKey:PGDataKey] retain] autorelease];
	if(data) return data;
	@synchronized(self) {
		if([self dataSource] && ![[self dataSource] node:self getData:&data info:info fast:flag]) return nil;
	}
	if(data) return data;
	PGResourceIdentifier *const identifier = [info objectForKey:PGIdentifierKey];
	if([identifier isFileIdentifier]) {
		NSURL *const URL = [identifier URLByFollowingAliases:YES];
		if(URL) data = [NSData dataWithContentsOfURL:URL options:NSMappedRead | NSUncachedRead error:NULL];
	}
	return data;
}
- (BOOL)canGetDataWithInfo:(NSDictionary *)info
{
	return [self dataSource] || [info objectForKey:PGFourCCDataKey] || [info objectForKey:PGDataKey] || [[info objectForKey:PGIdentifierKey] isFileIdentifier];
}

#pragma mark -

- (BOOL)shouldLoadAdapterClass:(Class)aClass
{
	if([aClass alwaysLoads]) return YES;
	switch([self ancestorLoadPolicy]) {
		case PGLoadToMaxDepth: return [self depth] <= [[[NSUserDefaults standardUserDefaults] objectForKey:PGMaxDepthKey] unsignedIntegerValue];
		case PGLoadAll: return YES;
		default: return NO;
	}
}
- (void)startLoadWithInfo:(id)info
{
	NSParameterAssert(!(PGNodeLoading & _status));
	_status |= PGNodeLoading;
	[_error release];
	_error = nil;
	[self noteIsViewableDidChange];
	[_adapters autorelease];
	_adapters = [[PGResourceAdapter adapterClassesInstantiated:YES forNode:self withInfoDicts:[self _standardizedInfo:info]] mutableCopy];
	[_adapters insertObject:[[[PGErrorAdapter alloc] init] autorelease] atIndex:0];
	[self _setResourceAdapter:[_adapters lastObject]];
	[_adapter loadIfNecessary];
}
- (void)continueLoadWithInfo:(id)info
{
	NSParameterAssert(PGNodeLoading & _status);
	NSParameterAssert(info && [info count]); // Otherwise nothing has changed.
	NSArray *const newAdapters = [PGResourceAdapter adapterClassesInstantiated:YES forNode:self withInfoDicts:[self _standardizedInfo:info]];
	if(![newAdapters count]) return [_adapter fallbackLoad];
	[_adapters addObjectsFromArray:newAdapters];
	NSParameterAssert([_adapters count]);
	[self _setResourceAdapter:[_adapters lastObject]];
	[_adapter loadIfNecessary];
}
- (void)loadFinished
{
	NSParameterAssert(PGNodeLoading & _status);
	_status &= ~PGNodeLoading;
	[self noteIsViewableDidChange];
	[self _updateFileAttributes];
	[self readIfNecessary];
	[[self document] noteNodeThumbnailDidChange:self recursively:NO];
}

#pragma mark -

- (void)becomeViewed
{
	[[self parentLoad] prioritizeSubload:self];
	if(PGNodeReading & _status) return;
	_status |= PGNodeReading;
	[self readIfNecessary];
}
- (void)readIfNecessary
{
	if((PGNodeLoadingOrReading & _status) == PGNodeReading) [_adapter read];
}
- (void)readFinishedWithImageRep:(NSImageRep *)aRep error:(NSError *)error
{
	NSParameterAssert((PGNodeLoadingOrReading & _status) == PGNodeReading);
	_status &= ~PGNodeReading;
	NSMutableDictionary *const dict = [NSMutableDictionary dictionary];
	[dict PG_setObject:aRep forKey:PGImageRepKey];
	if(error) [dict setObject:error forKey:PGErrorKey];
	else {
		[dict PG_setObject:_error forKey:PGErrorKey];
		[_error release];
		_error = nil;
	}
	[self PG_postNotificationName:PGNodeReadyForViewingNotification userInfo:dict];
}

#pragma mark -

- (void)removeFromDocument
{
	if([[self document] node] == self) [[self document] close];
	else [[self parentAdapter] removeChild:self];
}
- (void)detachFromTree
{
	@synchronized(self) {
		_parentAdapter = nil;
		_document = nil;
		_dataSource = nil;
	}
}
- (NSComparisonResult)compare:(PGNode *)node
{
	NSParameterAssert(node);
	NSParameterAssert([self document]);
	PGSortOrder const o = [[self document] sortOrder];
	NSInteger const d = PGSortDescendingMask & o ? -1 : 1;
	NSComparisonResult r = NSOrderedSame;
	switch(PGSortOrderMask & o) {
		case PGUnsorted:           return NSOrderedSame;
		case PGSortByDateModified: r = [[self dateModified] compare:[node dateModified]]; break;
		case PGSortByDateCreated:  r = [[self dateCreated] compare:[node dateCreated]]; break;
		case PGSortBySize:         r = [[self dataLength] compare:[node dataLength]]; break;
		case PGSortByKind:         r = [[self kind] compare:[node kind]]; break;
		case PGSortShuffle:        return random() & 1 ? NSOrderedAscending : NSOrderedDescending;
	}
	return (NSOrderedSame == r ? [[[self identifier] displayName] PG_localizedCaseInsensitiveNumericCompare:[[node identifier] displayName]] : r) * d; // If the actual sort order doesn't produce a distinct ordering, then sort by name too.
}
- (BOOL)writeToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
	BOOL wrote = NO;
	if([types containsObject:NSStringPboardType]) {
		if(pboard) {
			[pboard addTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
			[pboard setString:[[self identifier] displayName] forType:NSStringPboardType];
		}
		wrote = YES;
	}
	NSData *const data = [self canGetData] ? [self data] : nil;
	if(data) {
		if([types containsObject:NSRTFDPboardType]) {
			[pboard addTypes:[NSArray arrayWithObject:NSRTFDPboardType] owner:nil];
			NSFileWrapper *const wrapper = [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
			[wrapper setPreferredFilename:[[self identifier] displayName]];
			NSAttributedString *const string = [NSAttributedString attributedStringWithAttachment:[[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease]];
			[pboard setData:[string RTFDFromRange:NSMakeRange(0, [string length]) documentAttributes:nil] forType:NSRTFDPboardType];
			wrote = YES;
		}
		if([types containsObject:NSFileContentsPboardType]) {
			if(pboard) {
				[pboard addTypes:[NSArray arrayWithObject:NSFileContentsPboardType] owner:nil];
				[pboard setData:data forType:NSFileContentsPboardType];
			}
			wrote = YES;
		}
	}
	return wrote;
}

#pragma mark -

- (void)identifierIconDidChange:(NSNotification *)aNotif
{
	[self _updateMenuItem];
}
- (void)identifierDisplayNameDidChange:(NSNotification *)aNotif
{
	[self _updateMenuItem];
	if([[self document] isCurrentSortOrder:PGSortByName]) [[self parentAdapter] noteChildValueForCurrentSortOrderDidChange:self];
	[[self document] noteNodeDisplayNameDidChange:self];
}

#pragma mark -PGNode(Private)

- (void)_setResourceAdapter:(PGResourceAdapter *)adapter
{
	if(adapter == _adapter) return;
	if([_adapter node] == self) [_adapter setNode:nil];
	_adapter = adapter;
	[_adapter setNode:self];
	[self _updateMenuItem];
}
- (NSArray *)_standardizedInfo:(id)info
{
	NSMutableArray *const results = [NSMutableArray array];
	for(NSDictionary *const dict in [info PG_asArray]) [results addObject:[self _standardizedInfoDictionary:dict]];
	if(![results count]) [results addObject:[self _standardizedInfoDictionary:nil]];
	return results;
}
- (NSDictionary *)_standardizedInfoDictionary:(NSDictionary *)info
{
	NSMutableDictionary *const mutableInfo = info ? [[info mutableCopy] autorelease] : [NSMutableDictionary dictionary];
	[[self dataSource] node:self willLoadWithInfo:mutableInfo];
	NSURLResponse *const response = [info objectForKey:PGURLResponseKey];
	if(![mutableInfo objectForKey:PGIdentifierKey]) {
		NSURL *const responseURL = [response URL];
		[mutableInfo PG_setObject:responseURL ? [responseURL PG_resourceIdentifier] : [self identifier] forKey:PGIdentifierKey];
	}
	if(![mutableInfo objectForKey:PGMIMETypeKey]) [mutableInfo PG_setObject:[response MIMEType] forKey:PGMIMETypeKey];
	if(![mutableInfo objectForKey:PGExtensionKey]) [mutableInfo PG_setObject:[[[[mutableInfo objectForKey:PGIdentifierKey] URL] path] pathExtension] forKey:PGExtensionKey];
	if(![mutableInfo objectForKey:PGFourCCDataKey]) {
		NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
		NSData *const data = [self dataWithInfo:mutableInfo fast:YES];
		if(data && [data length] >= 4) [mutableInfo PG_setObject:[data subdataWithRange:NSMakeRange(0, 4)] forKey:PGFourCCDataKey];
		[pool release]; // Dispose of the data ASAP.
	}
	[mutableInfo setObject:[NSNumber numberWithInteger:[self canGetDataWithInfo:mutableInfo] ? PGExists : PGDoesNotExist] forKey:PGDataExistenceKey];
	return mutableInfo;
}
- (void)_updateMenuItem
{
	if(!_allowMenuItemUpdates) return;
	NSMutableAttributedString *const label = [[[[self identifier] attributedStringWithAncestory:NO] mutableCopy] autorelease];
	NSString *info = nil;
	NSDate *date = nil;
	switch(PGSortOrderMask & [[self document] sortOrder]) {
		case PGSortByDateModified: date = _dateModified; break;
		case PGSortByDateCreated:  date = _dateCreated; break;
		case PGSortBySize: info = [_dataLength PG_localizedStringAsBytes]; break;
		case PGSortByKind: info = _kind; break;
	}
	if(date && !info) info = [date PG_localizedStringWithDateStyle:kCFDateFormatterShortStyle timeStyle:kCFDateFormatterShortStyle];
	if(info) [label appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" (%@)", info] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor grayColor], NSForegroundColorAttributeName, [NSFont boldSystemFontOfSize:12], NSFontAttributeName, nil]] autorelease]];
	[_menuItem setAttributedTitle:label];
}
- (void)_updateFileAttributes
{
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	NSURL *const URL = [[self identifier] URL];
	if([URL isFileURL]) [attributes addEntriesFromDictionary:[[NSFileManager defaultManager] attributesOfItemAtPath:[URL path] error:NULL]];
	[attributes addEntriesFromDictionary:[[self dataSource] fileAttributesForNode:self]];
	if(PGEqualObjects([attributes fileType], NSFileTypeDirectory)) [attributes removeObjectForKey:NSFileSize];
	else if(![attributes objectForKey:NSFileSize]) {
		NSData *const data = [self data];
		if(data) [attributes setObject:[NSNumber numberWithUnsignedInteger:[data length]] forKey:NSFileSize];
	}
	[self _setValue:[attributes fileModificationDate] forSortOrder:PGSortByDateModified];
	[self _setValue:[attributes fileCreationDate] forSortOrder:PGSortByDateCreated];
	[self _setValue:[attributes objectForKey:NSFileSize] forSortOrder:PGSortBySize];

	NSDictionary *const info = [self info];
	NSString *kind = nil;
	// Try every possible method to get a decent string. When a method succeeds, it overwrites previous attempts.
	if(noErr == LSCopyKindStringForMIMEType((CFStringRef)[info objectForKey:PGMIMETypeKey], (CFStringRef *)&kind)) [kind autorelease]; // For some reason this produces extremely ugly strings, like "TextEdit.app Document".
	if(noErr == LSCopyKindStringForTypeInfo(kLSUnknownType, kLSUnknownCreator, (CFStringRef)[info objectForKey:PGExtensionKey], (CFStringRef *)&kind)) [kind autorelease];
	NSString *const workspaceKind = [[NSWorkspace sharedWorkspace] localizedDescriptionForType:[(NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (CFStringRef)[info objectForKey:PGMIMETypeKey], NULL) autorelease]]; // This produces ugly strings too ("Portable Network Graphics image"), but they still aren't nearly as bad.
	if(workspaceKind) kind = workspaceKind;
	if(noErr == LSCopyKindStringForTypeInfo(PGOSTypeFromString([info objectForKey:PGOSTypeKey]), kLSUnknownCreator, NULL, (CFStringRef *)&kind)) [kind autorelease];
	if(noErr == LSCopyKindStringForURL((CFURLRef)URL, (CFStringRef *)&kind)) [kind autorelease];
	[self _setValue:kind forSortOrder:PGSortByKind];
}
- (void)_setValue:(id)value forSortOrder:(PGSortOrder)order
{
	id *attributePtr = NULL;
	switch(PGSortOrderMask & order) {
		case PGSortByDateModified: attributePtr = &_dateModified; break;
		case PGSortByDateCreated:  attributePtr = &_dateCreated; break;
		case PGSortBySize:         attributePtr = &_dataLength; break;
		case PGSortByKind:         attributePtr = &_kind; break;
	}
	if(PGEqualObjects(value, *attributePtr)) return;
	[*attributePtr release];
	*attributePtr = [value retain];
	if(![[self document] isCurrentSortOrder:order]) return;
	[[self parentAdapter] noteChildValueForCurrentSortOrderDidChange:self];
	[self _updateMenuItem];
}

#pragma mark -NSObject

- (void)dealloc
{
	// Using our generic -PG_removeObserver is about twice as slow as removing the observer for the specific objects we care about. When closing huge folders of thousands of files, this makes a big difference. Even now it's still the slowest part.
	[_identifier PG_removeObserver:self name:PGDisplayableIdentifierIconDidChangeNotification];
	[_identifier PG_removeObserver:self name:PGDisplayableIdentifierDisplayNameDidChangeNotification];
	[_adapter setNode:nil]; // PGGenericImageAdapter gets retained while it's loading in another thread, and when it finishes it might expect us to still be around.
	[_identifier release];
	[_menuItem release];
	[_adapters release];
	[_error release];
	[_dateModified release];
	[_dateCreated release];
	[_dataLength release];
	[_kind release];
	[super dealloc];
}

#pragma mark -

- (IMP)methodForSelector:(SEL)sel
{
	return [super respondsToSelector:sel] ? [super methodForSelector:sel] : [_adapter methodForSelector:sel];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	return [_adapter methodSignatureForSelector:sel];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
	[invocation invokeWithTarget:_adapter];
}

#pragma mark -NSObject(NSObject)

- (NSUInteger)hash
{
	return [[self class] hash] ^ [[self identifier] hash];
}
- (BOOL)isEqual:(id)anObject
{
	return [anObject isMemberOfClass:[self class]] && PGEqualObjects([self identifier], [anObject identifier]);
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@(%@) %p: %@>", [self class], [_adapter class], self, [self identifier]];
}

#pragma mark -

- (BOOL)respondsToSelector:(SEL)sel
{
	return [super respondsToSelector:sel] ? YES : [_adapter respondsToSelector:sel];
}

#pragma mark -<PGResourceAdapting>

- (PGNode *)parentNode
{
	return [_parentAdapter node];
}
- (PGContainerAdapter *)parentAdapter
{
	return _parentAdapter;
}
- (PGNode *)rootNode
{
	return [self parentNode] ? [[self parentNode] rootNode] : self;
}
- (PGDocument *)document
{
	return _document ? _document : [_parentAdapter document];
}

#pragma mark -

- (PGDisplayableIdentifier *)identifier
{
	return [[_identifier retain] autorelease];
}

#pragma mark -

- (void)noteFileEventDidOccurDirect:(BOOL)flag
{
	[[self identifier] updateNaturalDisplayName];
	[self _updateFileAttributes];
	[_adapter noteFileEventDidOccurDirect:flag];
}
- (void)noteSortOrderDidChange
{
	[self _updateMenuItem];
	[_adapter noteSortOrderDidChange];
}
- (void)noteIsViewableDidChange
{
	BOOL const showsLoadingIndicator = !!(PGNodeLoading & _status);
	BOOL const showsError = _error && (PGNodeLoadingOrReading & _errorPhase) == PGNodeReading;
	BOOL const viewable = showsLoadingIndicator || showsError || [_adapter adapterIsViewable];
	if(viewable == _viewable) return;
	_viewable = viewable;
	[[self document] noteNodeIsViewableDidChange:self];
}

@end

@implementation NSObject(PGNodeDataSource)

- (NSDictionary *)fileAttributesForNode:(PGNode *)node
{
	return nil;
}
- (void)node:(PGNode *)sender willLoadWithInfo:(NSMutableDictionary *)info {}
- (BOOL)node:(PGNode *)sender getData:(out NSData **)outData info:(NSDictionary *)info fast:(BOOL)flag
{
	if(outData) *outData = nil;
	return YES;
}

@end
