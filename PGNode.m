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

NSString *const PGPasswordError = @"PGPassword";
NSString *const PGEncodingError = @"PGEncoding";

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
		_document = doc;
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

- (NSComparisonResult)compare:(PGNode *)node
{
	NSParameterAssert([self document]);
	PGSortOrder const o = [[self document] sortOrder];
	NSParameterAssert(PGUnsorted != o);
	int const d = PGSortDescendingMask & o ? -1 : 1;
	PGResourceAdapter *const a1 = [self resourceAdapter], *const a2 = [node resourceAdapter];
	switch(PGSortOrderMask & o) {
		case PGSortByDateModified: return [[a1 dateModified:NO] compare:[a2 dateModified:NO]] * d;
		case PGSortByDateCreated:  return [[a1 dateCreated:NO] compare:[a2 dateCreated:NO]] * d;
		case PGSortBySize:         return [[a1 size:NO] compare:[a2 size:NO]] * d;
		case PGSortShuffle:        return random() & 1 ? NSOrderedAscending : NSOrderedDescending;
	}
	return [[a1 sortName] AE_localizedCaseInsensitiveNumericCompare:[a2 sortName]] * d;
}

#pragma mark -

- (void)identifierDidChange:(NSNotification *)aNotif
{
	[self _updateMenuItem];
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
		case PGSortByDateModified: date = [[self resourceAdapter] dateModified:YES]; break;
		case PGSortByDateCreated:  date = [[self resourceAdapter] dateCreated:YES]; break;
		case PGSortBySize: info = [[[self resourceAdapter] size:YES] AE_localizedStringAsBytes]; break;
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
	return _document ? _document : [_parentAdapter document];
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
        error:(NSString *)error
{
	NSParameterAssert(_expectsReturnedImage);
	_expectsReturnedImage = NO;
	NSMutableDictionary *const dict = [NSMutableDictionary dictionary];
	if(anImage) [dict setObject:anImage forKey:PGImageKey];
	if(error) [dict setObject:error forKey:PGErrorKey];
	[self AE_postNotificationName:PGNodeReadyForViewingNotification userInfo:dict];
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
	[super dealloc];
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ (%@): %p %@>", [self class], [[self resourceAdapter] class], self, [self identifier]];
}

@end
