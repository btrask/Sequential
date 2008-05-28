#import "PGResourceIdentifier.h"

// Models
#import "PGSubscription.h"

// Categories
#import "NSAttributedStringAdditions.h"
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"
#import "NSURLAdditions.h"

NSString *const PGResourceIdentifierIconDidChangeNotification        = @"PGResourceIdentifierIconDidChange";
NSString *const PGResourceIdentifierDisplayNameDidChangeNotification = @"PGResourceIdentifierDisplayNameDidChange";

@interface PGAliasIdentifier : PGResourceIdentifier <NSCoding>
{
	@private
	AliasHandle     _alias;
	PGSubscription *_subscription;
}

- (id)initWithURL:(NSURL *)URL; // Must be a file URL.
- (id)initWithAliasData:(const uint8_t *)data length:(unsigned)length;
- (void)subscriptionEventDidOccur:(NSNotification *)aNotif;

@end

@interface PGURLIdentifier : PGResourceIdentifier <NSCoding>
{
	@private
	NSURL *_URL;
}

- (id)initWithURL:(NSURL *)URL; // Must not be a file URL.

@end

@interface PGIndexIdentifier : PGResourceIdentifier <NSCoding>
{
	@private
	PGResourceIdentifier *_superidentifier;
	int                   _index;
}

- (id)initWithSuperidentifier:(PGResourceIdentifier *)identifier index:(int)index;

@end

@implementation PGResourceIdentifier

#pragma mark Class Methods

+ (id)resourceIdentifierWithURL:(NSURL *)URL
{
	return [[[([URL isFileURL] ? [PGAliasIdentifier class] : [PGURLIdentifier class]) alloc] initWithURL:URL] autorelease];
}
+ (id)resourceIdentifierWithAliasData:(const uint8_t *)data
      length:(unsigned)length
{
	return [[[PGAliasIdentifier alloc] initWithAliasData:data length:length] autorelease];
}

#pragma mark Instance Methods

- (PGResourceIdentifier *)subidentifierWithIndex:(int)index
{
	return [[[PGIndexIdentifier alloc] initWithSuperidentifier:self index:index] autorelease];
}

#pragma mark -

- (PGResourceIdentifier *)superidentifier
{
	return nil;
}
- (NSURL *)superURLByFollowingAliases:(BOOL)flag
{
	NSURL *const URL = [self URLByFollowingAliases:flag];
	return URL ? URL : [[self superidentifier] superURLByFollowingAliases:flag];
}
- (NSURL *)URLByFollowingAliases:(BOOL)flag
{
	return nil;
}
- (NSURL *)URL
{
	return [self URLByFollowingAliases:NO];
}
- (int)index
{
	return NSNotFound;
}

#pragma mark -

- (BOOL)isFileIdentifier
{
	return NO;
}

#pragma mark -

- (NSImage *)icon
{
	return _icon ? [[_icon retain] autorelease] : [[self URL] AE_icon];
}
- (void)setIcon:(NSImage *)icon
{
	if(icon == _icon) return;
	[_icon release];
	_icon = [icon retain];
	[self AE_postNotificationName:PGResourceIdentifierIconDidChangeNotification];
}
- (NSString *)displayName
{
	if(_displayName) return [[_displayName retain] autorelease];
	NSURL *const URL = [self URL];
	if(!URL) return @"";
	NSString *displayName = nil;
	if(LSCopyDisplayNameForURL((CFURLRef)URL, (CFStringRef *)&displayName) == noErr && displayName) return [displayName autorelease];
	return [[URL path] lastPathComponent];
}
- (void)setDisplayName:(NSString *)aString
{
	if(aString == _displayName) return;
	[_displayName release];
	_displayName = [aString isEqual:@""] ? nil : [aString copy];
	[self AE_postNotificationName:PGResourceIdentifierDisplayNameDidChangeNotification];
}

#pragma mark -

