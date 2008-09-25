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
#import "PGNode.h"

// Models
#import "PGDocument.h"
#import "PGResourceAdapter.h"
#import "PGWebAdapter.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Controllers
#import "PGDocumentController.h"

// Categories
#import "NSDateAdditions.h"
#import "NSMutableDictionaryAdditions.h"
#import "NSNumberAdditions.h"
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGNodeLoadingDidProgressNotification = @"PGNodeLoadingDidProgress";
NSString *const PGNodeReadyForViewingNotification    = @"PGNodeReadyForViewing";

NSString *const PGImageRepKey = @"PGImageRep";
NSString *const PGErrorKey = @"PGError";

NSString *const PGNodeErrorDomain = @"PGNodeError";

enum {
	PGNodeNothing = 0,
	PGNodeLoading = 1 << 0,
	PGNodeReading = 1 << 1,
	PGNodeLoadingWillRead = PGNodeLoading | PGNodeReading
};

@interface PGNode (Private)

- (void)_updateMenuItem;
- (void)_updateFileAttributes;

@end

@implementation PGNode

#pragma mark NSObject

+ (void)initialize
{
	srandom(time(NULL)); // Used by our shuffle sort.
}

#pragma mark Instance Methods

- (id)initWithParentAdapter:(PGContainerAdapter *)parent
      document:(PGDocument *)doc
      identifier:(PGResourceIdentifier *)ident
{
	if(!ident) {
		[self release];
		return nil;
	}
	NSParameterAssert(parent || doc);
	if((self = [super init])) {
		_parentAdapter = parent;
		_document = doc ? doc : [parent document];
		_identifier = [ident retain];
		[_identifier AE_addObserver:self selector:@selector(identifierDidChange:) name:PGResourceIdentifierDidChangeNotification];
		[self setResourceAdapterClass:[PGResourceAdapter class]];
		_menuItem = [[NSMenuItem alloc] init];
		[_menuItem setRepresentedObject:[NSValue valueWithNonretainedObject:self]];
		[_menuItem setAction:@selector(jumpToPage:)];
		_allowMenuItemUpdates = YES;
		[self _updateMenuItem];
	}
	return self;
}

#pragma mark -

- (id)dataSource
{
	return _dataSource;
}
- (void)setDataSource:(id)anObject
{
	if(anObject == _dataSource) return;
	_dataSource = anObject;
}
- (NSData *)dataWithInfo:(NSDictionary *)info
{
	NSData *data = [[[info objectForKey:PGURLDataKey] retain] autorelease];
	if(data) return data;
	if([self dataSource] && ![[self dataSource] node:self getData:&data]) return nil;
	if(data) return data;
	PGResourceIdentifier *const identifier = [self identifier];
	if([identifier isFileIdentifier]) data = [NSData dataWithContentsOfMappedFile:[[identifier URLByFollowingAliases:YES] path]];
	return data;
}

#pragma mark -

