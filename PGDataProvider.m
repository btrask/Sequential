/* Copyright © 2010, The Sequential Project
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
#import "PGDataProvider.h"

// Models
#import "PGResourceIdentifier.h"

// Other Sources
#import "PGFoundationAdditions.h"

@interface PGResourceDataProvider : PGDataProvider
{
	@private
	PGResourceIdentifier *_identifier;
	NSString *_displayableName;
}

- (id)initWithResourceIdentifier:(PGResourceIdentifier *)ident displayableName:(NSString *)name;
- (id)valueForLSAttributeName:(CFStringRef)name;
- (id)valueForFMAttributeName:(NSString *)name;

@end

@interface PGURLResponseDataProvider : PGDataProvider
{
	@private
	NSURLResponse *_response;
	NSData *_data;
}

- (id)initWithURLResponse:(NSURLResponse *)response data:(NSData *)data;

@end

@implementation PGDataProvider

#pragma mark +PGDataProvider(PGDataProviderCreation)

+ (id)providerWithResourceIdentifier:(PGResourceIdentifier *)ident displayableName:(NSString *)name
{
	for(NSString *const classString in [[[NSBundle bundleForClass:self] infoDictionary] objectForKey:@"PGDataProviderCustomizers"]) {
		Class const class = NSClassFromString(classString);
		if(![class respondsToSelector:@selector(customDataProviderWithResourceIdentifier:displayableName:)]) continue;
		PGDataProvider *const provider = [class customDataProviderWithResourceIdentifier:ident displayableName:name];
		if(provider) return provider;
	}
	return [[[PGResourceDataProvider alloc] initWithResourceIdentifier:ident displayableName:name] autorelease];
}
+ (id)providerWithResourceIdentifier:(PGResourceIdentifier *)ident
{
	return [self providerWithResourceIdentifier:ident displayableName:nil];
}
+ (id)providerWithURLResponse:(NSURLResponse *)response data:(NSData *)data
{
	for(NSString *const classString in [[[NSBundle bundleForClass:self] infoDictionary] objectForKey:@"PGDataProviderCustomizers"]) {
		Class const class = NSClassFromString(classString);
		if(![class respondsToSelector:@selector(customDataProviderWithURLResponse:data:)]) continue;
		PGDataProvider *const provider = [class customDataProviderWithURLResponse:response data:data];
		if(provider) return provider;
	}
	return [[[PGURLResponseDataProvider alloc] initWithURLResponse:response data:data] autorelease];
}

#pragma mark -PGDataProvider

- (PGResourceIdentifier *)identifier
{
	return nil;
}
- (NSURLResponse *)response
{
	return nil;
}

#pragma mark -

- (NSData *)data
{
	return nil;
}
- (NSDate *)dateModified
{
	return nil;
}
- (NSDate *)dateCreated
{
	return nil;
}

#pragma mark -

- (NSString *)UTIType
{
	return nil;
}
- (NSString *)MIMEType
{
	return nil;
}
- (OSType)typeCode
{
	return 0;
}
- (NSString *)extension
{
	return nil;
}

#pragma mark -

- (BOOL)hasData
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	BOOL const hasData = !![self data];
	[pool drain];
	return hasData;
}
- (NSNumber *)dataLength
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	NSData *const fullData = [self data];
	NSUInteger const size = [fullData length];
	[pool drain];
	return [NSNumber numberWithUnsignedInteger:size];
}
- (NSData *)fourCCData
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	NSData *const fullData = [self data];
	NSData *const fourCCData = [fullData length] > 4 ? [[fullData subdataWithRange:NSMakeRange(0, 4)] retain] : nil;
	[pool drain];
	return [fourCCData autorelease];
}
- (NSImage *)icon
{
	IconRef iconRef = NULL;
	NSString *const MIMEType = [self MIMEType];
	OSType typeCode = [self typeCode];
	if(MIMEType || typeCode) {
		if('fold' == typeCode) typeCode = kGenericFolderIcon;
		if(noErr == GetIconRefFromTypeInfo('????', typeCode, NULL, (CFStringRef)MIMEType, kIconServicesNormalUsageFlag, &iconRef)) {
			NSImage *const icon = [[[NSImage alloc] initWithIconRef:iconRef] autorelease];
			ReleaseIconRef(iconRef);
			return icon;
		}
	}
	NSString *const extension = [self extension];
	if(extension) return [[NSWorkspace sharedWorkspace] iconForFileType:extension];
	return nil;
}
- (NSString *)kindString
{
	NSString *kind = [[NSWorkspace sharedWorkspace] localizedDescriptionForType:[self UTIType]]; // Ugly ("Portable Network Graphics image"), but more accurate than file extensions.
	if(kind) return kind;
	if(noErr == LSCopyKindStringForTypeInfo(kLSUnknownType, kLSUnknownCreator, (CFStringRef)[self extension], (CFStringRef *)&kind)) return [kind autorelease];
	if(noErr == LSCopyKindStringForMIMEType((CFStringRef)[self MIMEType], (CFStringRef *)&kind)) return [kind autorelease]; // Extremely ugly ("TextEdit.app Document"), worst case.
	return nil;
}

#pragma mark -<NSCopying>

- (id)copyWithZone:(NSZone *)zone
{
	return [self retain];
}

@end

@implementation PGResourceDataProvider

#pragma mark -PGResourceDataProvider

- (id)initWithResourceIdentifier:(PGResourceIdentifier *)ident displayableName:(NSString *)name
{
	if((self = [super init])) {
		_identifier = [ident retain];
		_displayableName = [name copy];
	}
	return self;
}
- (id)valueForLSAttributeName:(CFStringRef)name
{
	FSRef ref;
	if(![_identifier getRef:&ref byFollowingAliases:NO]) return nil;
	id val = nil;
	if(noErr != LSCopyItemAttribute(&ref, kLSRolesViewer, name, (CFTypeRef *)&val)) return nil;
	return [val autorelease];
}
- (id)valueForFMAttributeName:(NSString *)name
{
	return [_identifier isFileIdentifier] ? [[[NSFileManager defaultManager] attributesOfItemAtPath:[[_identifier URL] path] error:NULL] objectForKey:name] : nil;
}

#pragma mark -PGDataProvider

- (PGResourceIdentifier *)identifier
{
	return [[_identifier retain] autorelease];
}
- (NSString *)displayableName
{
	return _displayableName ? _displayableName : [self valueForLSAttributeName:kLSItemDisplayName];
}
- (NSData *)data
{
	return [[[NSData alloc] initWithContentsOfURL:[_identifier URL] options:NSMappedRead | NSUncachedRead error:NULL] autorelease];
}

#pragma mark -

- (NSString *)UTIType
{
	return [self valueForLSAttributeName:kLSItemContentType];
}
- (NSString *)MIMEType
{
	return [(NSString *)UTTypeCopyPreferredTagWithClass((CFStringRef)[self UTIType], kUTTagClassMIMEType) autorelease];
}
- (OSType)typeCode
{
	return PGOSTypeFromString([self valueForLSAttributeName:kLSItemFileType]);
}
- (NSString *)extension
{
	return [[self valueForLSAttributeName:kLSItemExtension] lowercaseString];
}

#pragma mark -

- (NSDate *)dateModified
{
	return [self valueForFMAttributeName:NSFileModificationDate];
}
- (NSDate *)dateCreated
{
	return [self valueForFMAttributeName:NSFileCreationDate];
}

#pragma mark -

- (BOOL)hasData
{
	return PGEqualObjects([self valueForFMAttributeName:NSFileType], NSFileTypeRegular);
}
- (NSNumber *)dataLength
{
	return [self valueForFMAttributeName:NSFileSize];
}
- (NSImage *)icon
{
	return [[NSWorkspace sharedWorkspace] iconForFile:[[_identifier URL] path]];
}
- (NSString *)kindString
{
	return [self valueForLSAttributeName:kLSItemDisplayKind];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_identifier release];
	[_displayableName release];
	[super dealloc];
}

@end

@implementation PGURLResponseDataProvider

#pragma mark -PGURLResponseDataProvider

- (id)initWithURLResponse:(NSURLResponse *)response data:(NSData *)data
{
	if((self = [super init])) {
		_response = [response copy];
		_data = [data copy];
	}
	return self;
}

#pragma mark -PGDataProvider

- (PGResourceIdentifier *)identifier
{
	return [[_response URL] PG_resourceIdentifier];
}
- (NSURLResponse *)response
{
	return [[_response retain] autorelease];
}

#pragma mark -

- (NSData *)data
{
	return [[_data retain] autorelease];
}

#pragma mark -

- (NSString *)UTIType
{
	return [(NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassMIMEType, (CFStringRef)[self MIMEType], NULL) autorelease];
}
- (NSString *)MIMEType
{
	return [_response MIMEType];
}
- (NSString *)extension
{
	return [[[_response suggestedFilename] pathExtension] lowercaseString];
}

#pragma mark -NSObject

- (void)dealloc
{
	[_response release];
	[_data release];
	[super dealloc];
}

@end
