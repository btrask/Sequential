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
#import "PGLegacy.h"

// Models
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Categories
#import "NSStringAdditions.h"

@implementation PGDynamicURL

- (id)initWithCoder:(NSCoder *)aCoder
{
	[[self init] release];
	PGDisplayableIdentifier *result = nil;
	NSURL *URL = [aCoder decodeObjectForKey:@"URL"];
	if(URL) result = [[URL PG_displayableIdentifier] retain];
	else {
		NSUInteger length;
		uint8_t const *const data = [aCoder decodeBytesForKey:@"Alias" returnedLength:&length];
		result = [[PGDisplayableIdentifier resourceIdentifierWithAliasData:data length:length] retain];
	}
	[result setIcon:[aCoder decodeObjectForKey:@"Icon"]];
	[result setCustomDisplayName:[aCoder decodeObjectForKey:@"DisplayName"]];
	return result;
}

@end

@implementation PGAlias

- (id)initWithCoder:(NSCoder *)aCoder
{
	[[self init] release];
	NSUInteger length;
	uint8_t const *data = [aCoder decodeBytesForKey:@"Alias" returnedLength:&length];
	if(!data) data = [aCoder decodeBytesForKey:@"HandleData" returnedLength:&length];
	return [[PGDisplayableIdentifier resourceIdentifierWithAliasData:data length:length] retain];
}

@end

@implementation PGIndexBookmark

- (id)initWithCoder:(NSCoder *)aCoder
{
	[[self init] release];
	PGDisplayableIdentifier *docIdent = [aCoder decodeObjectForKey:@"DocumentURL"];
	if(!docIdent) docIdent = [aCoder decodeObjectForKey:@"DocumentAlias"];
	PGDisplayableIdentifier *const fileIdent = [[docIdent subidentifierWithIndex:[aCoder decodeIntegerForKey:@"PageIndex"]] displayableIdentifier];
	[fileIdent setIcon:[aCoder decodeObjectForKey:@"PageIcon"]];
	[fileIdent setCustomDisplayName:[aCoder decodeObjectForKey:@"PageName"]];
	return [[PGBookmark alloc] initWithDocumentIdentifier:docIdent fileIdentifier:fileIdent displayName:nil];
}

@end

@implementation PGFileBookmark

- (id)initWithCoder:(NSCoder *)aCoder
{
	[[self init] release];
	PGDisplayableIdentifier *fileIdent = [aCoder decodeObjectForKey:@"FileURL"];
	if(!fileIdent) fileIdent = [aCoder decodeObjectForKey:@"FileAlias"];
	PGDisplayableIdentifier *const docIdent = [aCoder decodeBoolForKey:@"OpenImageDirectly"] ? fileIdent : [[[[[fileIdent URL] path] stringByDeletingLastPathComponent] AE_fileURL] PG_displayableIdentifier];
	return [[PGBookmark alloc] initWithDocumentIdentifier:docIdent fileIdentifier:fileIdent displayName:[aCoder decodeObjectForKey:@"BackupPageName"]];
}

@end