- (PGResourceAdapter *)resourceAdapter
{
	return [[_resourceAdapter retain] autorelease];
}
- (void)setResourceAdapterClass:(Class)aClass
{
	if(!aClass || [_resourceAdapter isKindOfClass:aClass]) return;
	if([_resourceAdapter node] == self) [_resourceAdapter setNode:nil];
	[_resourceAdapter autorelease]; // Don't let it get deallocated immediately.
	_resourceAdapter = [[aClass alloc] init];
	[_resourceAdapter setNode:self];
	[self _updateMenuItem];
}
- (Class)classWithInfo:(NSMutableDictionary *)info
{
	Class class = [[self dataSource] classForNode:self];
	if(class) return class;
	NSURLResponse *const response = [info objectForKey:PGURLResponseKey];
	if([response respondsToSelector:@selector(statusCode)]) {
		int const status = [(NSHTTPURLResponse *)response statusCode];
		if(status < 200 || status >= 300) return Nil;
	}
	PGDocumentController *const d = [PGDocumentController sharedDocumentController];
	NSURL *URL = [info objectForKey:PGURLKey];
	if(!URL) URL = [[self identifier] URLByFollowingAliases:YES];
	NSData *const data = [self dataWithInfo:info];
	if(data) {
		if([data length] < 4) return Nil;
		class = [d resourceAdapterClassWhereAttribute:PGBundleTypeFourCCKey matches:[data subdataWithRange:NSMakeRange(0, 4)]];
	} else if(URL) {
		if(![URL isFileURL]) return [PGWebAdapter class];
		BOOL isDir;
		if(![[NSFileManager defaultManager] fileExistsAtPath:[URL path] isDirectory:&isDir]) return Nil;
		if(isDir) return [d resourceAdapterClassWhereAttribute:PGLSTypeIsPackageKey matches:[NSNumber numberWithBool:YES]];
	}
	NSString *const MIMEType = [info objectForKey:PGMIMETypeKey];
	if(!class && MIMEType) class = [d resourceAdapterClassWhereAttribute:PGCFBundleTypeMIMETypesKey matches:MIMEType];
	if(!class && URL) class = [d resourceAdapterClassForExtension:[[URL path] pathExtension]];
	if(!class) class = [PGResourceAdapter class];
	return class;
}
- (PGLoadPolicy)ancestorLoadPolicy
{
	PGContainerAdapter *const p = [self parentAdapter];
	return p ? MAX([[p node] ancestorLoadPolicy], [p descendentLoadPolicy]) : PGLoadToMaxDepth;
}
- (BOOL)shouldLoadAdapterClass:(Class)aClass
{
	if([aClass alwaysLoads]) return YES;
	switch([self ancestorLoadPolicy]) {
		case PGLoadToMaxDepth: return [self depth] <= [[[NSUserDefaults standardUserDefaults] objectForKey:PGMaxDepthKey] unsignedIntValue];
		case PGLoadAll: return YES;
		default: return NO;
	}
}
- (void)loadFinished
{
	NSParameterAssert(PGNodeLoading & _status);
	_status = ~PGNodeLoading & _status;
	[self noteIsViewableDidChange];
	[self _updateFileAttributes];
	[self readIfNecessary];
}
- (void)becomeViewed
{
	if(PGNodeReading & _status) return;
	_status |= PGNodeReading;
	[self readIfNecessary];
}
- (void)readIfNecessary
{
	if(PGNodeReading != _status) return;
	if(_error && PGNodeLoading & _errorPhase) [self readFinishedWithImageRep:nil];
	else [_resourceAdapter read];
}
- (void)readFinishedWithImageRep:(NSImageRep *)aRep
{
	NSParameterAssert(PGNodeReading == _status);
	_status = ~PGNodeReading & _status;
	NSMutableDictionary *const dict = [NSMutableDictionary dictionary];
	if(aRep) [dict setObject:aRep forKey:PGImageRepKey];
	if(_error) [dict setObject:_error forKey:PGErrorKey];
	if(PGNodeReading == _errorPhase) {
		[_error release];
		_error = nil;
	}
	[self AE_postNotificationName:PGNodeReadyForViewingNotification userInfo:dict];
}

#pragma mark -

- (void)setError:(NSError *)error
{
	if(_error || PGNodeNothing == _status) return;
	_error = [error copy];
	_errorPhase = _status;
}
- (NSString *)password
{
	return [[_password retain] autorelease];
}
- (void)setPassword:(NSString *)password
{
	if(password == _password) return;
	[_password release];
	_password = [password copy];
}

#pragma mark -

- (BOOL)isViewable
{
	return _viewable;
}
- (unsigned)depth
{
	return [self parentNode] ? [[self parentNode] depth] + 1 : 0;
}
- (BOOL)isRooted
{
	return [[self document] node] == self || ([[[self parentAdapter] unsortedChildren] indexOfObjectIdenticalTo:self] != NSNotFound && [[self parentNode] isRooted]);
}
- (NSMenuItem *)menuItem
{
	return [[_menuItem retain] autorelease];
}

#pragma mark -

- (void)removeFromDocument
{
	if([[self document] node] == self) [[self document] close];
	else [[self parentAdapter] removeChild:self];
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
	return _dataLength ? [[_dataLength retain] autorelease] : [NSNumber numberWithUnsignedInt:0];
}
- (NSComparisonResult)compare:(PGNode *)node
{
	NSParameterAssert(node);
	NSParameterAssert([self document]);
	PGSortOrder const o = [[self document] sortOrder];
	int const d = PGSortDescendingMask & o ? -1 : 1;
	NSComparisonResult r = NSOrderedSame;
	switch(PGSortOrderMask & o) {
		case PGUnsorted:           return NSOrderedSame;
		case PGSortByDateModified: r = [[self dateModified] compare:[node dateModified]]; break;
		case PGSortByDateCreated:  r = [[self dateCreated] compare:[node dateCreated]]; break;
		case PGSortBySize:         r = [[self dataLength] compare:[node dataLength]]; break;
		case PGSortShuffle:        return random() & 1 ? NSOrderedAscending : NSOrderedDescending;
	}
	return (NSOrderedSame == r ? [[[self identifier] displayName] AE_localizedCaseInsensitiveNumericCompare:[[node identifier] displayName]] : r) * d; // If the actual sort order doesn't produce a distinct ordering, then sort by name too.
}