- (PGSubscription *)subscription
{
	return nil;
}
- (NSAttributedString *)attributedStringWithWithAncestory:(BOOL)flag
{
	NSMutableAttributedString *const result = [NSMutableAttributedString AE_attributedStringWithFileIcon:[self icon] name:[self displayName]];
	if(!flag) return result;
	NSURL *const URL = [self URL];
	if(!URL) return result;
	NSString *const parent = [URL isFileURL] ? [[URL path] stringByDeletingLastPathComponent] : [URL absoluteString];
	NSString *const parentName = [URL isFileURL] ? [parent lastPathComponent] : parent;
	if(!parentName || [parentName isEqual:@""]) return result;
	[[result mutableString] appendString:[NSString stringWithFormat:@" %C ", 0x2014]];
	[result appendAttributedString:[NSAttributedString AE_attributedStringWithFileIcon:([URL isFileURL] ? [[parent AE_fileURL] AE_icon] : nil) name:parentName]];
	return result;
}

#pragma mark NSCoding Protocol

- (id)initWithCoder:(NSCoder *)aCoder
{
	Class const class = NSClassFromString([aCoder decodeObjectForKey:@"ClassName"]);
	if(class && [self class] != class) {
		[self release];
		return [[class alloc] initWithCoder:aCoder];
	}
	if((self = [super init])) {
		[self setIcon:[aCoder decodeObjectForKey:@"Icon"]];
		[self setDisplayName:[aCoder decodeObjectForKey:@"DisplayName"]];
	}
	return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:NSStringFromClass([self class]) forKey:@"ClassName"];
	[aCoder encodeObject:_icon forKey:@"Icon"];
	[aCoder encodeObject:_displayName forKey:@"DisplayName"];
}

#pragma mark NSObject

- (void)dealloc
{
	[_icon release];
	[_displayName release];
	[super dealloc];
}
- (Class)classForKeyedArchiver
{
	return [PGResourceIdentifier class];
}
- (unsigned)hash
{
	return [[PGResourceIdentifier class] hash] ^ [self index];
}
- (BOOL)isEqual:(id)obj
{
	if(obj == self) return YES;
	if(![obj isKindOfClass:[PGResourceIdentifier class]] || [self index] != [(PGResourceIdentifier *)obj index]) return NO;
	NSURL *const ourURL = [self URLByFollowingAliases:YES], *const theirURL = [obj URLByFollowingAliases:YES];
	if(ourURL != theirURL && ![ourURL isEqual:theirURL]) return NO;
	PGResourceIdentifier *const ourSuper = [self superidentifier], *const theirSuper = [obj superidentifier];
	return ourSuper == theirSuper || [ourSuper isEqual:theirSuper];
}
- (NSString *)description
{
	return [NSString stringWithFormat:@"%@ (%d)", [self URL], [self index]];
}

@end

@implementation PGAliasIdentifier

#pragma mark Instance Methods

- (id)initWithURL:(NSURL *)URL
{
	NSParameterAssert([URL isFileURL]);
	if((self = [super init])) {
		FSRef ref;
		if(!CFURLGetFSRef((CFURLRef)URL, &ref) || FSNewAliasMinimal(&ref, &_alias) != noErr) {
			[self release];
			return nil;
		}
		(void)[self subscription];
	}
	return self;
}
- (id)initWithAliasData:(const uint8_t *)data
      length:(unsigned)length
{
	NSParameterAssert(data && length);
	if((self = [super init])) {
		_alias = (AliasHandle)NewHandle(length);
		memcpy(*_alias, data, length);
		(void)[self subscription];
	}
	return self;
}
- (void)subscriptionEventDidOccur:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	if([[[aNotif userInfo] objectForKey:PGSubscriptionFlagsKey] unsignedIntValue] & NOTE_RENAME) [self AE_postNotificationName:PGResourceIdentifierDisplayNameDidChangeNotification];
}

