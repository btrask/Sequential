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
#import <Cocoa/Cocoa.h>
#import "PGResourceAdapting.h"

// Models
@class PGDocument;
@class PGResourceAdapter;
@class PGContainerAdapter;
@class PGDisplayableIdentifier;

extern NSString *const PGNodeLoadingDidProgressNotification;
extern NSString *const PGNodeReadyForViewingNotification;

extern NSString *const PGImageRepKey;
extern NSString *const PGErrorKey;

extern NSString *const PGNodeErrorDomain;
enum {
	PGGenericError  = 1,
	PGPasswordError = 2,
	PGEncodingError = 3
};
extern NSString *const PGUnencodedStringDataKey;
extern NSString *const PGDefaultEncodingKey;

typedef unsigned PGNodeStatus;

@interface PGNode : NSObject
{
	@private
	PGContainerAdapter *_parentAdapter;
	PGDocument *_document;
	PGDisplayableIdentifier *_identifier;
	id _dataSource;

	NSMutableArray *_adapters;
	PGResourceAdapter *_adapter;
	PGNodeStatus _status;
	NSError *_error;
	PGNodeStatus _errorPhase;

	BOOL _viewable;
	NSMenuItem *_menuItem;
	BOOL _allowMenuItemUpdates; // Just an optimization.

	NSDate *_dateModified;
	NSDate *_dateCreated;
	NSNumber *_dataLength;
}

- (id)initWithParentAdapter:(PGContainerAdapter *)parent document:(PGDocument *)doc identifier:(PGDisplayableIdentifier *)ident dataSource:(id)dataSource;

- (id)dataSource;
- (NSData *)dataWithInfo:(NSDictionary *)info fast:(BOOL)flag;
- (BOOL)canGetDataWithInfo:(NSDictionary *)info;

- (PGResourceAdapter *)resourceAdapter;
- (PGLoadPolicy)ancestorLoadPolicy;
- (BOOL)shouldLoadAdapterClass:(Class)aClass;
- (void)startLoadWithInfo:(id)info;
- (void)continueLoadWithInfo:(id)info;
- (void)loadFinished;

- (void)becomeViewed;
- (void)readIfNecessary;
- (void)readFinishedWithImageRep:(NSImageRep *)aRep error:(NSError *)error;

- (NSError *)error;
- (void)setError:(NSError *)error;

- (NSImage *)thumbnail;

- (BOOL)isViewable;
- (unsigned)depth;
- (PGNode *)viewableAncestor;
- (NSMenuItem *)menuItem;

- (void)removeFromDocument;
- (void)detachFromTree;

- (NSDate *)dateModified;
- (NSDate *)dateCreated;
- (NSNumber *)dataLength;
- (NSComparisonResult)compare:(PGNode *)node; // Uses the document's sort mode.

- (BOOL)canBookmark;
- (PGBookmark *)bookmark;

- (void)identifierIconDidChange:(NSNotification *)aNotif;
- (void)identifierDisplayNameDidChange:(NSNotification *)aNotif;

@end

@interface PGNode (PGResourceAdapterProxy) <PGResourceAdapting>
@end

@interface NSObject (PGNodeDataSource)

- (NSDate *)dateModifiedForNode:(PGNode *)sender;
- (NSDate *)dateCreatedForNode:(PGNode *)sender;
- (NSNumber *)dataLengthForNode:(PGNode *)sender;
- (void)node:(PGNode *)sender willLoadWithInfo:(NSMutableDictionary *)info;
- (BOOL)node:(PGNode *)sender getData:(out NSData **)outData info:(NSDictionary *)info fast:(BOOL)flag; // Return NO if a problem occurred. Implementations must be thread-safe.

@end
