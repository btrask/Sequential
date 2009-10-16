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

typedef NSUInteger PGNodeStatus;

@protocol PGNodeDataSource;

@interface PGNode : NSObject
{
	@private
	PGContainerAdapter *_parentAdapter;
	PGDocument *_document;
	PGDisplayableIdentifier *_identifier;
	NSObject<PGNodeDataSource> *_dataSource;

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
	NSString *_kind;
}

+ (NSArray *)pasteboardTypes;

- (id)initWithParentAdapter:(PGContainerAdapter *)parent document:(PGDocument *)doc identifier:(PGDisplayableIdentifier *)ident dataSource:(NSObject<PGNodeDataSource> *)dataSource;

@property(readonly) NSObject<PGNodeDataSource> *dataSource;
@property(readonly) PGResourceAdapter *resourceAdapter;
@property(readonly) PGLoadPolicy ancestorLoadPolicy;
@property(retain) NSError *error;
@property(readonly) NSImage *thumbnail;
@property(readonly) BOOL isViewable;
@property(readonly) NSUInteger depth;
@property(readonly) PGNode *viewableAncestor;
@property(readonly) NSMenuItem *menuItem;
@property(readonly) BOOL canBookmark;
@property(readonly) PGBookmark *bookmark;

@property(readonly) NSDate *dateModified;
@property(readonly) NSDate *dateCreated;
@property(readonly) NSNumber *dataLength;
@property(readonly) NSString *kind;

- (NSData *)dataWithInfo:(NSDictionary *)info fast:(BOOL)flag;
- (BOOL)canGetDataWithInfo:(NSDictionary *)info;

- (BOOL)shouldLoadAdapterClass:(Class)aClass;
- (void)startLoadWithInfo:(id)info;
- (void)continueLoadWithInfo:(id)info;
- (void)loadFinished;

- (void)becomeViewed;
- (void)readIfNecessary;
- (void)readFinishedWithImageRep:(NSImageRep *)aRep error:(NSError *)error;

- (void)removeFromDocument;
- (void)detachFromTree;
- (NSComparisonResult)compare:(PGNode *)node; // Uses the document's sort mode.
- (BOOL)writeToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;

- (void)identifierIconDidChange:(NSNotification *)aNotif;
- (void)identifierDisplayNameDidChange:(NSNotification *)aNotif;

@end

@interface PGNode(PGResourceAdapterProxy) <PGResourceAdapting>
@end

@protocol PGNodeDataSource <NSObject>

@optional
- (NSDictionary *)fileAttributesForNode:(PGNode *)node;
- (void)node:(PGNode *)sender willLoadWithInfo:(NSMutableDictionary *)info;
- (BOOL)node:(PGNode *)sender getData:(out NSData **)outData info:(NSDictionary *)info fast:(BOOL)flag; // Return NO if a problem occurred. Implementations must be thread-safe.

@end
