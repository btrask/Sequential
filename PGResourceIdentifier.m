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
#import "PGResourceIdentifier.h"

// Models
#import "PGSubscription.h"

// Other
#import "PGAttachments.h"

// Categories
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
	BOOL            _allowSubscription;
	NSURL          *_cachedURL;
}

- (id)initWithURL:(NSURL *)URL; // Must be a file URL.
- (id)initWithAliasData:(const uint8_t *)data length:(unsigned)length;
- (void)createSubscription;
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
- (PGResourceIdentifier *)superidentifier
{
	return nil;
}
- (PGResourceIdentifier *)rootIdentifier
{
	return [self superidentifier] ? [[self superidentifier] rootIdentifier] : self;
}

#pragma mark -

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

- (BOOL)hasTarget
{
	return NO;
}
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
        notify:(BOOL)flag
{
	if(icon == _icon) return;
	[_icon release];
	_icon = [icon retain];
	if(flag) [self AE_postNotificationName:PGResourceIdentifierIconDidChangeNotification];
}
- (NSString *)displayName
{
	if(_displayName) return [[_displayName retain] autorelease];
	NSURL *const URL = [self URL];
	if(!URL) return @"";
	NSString *displayName = nil;
	if(LSCopyDisplayNameForURL((CFURLRef)URL, (CFStringRef *)&displayName) == noErr && displayName) return [displayName autorelease];
	NSString *const path = [URL path];
	return [@"/" isEqualToString:path] ? [URL absoluteString] : [path lastPathComponent];
}
- (void)setDisplayName:(NSString *)aString
        notify:(BOOL)flag
{
	if(aString == _displayName) return;
	[_displayName release];
	_displayName = [aString isEqual:@""] ? nil : [aString copy];
	if(flag) [self AE_postNotificationName:PGResourceIdentifierDisplayNameDidChangeNotification];
}

#pragma mark -

- (PGSubscription *)subscription
{
	return nil;
}
- (NSAttributedString *)attributedStringWithWithAncestory:(BOOL)flag
{
	NSMutableAttributedString *const result = [NSMutableAttributedString PG_attributedStringWithFileIcon:[self icon] name:[self displayName]];
	if(!flag) return result;
	NSURL *const URL = [self URL];
	if(!URL) return result;
	NSString *const parent = [URL isFileURL] ? [[URL path] stringByDeletingLastPathComponent] : [URL absoluteString];
	NSString *const parentName = [URL isFileURL] ? [parent lastPathComponent] : parent;
	if(!parentName || [parentName isEqual:@""]) return result;
	[[result mutableString] appendString:[NSString stringWithFormat:@" %C ", 0x2014]];
	[result appendAttributedString:[NSAttributedString PG_attributedStringWithFileIcon:([URL isFileURL] ? [[parent AE_fileURL] AE_icon] : nil) name:parentName]];
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
		[self setIcon:[aCoder decodeObjectForKey:@"Icon"] notify:NO];
		[self setDisplayName:[aCoder decodeObjectForKey:@"DisplayName"] notify:NO];
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
	return [NSString stringWithFormat:@"%@", [self URL]];
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
			return [[PGURLIdentifier alloc] initWithURL:URL];
		}
		_cachedURL = [URL retain];
		_allowSubscription = YES;
		[self createSubscription];
	}
	return self;
}
- (id)initWithAliasData:(const uint8_t *)data
      length:(unsigned)length
{
	if(!data || !length) {
		[self release];
		return nil;
	}
	if((self = [super init])) {
		_alias = (AliasHandle)NewHandle(length);
		memcpy(*_alias, data, length);
		_allowSubscription = YES;
		[self createSubscription];
	}
	return self;
}
- (void)createSubscription
{
	NSParameterAssert(!_subscription);
	if(!_allowSubscription) return;
	_subscription = [[PGSubscription alloc] initWithPath:[[self URL] path]];
	[_subscription AE_addObserver:self selector:@selector(subscriptionEventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
}
- (void)subscriptionEventDidOccur:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	[_cachedURL release];
	_cachedURL = nil;
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
		_allowSubscription = YES;
		[self createSubscription];
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
- (NSURL *)URL
{
	if(!_cachedURL) _cachedURL = [[super URL] retain];
	return [[_cachedURL retain] autorelease];
}
- (BOOL)hasTarget
{
	return [self URLByFollowingAliases:YES] != nil;
}
- (BOOL)isFileIdentifier
{
	return YES;
}
- (PGSubscription *)subscription
{
	return [[_subscription retain] autorelease];
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	if(_alias) DisposeHandle((Handle)_alias);
	[_subscription release];
	[_cachedURL release];
	[super dealloc];
}

@end

@implementation PGURLIdentifier

#pragma mark Instance Methods

- (id)initWithURL:(NSURL *)URL
{
	if((self = [super init])) {
		_URL = [URL retain];
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
- (BOOL)hasTarget
{
	return YES;
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
- (BOOL)hasTarget
{
	return NSNotFound != _index && [_superidentifier hasTarget];
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
- (NSString *)description
{
	return [NSString stringWithFormat:@"%@:%d", [self superidentifier], [self index]];
}

@end