#pragma mark -

- (BOOL)canBookmark
{
	return [self isViewable] && [[self identifier] hasTarget];
}
- (PGBookmark *)bookmark
{
	return [[[PGBookmark alloc] initWithNode:self] autorelease];
}

#pragma mark -

- (void)identifierDidChange:(NSNotification *)aNotif
{
	[self _updateMenuItem];
	[[self parentAdapter] noteChild:self didChangeForSortOrder:PGSortByName];
	[[self document] noteNodeDisplayNameDidChange:self];
}

#pragma mark Private Protocol

- (void)_updateMenuItem
{
	if(!_allowMenuItemUpdates) return;
	NSMutableAttributedString *const label = [[[[self identifier] attributedStringWithWithAncestory:NO] mutableCopy] autorelease];
	NSString *info = nil;
	NSDate *date = nil;
	switch(PGSortOrderMask & [[self document] sortOrder]) {
		case PGSortByDateModified: date = _dateModified; break;
		case PGSortByDateCreated:  date = _dateCreated; break;
		case PGSortBySize: info = [_dataLength AE_localizedStringAsBytes]; break;
	}
	if(date && !info) info = [date AE_localizedStringWithDateStyle:kCFDateFormatterShortStyle timeStyle:kCFDateFormatterShortStyle];
	if(info) [label appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" (%@)", info] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor grayColor], NSForegroundColorAttributeName, [NSFont boldSystemFontOfSize:12], NSFontAttributeName, nil]] autorelease]];
	[_menuItem setAttributedTitle:label];
}
- (void)_updateFileAttributes
{
	BOOL menuNeedsUpdate = NO;
	NSString *path = nil;
	NSDictionary *attributes = nil;
	NSDate *dateModified = [[self dataSource] dateModifiedForNode:self];
	if(!dateModified) {
		PGResourceIdentifier *const identifier = [self identifier];
		if(path || [identifier isFileIdentifier]) {
			if(!path) path = [[identifier URL] path];
			if(!attributes) attributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO];
			dateModified = [attributes fileModificationDate];
		}
	}
	if(_dateModified != dateModified && (!_dateModified || !dateModified || ![_dateModified isEqualToDate:dateModified])) {
		[_dateModified release];
		_dateModified = [dateModified retain];
		[[self parentAdapter] noteChild:self didChangeForSortOrder:PGSortByDateModified];
		menuNeedsUpdate = YES;
	}
	NSDate *dateCreated = [[self dataSource] dateCreatedForNode:self];
	if(!dateCreated) {
		PGResourceIdentifier *const identifier = [self identifier];
		if(path || [identifier isFileIdentifier]) {
			if(!path) path = [[identifier URL] path];
			if(!attributes) attributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO];
			dateCreated = [attributes fileCreationDate];
		}
	}
	if(_dateCreated != dateCreated && (!_dateCreated || !dateCreated || ![_dateCreated isEqualToDate:dateCreated])) {
		[_dateCreated release];
		_dateCreated = [dateCreated retain];
		[[self parentAdapter] noteChild:self didChangeForSortOrder:PGSortByDateCreated];
		menuNeedsUpdate = YES;
	}
	NSNumber *dataLength = [[self dataSource] dataLengthForNode:self];
	do {
		if(dataLength) break;
		NSData *const data = [self data];
		if(data) dataLength = [[NSNumber alloc] initWithUnsignedInt:[data length]];
		if(dataLength) break;
		PGResourceIdentifier *const identifier = [self identifier];
		if(path || [identifier isFileIdentifier]) {
			if(!path) path = [[identifier URL] path];
			if(!attributes) attributes = [[NSFileManager defaultManager] fileAttributesAtPath:path traverseLink:NO];
			if(![NSFileTypeDirectory isEqualToString:[attributes fileType]]) dataLength = [attributes objectForKey:NSFileSize]; // File size is meaningless for folders.
		}
	} while(NO);
	if(_dataLength != dataLength && (!_dataLength || !dataLength || ![_dataLength isEqualToNumber:dataLength])) {
		[_dataLength release];
		_dataLength = [dataLength retain];
		[[self parentAdapter] noteChild:self didChangeForSortOrder:PGSortBySize];
		menuNeedsUpdate = YES;
	}
	if(menuNeedsUpdate) [self _updateMenuItem];
}