#pragma mark NSCoding Protocol

- (id)initWithCoder:(NSCoder *)aCoder
{
	if((self = [super initWithCoder:aCoder])) {
		unsigned length;
		uint8_t const *const data = [aCoder decodeBytesForKey:@"Alias" returnedLength:&length];
		if(data) {
			_alias = (AliasHandle)NewHandle(length);
			memcpy(*_alias, data, length);
		}
		(void)[self subscription];
	}
	return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder:aCoder];
	if(_alias) [aCoder encodeBytes:(uint8_t const *)*_alias length:GetHandleSize((Handle)_alias) forKey:@"Alias"];
}

#pragma mark PGResourceIdentifier

- (NSURL *)URLByFollowingAliases:(BOOL)flag
{
	FSRef ref;
	Boolean dontCare1, dontCare2;
	if(FSResolveAliasWithMountFlags(NULL, _alias, &ref, &dontCare1, kResolveAliasFileNoUI) != noErr) return nil;
	if(flag && FSResolveAliasFileWithMountFlags(&ref, true, &dontCare1, &dontCare2, kResolveAliasFileNoUI) != noErr) return nil;
	return [(NSURL *)CFURLCreateFromFSRef(kCFAllocatorDefault, &ref) autorelease];
}
- (BOOL)isFileIdentifier
{
	return YES;
}
- (PGSubscription *)subscription
{
	if(!_subscription) {
		_subscription = [[PGSubscription alloc] initWithPath:[[self URL] path]];
		[_subscription AE_addObserver:self selector:@selector(subscriptionEventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
	}
	return [[_subscription retain] autorelease];
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	if(_alias) DisposeHandle((Handle)_alias);
	[_subscription release];
	[super dealloc];
}

@end

@implementation PGURLIdentifier

#pragma mark Instance Methods

- (id)initWithURL:(NSURL *)URL
{
	NSParameterAssert(![URL isFileURL]);
	if((self = [super init])) {
		_URL = [URL copy];
	}
	return self;
}

#pragma mark NSCoding Protocol

- (id)initWithCoder:(NSCoder *)aCoder
{
	if((self = [super initWithCoder:aCoder])) {
		_URL = [[aCoder decodeObjectForKey:@"URL"] retain];
	}
	return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder:aCoder];
	[aCoder encodeObject:_URL forKey:@"URL"];
}

#pragma mark PGResourceIdentifier

- (NSURL *)URLByFollowingAliases:(BOOL)flag
{
	return [[_URL retain] autorelease];
}
- (BOOL)isFileIdentifier
{
	return [_URL isFileURL];
}

#pragma mark NSObject

- (void)dealloc
{
	[_URL release];
	[super dealloc];
}

@end

@implementation PGIndexIdentifier

#pragma mark Instance Methods

- (id)initWithSuperidentifier:(PGResourceIdentifier *)identifier
      index:(int)index
{
	if((self = [super init])) {
		_superidentifier = [identifier retain];
		_index = index;
	}
	return self;
}

#pragma mark NSCoding Protocol

- (id)initWithCoder:(NSCoder *)aCoder
{
	if((self = [super initWithCoder:aCoder])) {
		_superidentifier = [[aCoder decodeObjectForKey:@"Superidentifier"] retain];
		_index = [aCoder decodeIntForKey:@"Index"];
	}
	return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder:aCoder];
	[aCoder encodeObject:_superidentifier forKey:@"Superidentifier"];
	[aCoder encodeInt:_index forKey:@"Index"];
}

#pragma mark PGResourceIdentifier

- (PGResourceIdentifier *)superidentifier
{
	return [[_superidentifier retain] autorelease];
}
- (int)index
{
	return _index;
}
- (BOOL)isFileIdentifier
{
	return [_superidentifier isFileIdentifier];
}

#pragma mark NSObject

- (void)dealloc
{
	[_superidentifier release];
	[super dealloc];
}

@end
