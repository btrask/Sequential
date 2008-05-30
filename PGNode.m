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
#import "PGNode.h"

// Models
#import "PGDocument.h"
#import "PGResourceAdapter.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGSubscription.h"

// Categories
#import "NSDateAdditions.h"
#import "NSNumberAdditions.h"
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGNodeLoadingDidProgressNotification = @"PGNodeLoadingDidProgress";
NSString *const PGNodeReadyForViewingNotification    = @"PGNodeReadyForViewing";

NSString *const PGImageKey = @"PGImage";
NSString *const PGErrorKey = @"PGError";

NSString *const PGNodeErrorDomain = @"PGNodeError";

@interface PGNode (Private)

- (void)_updateMenuItem;

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
      adapterClass:(Class)class
      dataSource:(id)source
      load:(BOOL)flag;
{
	NSParameterAssert(parent || doc);
	if((self = [super init])) {
		_parentAdapter = parent;
		_document = doc ? doc : [parent document];
		if([[[self document] node] nodeForIdentifier:ident]) { // It's already open.
			[self release];
			return nil;
		}
		_identifier = [ident retain];
		[_identifier AE_addObserver:self selector:@selector(identifierDidChange:) name:PGResourceIdentifierIconDidChangeNotification];
		[_identifier AE_addObserver:self selector:@selector(identifierDidChange:) name:PGResourceIdentifierDisplayNameDidChangeNotification];
		[[_identifier subscription] AE_addObserver:self selector:@selector(fileEventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
		_dataSource = source;
		_menuItem = [[NSMenuItem alloc] init];
		[_menuItem setRepresentedObject:[NSValue valueWithNonretainedObject:self]];
		[_menuItem setAction:@selector(jumpToPage:)];
		[self _updateMenuItem];
		[self setResourceAdapterClass:(class ? class : [PGResourceAdapter class])];
		if(flag) [[self resourceAdapter] loadFromData:nil URLResponse:nil];
	}
	return self;
}

#pragma mark -

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
- (void)setIsViewable:(BOOL)flag
{
	if(flag == _isViewable) return;
	_isViewable = flag;
	[[self document] noteNodeIsViewableDidChange:self];
}
- (void)becomeViewed
{
	[self becomeViewedWithPassword:nil];
}
- (void)becomeViewedWithPassword:(NSString *)pass
{
	[_lastPassword autorelease];
	_lastPassword = [pass copy];
	if(_expectsReturnedImage) return;
	_expectsReturnedImage = YES;
	[[self resourceAdapter] readContents];
}

#pragma mark -

- (PGResourceAdapter *)resourceAdapter
{
	return [[_resourceAdapter retain] autorelease];
}
- (PGResourceAdapter *)setResourceAdapter:(PGResourceAdapter *)adapter
{
	if(adapter == _resourceAdapter) return nil;
	if([_resourceAdapter node] == self) [_resourceAdapter setNode:nil];
	[_resourceAdapter autorelease]; // Don't let it get deallocated immediately.
	_resourceAdapter = [adapter retain];
	[_resourceAdapter setNode:self];
	[self _updateMenuItem];
	return _resourceAdapter;
}
- (PGResourceAdapter *)setResourceAdapterClass:(Class)aClass
{
	return aClass && (!_resourceAdapter || ![_resourceAdapter isKindOfClass:aClass]) ? [self setResourceAdapter:[[[aClass alloc] init] autorelease]] : nil;
}

#pragma mark -

- (void)setDateModified:(NSDate *)aDate
{
	if(aDate == _dateModified || (aDate && [_dateModified isEqualToDate:aDate])) return;
	[_dateModified release];
	_dateModified = [aDate copy];
	[[self parentAdapter] noteChild:self didChangeForSortOrder:PGSortByDateModified];
	[self _updateMenuItem];
}
- (void)setDateCreated:(NSDate *)aDate
{
	if(aDate == _dateCreated || (aDate && [_dateCreated isEqualToDate:aDate])) return;
	[_dateCreated release];
	_dateCreated = [aDate copy];
	[[self parentAdapter] noteChild:self didChangeForSortOrder:PGSortByDateCreated];
	[self _updateMenuItem];
}
- (void)setDataLength:(NSNumber *)aNumber
{
	if(aNumber == _dataLength || (aNumber && [_dataLength isEqualToNumber:aNumber])) return;
	[_dataLength release];
	_dataLength = [aNumber copy];
	[[self parentAdapter] noteChild:self didChangeForSortOrder:PGSortBySize];
	[self _updateMenuItem];
}
- (NSComparisonResult)compare:(PGNode *)node
{
	NSParameterAssert(node);
	NSParameterAssert([self document]);
	PGSortOrder const o = [[self document] sortOrder];
	int const d = PGSortDescendingMask & o ? -1 : 1;
	switch(PGSortOrderMask & o) {
		case PGUnsorted:           return NSOrderedSame;
		case PGSortByDateModified: return [[self dateModified] compare:[node dateModified]] * d;
		case PGSortByDateCreated:  return [[self dateCreated] compare:[node dateCreated]] * d;
		case PGSortBySize:         return [[self dataLength] compare:[node dataLength]] * d;
		case PGSortShuffle:        return random() & 1 ? NSOrderedAscending : NSOrderedDescending;
	}
	return [[[self identifier] displayName] AE_localizedCaseInsensitiveNumericCompare:[[node identifier] displayName]] * d;
}

#pragma mark -

- (void)identifierDidChange:(NSNotification *)aNotif
{
	[self _updateMenuItem];
	if([PGResourceIdentifierDisplayNameDidChangeNotification isEqualToString:[aNotif name]]) [[self parentAdapter] noteChild:self didChangeForSortOrder:PGSortByName];
	[[self document] noteNodeDisplayNameDidChange:self];
}
- (void)fileEventDidOccur:(NSNotification *)aNotif
{
	[[self resourceAdapter] fileResourceDidChange:[[[aNotif userInfo] objectForKey:PGSubscriptionFlagsKey] unsignedIntValue]];
}

#pragma mark Private Protocol

- (void)_updateMenuItem
{
	NSMutableAttributedString *const label = [[[[self identifier] attributedStringWithWithAncestory:NO] mutableCopy] autorelease];
	PGSortOrder const o = [[self document] sortOrder];
	NSDate *date = nil;
	NSString *info = nil;
	switch(PGSortOrderMask & o) {
		case PGSortByDateModified: date = _dateModified; break;
		case PGSortByDateCreated:  date = _dateCreated; break;
		case PGSortBySize: info = [_dataLength AE_localizedStringAsBytes]; break;
	}
	if(date && !info) info = [date AE_localizedStringWithDateStyle:kCFDateFormatterShortStyle timeStyle:kCFDateFormatterShortStyle];
	if(info) [label appendAttributedString:[[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" (%@)", info] attributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSColor grayColor], NSForegroundColorAttributeName, [NSFont boldSystemFontOfSize:12], NSFontAttributeName, nil]] autorelease]];
	[_menuItem setAttributedTitle:label];
}

