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
#import "PGBookmark.h"

// Models
#import "PGNode.h"
#import "PGResourceIdentifier.h"
#import "PGSubscription.h"

// Categories
#import "NSObjectAdditions.h"

NSString *const PGBookmarkDidUpdateNotification = @"PGBookmarkDidUpdate";

@implementation PGBookmark

#pragma mark Instance Methods

- (id)initWithNode:(PGNode *)aNode
{
	return [self initWithDocumentIdentifier:[[aNode document] identifier] fileIdentifier:[aNode identifier] displayName:nil];
}
- (id)initWithDocumentIdentifier:(PGResourceIdentifier *)docIdent
      fileIdentifier:(PGResourceIdentifier *)fileIdent
      displayName:(NSString *)aString
{
	if((self = [super init])) {
		_documentIdentifier = [docIdent retain];
		[[_documentIdentifier subscription] AE_addObserver:self selector:@selector(eventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
		_fileIdentifier = [fileIdent retain];
		[[_fileIdentifier subscription] AE_addObserver:self selector:@selector(eventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
		_backupDisplayName = [(aString ? aString : [fileIdent displayName]) copy];
	}
	return self;
}

#pragma mark -

- (PGResourceIdentifier *)documentIdentifier
{
	return [[_documentIdentifier retain] autorelease];
}
- (PGResourceIdentifier *)fileIdentifier
{
	return [[_fileIdentifier retain] autorelease];
}

#pragma mark -

- (NSString *)displayName
{
	NSString *const name = [_fileIdentifier displayName];
	return name && ![@"" isEqualToString:name] ? name : [[_backupDisplayName retain] autorelease];
}
- (BOOL)isValid
{
	if(![_documentIdentifier hasTarget] || ![_fileIdentifier hasTarget]) return NO;
	if(![_documentIdentifier isFileIdentifier] || ![_fileIdentifier isFileIdentifier]) return YES;
	return [[[[_fileIdentifier rootIdentifier] URL] path] hasPrefix:[[_documentIdentifier URL] path]];
}

#pragma mark -

- (void)eventDidOccur:(NSNotification *)aNotif
{
	NSString *const displayName = [_fileIdentifier displayName];
	if(displayName && ![@"" isEqualToString:displayName]) {
		[_backupDisplayName release];
		_backupDisplayName = [displayName copy];
	}
	[self AE_postNotificationName:PGBookmarkDidUpdateNotification];
}

#pragma mark NSCoding Protocol

- (id)initWithCoder:(NSCoder *)aCoder
{
	return [self initWithDocumentIdentifier:[aCoder decodeObjectForKey:@"DocumentIdentifier"] fileIdentifier:[aCoder decodeObjectForKey:@"FileIdentifier"] displayName:[aCoder decodeObjectForKey:@"BackupDisplayName"]];
}
- (void)encodeWithCoder:(NSCoder *)aCoder
{
	[aCoder encodeObject:_documentIdentifier forKey:@"DocumentIdentifier"];
	[aCoder encodeObject:_fileIdentifier forKey:@"FileIdentifier"];
	[aCoder encodeObject:_backupDisplayName forKey:@"BackupDisplayName"];
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[_documentIdentifier release];
	[_fileIdentifier release];
	[_backupDisplayName release];
	[super dealloc];
}

#pragma mark -

- (unsigned)hash
{
	return [[self class] hash] ^ [_documentIdentifier hash] ^ [_fileIdentifier hash];
}
- (BOOL)isEqual:(id)anObject
{
	return [anObject isMemberOfClass:[self class]] && [[self documentIdentifier] isEqual:[anObject documentIdentifier]] && [[self fileIdentifier] isEqual:[anObject fileIdentifier]];
}

@end
