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

// Controllers
#import "PGDisplayController.h"

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGFoundationAdditions.h"

NSString *const PGNodeLoadingDidProgressNotification = @"PGNodeLoadingDidProgress";
NSString *const PGNodeReadyForViewingNotification    = @"PGNodeReadyForViewing";

NSString *const PGImageRepKey       = @"PGImageRep";

NSString *const PGNodeErrorDomain        = @"PGNodeError";

enum {
	PGNodeNothing = 0,
	PGNodeLoading = 1 << 0,
	PGNodeReading = 1 << 1,
	PGNodeLoadingOrReading = PGNodeLoading | PGNodeReading
}; // PGNodeStatus.

@interface PGNode(Private)

- (void)_setResourceAdapter:(PGResourceAdapter *)adapter;

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

- (id)initWithParentAdapter:(PGContainerAdapter *)parent document:(PGDocument *)doc identifier:(PGDisplayableIdentifier *)ident
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
	_adapters = [[NSMutableArray alloc] init];
	_menuItem = [[NSMenuItem alloc] init];
	[_menuItem setRepresentedObject:[NSValue valueWithNonretainedObject:self]];
	[_menuItem setAction:@selector(jumpToPage:)];
	_allowMenuItemUpdates = YES;
	[self _updateMenuItem];
	[_identifier PG_addObserver:self selector:@selector(identifierIconDidChange:) name:PGDisplayableIdentifierIconDidChangeNotification];
	[_identifier PG_addObserver:self selector:@selector(identifierDisplayNameDidChange:) name:PGDisplayableIdentifierDisplayNameDidChangeNotification];
	return self;
}
- (PGDisplayableIdentifier *)identifier
{
	return [[_identifier retain] autorelease];
}

#pragma mark -

