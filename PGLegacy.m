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
#import "PGLegacy.h"

// Models
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Categories
#import "NSStringAdditions.h"

@implementation PGDynamicURL

- (id)initWithCoder:(NSCoder *)aCoder
{
	[self release];
	PGResourceIdentifier *result = nil;
	NSURL *URL = [aCoder decodeObjectForKey:@"URL"];
	if(URL) result = [[URL AE_resourceIdentifier] retain];
	else {
		unsigned length;
		uint8_t const *const data = [aCoder decodeBytesForKey:@"Alias" returnedLength:&length];
		result = [[PGResourceIdentifier resourceIdentifierWithAliasData:data length:length] retain];
	}
	[result setIcon:[aCoder decodeObjectForKey:@"Icon"] notify:NO];
	[result setCustomDisplayName:[aCoder decodeObjectForKey:@"DisplayName"] notify:NO];
	return result;
}

@end

@implementation PGAlias

- (id)initWithCoder:(NSCoder *)aCoder
{
	[self release];
	unsigned length;
	uint8_t const *data = [aCoder decodeBytesForKey:@"Alias" returnedLength:&length];
	if(!data) data = [aCoder decodeBytesForKey:@"HandleData" returnedLength:&length];
	return [[PGResourceIdentifier resourceIdentifierWithAliasData:data length:length] retain];
}

@end

@implementation PGIndexBookmark

- (id)initWithCoder:(NSCoder *)aCoder
{
	[self release];
	PGResourceIdentifier *docIdent = [aCoder decodeObjectForKey:@"DocumentURL"];
	if(!docIdent) docIdent = [aCoder decodeObjectForKey:@"DocumentAlias"];
	PGResourceIdentifier *const fileIdent = [docIdent subidentifierWithIndex:[aCoder decodeIntForKey:@"PageIndex"]];
	[fileIdent setIcon:[aCoder decodeObjectForKey:@"PageIcon"] notify:NO];
	[fileIdent setCustomDisplayName:[aCoder decodeObjectForKey:@"PageName"] notify:NO];
	return [[PGBookmark alloc] initWithDocumentIdentifier:docIdent fileIdentifier:fileIdent displayName:nil];
}

@end

@implementation PGFileBookmark

- (id)initWithCoder:(NSCoder *)aCoder
{
	[self release];
	PGResourceIdentifier *fileIdent = [aCoder decodeObjectForKey:@"FileURL"];
	if(!fileIdent) fileIdent = [aCoder decodeObjectForKey:@"FileAlias"];
	PGResourceIdentifier *const docIdent = [aCoder decodeBoolForKey:@"OpenImageDirectly"] ? fileIdent : [[[[[fileIdent URL] path] stringByDeletingLastPathComponent] AE_fileURL] AE_resourceIdentifier];
	return [[PGBookmark alloc] initWithDocumentIdentifier:docIdent fileIdentifier:fileIdent displayName:[aCoder decodeObjectForKey:@"BackupPageName"]];
}

@end