#pragma mark PGResourceAdapting Proxy

- (PGContainerAdapter *)parentAdapter
{
	return _parentAdapter;
}
- (PGDocument *)document
{
	return _document;
}
- (PGResourceIdentifier *)identifier
{
	return [[_identifier retain] autorelease];
}
- (id)dataSource
{
	return _dataSource;
}
- (BOOL)isViewable
{
	return _isViewable;
}
- (NSString *)lastPassword
{
	return [[_lastPassword retain] autorelease];
}
- (BOOL)expectsReturnedImage
{
	return _expectsReturnedImage;
}
- (void)returnImage:(NSImage *)anImage
        error:(NSError *)error
{
	NSParameterAssert(_expectsReturnedImage);
	_expectsReturnedImage = NO;
	NSMutableDictionary *const dict = [NSMutableDictionary dictionary];
	if(anImage) [dict setObject:anImage forKey:PGImageKey];
	if(error) [dict setObject:error forKey:PGErrorKey];
	[self AE_postNotificationName:PGNodeReadyForViewingNotification userInfo:dict];
}
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
- (void)sortOrderDidChange
{
	[self _updateMenuItem];
	[[self resourceAdapter] sortOrderDidChange];
}

#pragma mark NSProxy

- (BOOL)respondsToSelector:(SEL)sel
{
	return [super respondsToSelector:sel] ? YES : [_resourceAdapter respondsToSelector:sel];
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

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[_identifier release];
	[_menuItem release];
	[_resourceAdapter release];
	[_lastPassword release];
	[_dateModified release];
	[_dateCreated release];
	[_dataLength release];
	[super dealloc];
}

#pragma mark -

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
	return [NSString stringWithFormat:@"<%@ (%@): %p %@>", [self class], [[self resourceAdapter] class], self, [self identifier]];
}

@end