- (PGResourceAdapter *)resourceAdapter
{
	return [[_adapter retain] autorelease];
}
- (NSImage *)thumbnail
{
	return PGNodeLoading & _status ? nil : [[self resourceAdapter] thumbnail];
}
- (BOOL)isViewable
{
	return _viewable;
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

- (void)loadWithDataProvider:(PGDataProvider *)provider
{
	_status |= PGNodeLoading;
	PGDataProvider *const p = provider ? provider : [PGDataProvider providerWithResourceIdentifier:[self identifier] displayableName:nil];
	NSArray *const newAdapters = [p adaptersForNode:self];
	if(![newAdapters count]) return [_adapter fallbackLoad];
	[_adapters addObjectsFromArray:newAdapters];
	[self _setResourceAdapter:[_adapters lastObject]];
	[_adapter loadIfNecessary];
}
- (void)loadSucceededForAdapter:(PGResourceAdapter *)adapter
{
	NSParameterAssert(adapter == _adapter);
	NSParameterAssert(PGNodeLoading & _status);
	_status &= ~PGNodeLoading;
	[self noteIsViewableDidChange];
	[self readIfNecessary];
	[[self document] noteNodeThumbnailDidChange:self recursively:NO];
}
- (void)loadFailedWithError:(NSError *)error forAdapter:(PGResourceAdapter *)adapter
{
	NSParameterAssert(adapter == _adapter);
	NSParameterAssert(PGNodeLoading & _status);
	[_adapters removeObjectIdenticalTo:adapter];
	[_adapters insertObject:[[[PGErrorAdapter alloc] initWithNode:self dataProvider:nil] autorelease] atIndex:0];
	[self _setResourceAdapter:[_adapters lastObject]];
	[_adapter fallbackLoad];
}

#pragma mark -

- (void)becomeViewed
{
	[[[self resourceAdapter] activity] prioritize:self];
	if(PGNodeReading & _status) return;
	_status |= PGNodeReading;
	[self readIfNecessary];
}
- (void)readIfNecessary
{
	if((PGNodeLoadingOrReading & _status) == PGNodeReading) [_adapter read];
}
- (void)readFinishedWithImageRep:(NSImageRep *)aRep
{
	NSParameterAssert((PGNodeLoadingOrReading & _status) == PGNodeReading);
	_status &= ~PGNodeReading;
	[self PG_postNotificationName:PGNodeReadyForViewingNotification userInfo:[NSDictionary dictionaryWithObjectsAndKeys:aRep, PGImageRepKey, nil]];
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
	NSData *const data = [[self resourceAdapter] canGetData] ? [[self resourceAdapter] data] : nil;
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
- (void)addToMenu:(NSMenu *)menu flatten:(BOOL)flatten
{
	[_menuItem PG_removeFromMenu];
	if(flatten && [[self resourceAdapter] hasChildren]) {
		[[self resourceAdapter] addChildrenToMenu:menu];
	} else {
		[[self resourceAdapter] addChildrenToMenu:[_menuItem submenu]];
		[menu addItem:_menuItem];
	}
}

#pragma mark -

- (PGNode *)ancestorThatIsChildOfNode:(PGNode *)aNode
{
	PGNode *const parent = [self parentNode];
	return aNode == parent ? self : [parent ancestorThatIsChildOfNode:aNode];
}
- (BOOL)isDescendantOfNode:(PGNode *)aNode
{
	return [self ancestorThatIsChildOfNode:aNode] != nil;
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

#pragma mark -

- (void)noteIsViewableDidChange
{
	BOOL const showsLoadingIndicator = !!(PGNodeLoading & _status);
	BOOL const viewable = showsLoadingIndicator || [_adapter adapterIsViewable];
	if(viewable == _viewable) return;
	_viewable = viewable;
	[[self document] noteNodeIsViewableDidChange:self];
}

#pragma mark -PGNode(Private)

- (void)_setResourceAdapter:(PGResourceAdapter *)adapter
{
	if(adapter == _adapter) return;
	[[_adapter activity] setParentActivity:nil];
	_adapter = adapter;
	PGActivity *const parentActivity = [[self parentAdapter] activity];
	[[_adapter activity] setParentActivity:parentActivity ? parentActivity : [[self document] activity]];
	[self noteIsViewableDidChange];
}

#pragma mark -

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
	PGDataProvider *const dp = [[self resourceAdapter] dataProvider];
	[self _setValue:[dp dateModified] forSortOrder:PGSortByDateModified];
	[self _setValue:[dp dateCreated] forSortOrder:PGSortByDateCreated];
	[self _setValue:[NSNumber numberWithUnsignedInteger:[dp size]] forSortOrder:PGSortBySize];
	[self _setValue:[dp kindString] forSortOrder:PGSortByKind];
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
	if(!attributePtr || PGEqualObjects(value, *attributePtr)) return;
	[*attributePtr release];
	*attributePtr = [value retain];
	if(![[self document] isCurrentSortOrder:order]) return;
	[[self parentAdapter] noteChildValueForCurrentSortOrderDidChange:self];
	[self _updateMenuItem];
}

#pragma mark -NSObject

- (void)dealloc
{
	[[_adapter activity] setParentActivity:nil];

	// Using our generic -PG_removeObserver is about twice as slow as removing the observer for the specific objects we care about. When closing huge folders of thousands of files, this makes a big difference. Even now it's still the slowest part.
	[_identifier PG_removeObserver:self name:PGDisplayableIdentifierIconDidChangeNotification];
	[_identifier PG_removeObserver:self name:PGDisplayableIdentifierDisplayNameDidChangeNotification];
	[_identifier release];
	[_adapters release];

	[_menuItem release];
	[_dateModified release];
	[_dateCreated release];
	[_dataLength release];
	[_kind release];
	[super dealloc];
}

#pragma mark -NSObject(NSObject)

- (NSUInteger)hash
{
	return [[self class] hash] ^ [[self identifier] hash];
}
- (BOOL)isEqual:(id)anObject
{
	return [anObject isMemberOfClass:[self class]] && PGEqualObjects([self identifier], [(PGNode *)anObject identifier]);
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@(%@) %p: %@>", [self class], [_adapter class], self, [self identifier]];
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

- (void)noteFileEventDidOccurDirect:(BOOL)flag
{
	[[self identifier] noteNaturalDisplayNameDidChange];
	[self _updateFileAttributes];
	[_adapter noteFileEventDidOccurDirect:flag];
}
- (void)noteSortOrderDidChange
{
	[self _updateMenuItem];
	[_adapter noteSortOrderDidChange];
}

@end
