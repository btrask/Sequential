/* Copyright © 2007-2008, The Sequential Project
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
#import "PGBookmark.h"

// Models
#import "PGDocument.h"
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
	return [self initWithDocumentIdentifier:[[aNode document] rootIdentifier] fileIdentifier:[aNode identifier] displayName:nil];
}
- (id)initWithDocumentIdentifier:(PGDisplayableIdentifier *)docIdent
      fileIdentifier:(PGDisplayableIdentifier *)fileIdent
      displayName:(NSString *)aString
{
	if((self = [super init])) {
		_documentIdentifier = [docIdent retain];
		[_documentIdentifier AE_addObserver:self selector:@selector(identifierDidChange:) name:PGDisplayableIdentifierIconDidChangeNotification];
		[_documentIdentifier AE_addObserver:self selector:@selector(identifierDidChange:) name:PGDisplayableIdentifierDisplayNameDidChangeNotification];
		_documentSubscription = [[_documentIdentifier subscriptionWithDescendents:NO] retain];
		[_documentSubscription AE_addObserver:self selector:@selector(eventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
		_fileIdentifier = [fileIdent retain];
		[_fileIdentifier AE_addObserver:self selector:@selector(identifierDidChange:) name:PGDisplayableIdentifierIconDidChangeNotification];
		[_fileIdentifier AE_addObserver:self selector:@selector(identifierDidChange:) name:PGDisplayableIdentifierDisplayNameDidChangeNotification];
		_fileSubscription = [[_fileIdentifier subscriptionWithDescendents:NO] retain];
		[_fileSubscription AE_addObserver:self selector:@selector(eventDidOccur:) name:PGSubscriptionEventDidOccurNotification];
		if(aString) {
			[_fileIdentifier setNaturalDisplayName:aString];
			[_fileIdentifier updateNaturalDisplayName];
		}
	}
	return self;
}

#pragma mark -

- (PGDisplayableIdentifier *)documentIdentifier
{
	return [[_documentIdentifier retain] autorelease];
}
- (PGDisplayableIdentifier *)fileIdentifier
{
	return [[_fileIdentifier retain] autorelease];
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
	NSParameterAssert(aNotif);
	if([aNotif object] == _documentSubscription) [_documentIdentifier updateNaturalDisplayName];
	else if([aNotif object] == _fileSubscription) [_fileIdentifier updateNaturalDisplayName];
	[self AE_postNotificationName:PGBookmarkDidUpdateNotification];
}
- (void)identifierDidChange:(NSNotification *)aNotif
{
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
	[aCoder encodeObject:[_fileIdentifier naturalDisplayName] forKey:@"BackupDisplayName"];
}

#pragma mark NSObject Protocol

- (unsigned)hash
{
	return [[self class] hash] ^ [_documentIdentifier hash] ^ [_fileIdentifier hash];
}
- (BOOL)isEqual:(id)anObject
{
	return [anObject isMemberOfClass:[self class]] && [[self documentIdentifier] isEqual:[anObject documentIdentifier]] && [[self fileIdentifier] isEqual:[anObject fileIdentifier]];
}

#pragma mark NSObject

- (void)dealloc
{
	[self AE_removeObserver];
	[_documentIdentifier release];
	[_documentSubscription release];
	[_fileIdentifier release];
	[_fileSubscription release];
	[super dealloc];
}

@end
