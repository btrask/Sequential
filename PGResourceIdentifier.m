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
}

- (id)initWithURL:(NSURL *)URL; // Must be a file URL.
- (id)initWithAliasData:(const uint8_t *)data length:(unsigned)length;

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
- (BOOL)getRef:(out FSRef *)outRef
        byFollowingAliases:(BOOL)flag
{
	return NO;
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

#pragma mark -

- (NSString *)displayName
{
	return _customDisplayName ? [[_customDisplayName retain] autorelease] : [self naturalDisplayName];
}
- (NSString *)naturalDisplayName
{
	if(!_naturalDisplayName) [self updateNaturalDisplayName];
	if(_naturalDisplayName) return [[_naturalDisplayName retain] autorelease];
	return @"";
}
- (void)setNaturalDisplayName:(NSString *)aString
        notify:(BOOL)flag
{
	if(!aString || aString == _naturalDisplayName || [aString isEqualToString:_naturalDisplayName]) return;
	[_naturalDisplayName release];
	_naturalDisplayName = [aString copy];
	if(flag && !_customDisplayName) [self AE_postNotificationName:PGResourceIdentifierDisplayNameDidChangeNotification];
}
- (void)setCustomDisplayName:(NSString *)aString
        notify:(BOOL)flag
{
	NSString *const string = [@"" isEqualToString:aString] ? nil : aString;
	if(string == _customDisplayName || [string isEqualToString:_customDisplayName]) return;
	[_customDisplayName release];
	_customDisplayName = [string copy];
	if(flag) [self AE_postNotificationName:PGResourceIdentifierDisplayNameDidChangeNotification];
}
- (void)updateNaturalDisplayName
{
	NSString *name = nil;
	NSURL *const URL = [self URL];
	if(URL) {
		if(LSCopyDisplayNameForURL((CFURLRef)URL, (CFStringRef *)&name) == noErr && name) [name autorelease];
		else {
			NSString *const path = [URL path];
			name = [@"/" isEqualToString:path] ? [URL absoluteString] : [path lastPathComponent];
		}
	}
	[self setNaturalDisplayName:name notify:YES];
}

#pragma mark -

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
- (PGSubscription *)subscriptionWithDescendents:(BOOL)flag
{
	return [self isFileIdentifier] ? [PGSubscription subscriptionWithPath:[[self URL] path] descendents:flag] : nil;
}
- (PGLabelColor)labelColor
{
	FSRef ref;
	FSCatalogInfo catalogInfo;
	if(![self getRef:&ref byFollowingAliases:NO] || FSGetCatalogInfo(&ref, kFSCatInfoFinderInfo | kFSCatInfoNodeFlags, &catalogInfo, NULL, NULL, NULL) != noErr) return PGLabelNone;
	UInt16 finderFlags;
	if(catalogInfo.nodeFlags & kFSNodeIsDirectoryMask) finderFlags = ((FolderInfo *)&catalogInfo.finderInfo)->finderFlags;
	else finderFlags = ((FileInfo *)&catalogInfo.finderInfo)->finderFlags;
	return (finderFlags & 0x0E) >> 1;
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
		[self setCustomDisplayName:[aCoder decodeObjectForKey:@"DisplayName"] notify:NO];
	}
	return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:NSStringFromClass([self class]) forKey:@"ClassName"];
	[aCoder encodeObject:_icon forKey:@"Icon"];
	[aCoder encodeObject:_customDisplayName forKey:@"DisplayName"];
}

#pragma mark NSKeyedArchiverObjectSubstitution Protocol

- (Class)classForKeyedArchiver
{
	return [PGResourceIdentifier class];
}

#pragma mark NSObject Protocol

- (unsigned)hash
{
	return [[self class] hash];
}
- (BOOL)isEqual:(id)obj
{
	return obj == self || ([obj isKindOfClass:[self class]] && [[obj URL] isEqual:[self URL]]);
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@", [self URL]];
}

#pragma mark NSObject

- (void)dealloc
{
	[_icon release];
	[_naturalDisplayName release];
	[_customDisplayName release];
	[super dealloc];
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
	}
	return self;
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
	}
	return self;
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[super encodeWithCoder:aCoder];
	if(_alias) [aCoder encodeBytes:(uint8_t const *)*_alias length:GetHandleSize((Handle)_alias) forKey:@"Alias"];
}

#pragma mark NSObject Protocol

- (unsigned)hash
{
	return [[self class] hash];
}
- (BOOL)isEqual:(id)obj
{
	if(obj == self) return YES;
	if(![obj isKindOfClass:[PGAliasIdentifier class]]) return [super isEqual:obj];
	FSRef ourRef, theirRef;
	if(![self getRef:&ourRef byFollowingAliases:NO] || ![obj getRef:&theirRef byFollowingAliases:NO]) return NO;
	return FSCompareFSRefs(&ourRef, &theirRef) == noErr;
}

#pragma mark PGResourceIdentifier

- (NSURL *)URLByFollowingAliases:(BOOL)flag
{
	FSRef ref;
	if(![self getRef:&ref byFollowingAliases:flag]) return nil;
	return [(NSURL *)CFURLCreateFromFSRef(kCFAllocatorDefault, &ref) autorelease];
}
- (BOOL)getRef:(out FSRef *)outRef
        byFollowingAliases:(BOOL)flag
{
	Boolean dontCare1, dontCare2;
	if(FSResolveAliasWithMountFlags(NULL, _alias, outRef, &dontCare1, kResolveAliasFileNoUI) != noErr) return NO;
	return flag ? FSResolveAliasFileWithMountFlags(outRef, true, &dontCare1, &dontCare2, kResolveAliasFileNoUI) == noErr : YES;
}
- (BOOL)hasTarget
{
	return [self URLByFollowingAliases:YES] != nil;
}
- (BOOL)isFileIdentifier
{
	return YES;
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	if(_alias) DisposeHandle((Handle)_alias);
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

#pragma mark NSObject Protocol

- (unsigned)hash
{
	return [[self class] hash] ^ (unsigned)_index;
}
- (BOOL)isEqual:(id)obj
{
	return obj == self || ([obj isKindOfClass:[self class]] && [(PGIndexIdentifier *)obj index] == [self index] && [[self superidentifier] isEqual:[obj superidentifier]]);
}

#pragma mark -

- (NSString *)description
{
	return [NSString stringWithFormat:@"%@:%d", [self superidentifier], [self index]];
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

@end

@implementation NSURL (PGResourceIdentifierCreation)

- (id)AE_resourceIdentifier
{
	return [PGResourceIdentifier resourceIdentifierWithURL:self];
}

@end