#pragma mark PGResourceAdapting Proxy

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
	return _document;
}

#pragma mark -

- (PGResourceIdentifier *)identifier
{
	return [[_identifier retain] autorelease];
}
- (void)loadWithInfo:(NSDictionary *)info
{
	NSMutableDictionary *const mutableInfo = info ? [[info mutableCopy] autorelease] : [NSMutableDictionary dictionary];
	[[self dataSource] node:self willLoadWithInfo:mutableInfo];
	if(![mutableInfo objectForKey:PGURLKey]) [mutableInfo AE_setObject:[[self identifier] URLByFollowingAliases:YES] forKey:PGURLKey];
	if(![mutableInfo objectForKey:PGMIMETypeKey]) [mutableInfo AE_setObject:[[mutableInfo objectForKey:PGURLResponseKey] MIMEType] forKey:PGMIMETypeKey];
	if(![mutableInfo objectForKey:PGExtensionKey]) [mutableInfo AE_setObject:[[[mutableInfo objectForKey:PGURLKey] path] pathExtension] forKey:PGExtensionKey];
	[self setResourceAdapterClass:[self classWithInfo:mutableInfo]];
	if(info) [[[self resourceAdapter] info] addEntriesFromDictionary:mutableInfo];
	if(!(PGNodeLoading & _status)) {
		[_error release];
		_error = nil;
	}
	if(![_resourceAdapter shouldLoad]) {
		if(PGNodeLoading & _status) [self loadFinished];
		return;
	}
	_status |= PGNodeLoading;
	[self noteIsViewableDidChange];
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init]; // Since we recursively load the entire tree.
	[_resourceAdapter loadWithInfo:mutableInfo];
	[pool release];
}

#pragma mark -

- (void)noteFileEventDidOccurDirect:(BOOL)flag
{
	[[self identifier] updateNaturalDisplayName];
	[self _updateFileAttributes];
	[_resourceAdapter noteFileEventDidOccurDirect:flag];
}
- (void)noteSortOrderDidChange
{
	[self _updateMenuItem];
	[_resourceAdapter noteSortOrderDidChange];
}
- (void)noteIsViewableDidChange
{
	BOOL const flag = PGNodeLoading & _status || _error || [_resourceAdapter adapterIsViewable]; // If we're loading, we should display a loading indicator, meaning we must be viewable.
	if(flag == _viewable) return;
	_viewable = flag;
	[[self document] noteNodeIsViewableDidChange:self];
}

#pragma mark NSObject Protocol

- (unsigned)hash
{
	return [[self class] hash] ^ [[self identifier] hash];
}
- (BOOL)isEqual:(id)anObject
{
	return [anObject isMemberOfClass:[self class]] && [[self identifier] isEqual:[anObject identifier]];
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@(%@) %p: %@>", [self class], [_resourceAdapter class], self, [self identifier]];
}

#pragma mark -

- (BOOL)respondsToSelector:(SEL)sel
{
	return [super respondsToSelector:sel] ? YES : [_resourceAdapter respondsToSelector:sel];
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[_resourceAdapter setNode:nil]; // PGGenericImageAdapter gets retained while it's loading in another thread, and when it finishes it might expect us to still be around.
	[_identifier release];
	[_menuItem release];
	[_resourceAdapter release];
	[_password release];
	[_error release];
	[_dateModified release];
	[_dateCreated release];
	[_dataLength release];
	[super dealloc];
}

#pragma mark -

- (IMP)methodForSelector:(SEL)sel
{
	return [super respondsToSelector:sel] ? [super methodForSelector:sel] : [_resourceAdapter methodForSelector:sel];
}
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel
{
	return [_resourceAdapter methodSignatureForSelector:sel];
}
- (void)forwardInvocation:(NSInvocation *)invocation
{
	[invocation setTarget:_resourceAdapter];
	[invocation invoke];
}

@end

@implementation NSObject (PGNodeDataSource)

- (Class)classForNode:(PGNode *)sender
{
	return Nil;
}
- (NSDate *)dateModifiedForNode:(PGNode *)sender
{
	return nil;
}
- (NSDate *)dateCreatedForNode:(PGNode *)sender
{
	return nil;
}
- (NSNumber *)dataLengthForNode:(PGNode *)sender
{
	return nil;
}
- (void)node:(PGNode *)sender willLoadWithInfo:(NSMutableDictionary *)info {}
- (BOOL)node:(PGNode *)sender
        getData:(out NSData **)outData
{
	if(outData) *outData = nil;
	return YES;
}

@end
