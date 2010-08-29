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
#import "PGPrefObject.h"

// Models
#import "PGNodeParenting.h"
@class PGNode;
@class PGResourceIdentifier;
@class PGDisplayableIdentifier;
@class PGSubscription;
#import "PGActivity.h"
@class PGBookmark;

// Views
@class PGImageView;

// Controllers
@class PGDisplayController;

// Other Sources
#import "PGGeometryTypes.h"

extern NSString *const PGDocumentWillRemoveNodesNotification;
extern NSString *const PGDocumentSortedNodesDidChangeNotification;
extern NSString *const PGDocumentNodeIsViewableDidChangeNotification;
extern NSString *const PGDocumentNodeThumbnailDidChangeNotification;
extern NSString *const PGDocumentNodeDisplayNameDidChangeNotification;

extern NSString *const PGDocumentNodeKey;
extern NSString *const PGDocumentRemovedChildrenKey;
extern NSString *const PGDocumentUpdateRecursivelyKey;

@interface PGDocument : PGPrefObject <PGActivityOwner, PGNodeParenting>
{
	@private
	PGDisplayableIdentifier *_rootIdentifier;
	PGNode *_node;
	PGSubscription *_subscription;
	NSMutableArray *_cachedNodes;
	NSOperationQueue *_operationQueue;

	PGNode *_storedNode;
	PGImageView *_storedImageView;
	NSSize _storedOffset;
	NSString *_storedQuery;
	NSRect _storedFrame;

	PGDisplayableIdentifier *_initialIdentifier;
	BOOL _openedBookmark;
	PGDisplayController *_displayController;
	NSMenu *_pageMenu;
	PGActivity *_activity;

	NSUInteger _processingNodeCount;
	BOOL _sortedChildrenChanged;
}

- (id)initWithIdentifier:(PGDisplayableIdentifier *)ident;
- (id)initWithURL:(NSURL *)aURL;
- (id)initWithBookmark:(PGBookmark *)aBookmark;

@property(readonly) PGDisplayableIdentifier *rootIdentifier;
@property(readonly) PGNode *node;
@property(retain) PGDisplayController *displayController;
@property(readonly, getter = isOnline) BOOL online;
@property(readonly) NSMenu *pageMenu;
@property(getter = isProcessingNodes) BOOL processingNodes; // Batch changes for performance.

- (void)getStoredNode:(out PGNode **)outNode imageView:(out PGImageView **)outImageView offset:(out NSSize *)outOffset query:(out NSString **)outQuery; // No arguments may be NULL.
- (void)storeNode:(PGNode *)node imageView:(PGImageView *)imageView offset:(NSSize)offset query:(NSString *)query;
- (BOOL)getStoredWindowFrame:(out NSRect *)outFrame;
- (void)storeWindowFrame:(NSRect)frame;

- (void)createUI;
- (void)close;
- (void)openBookmark:(PGBookmark *)aBookmark;

- (void)noteNode:(PGNode *)node willRemoveNodes:(NSArray *)anArray;
- (void)noteSortedChildrenDidChange;
- (void)noteNodeIsViewableDidChange:(PGNode *)node;
- (void)noteNodeThumbnailDidChange:(PGNode *)node recursively:(BOOL)flag;
- (void)noteNodeDisplayNameDidChange:(PGNode *)node;
- (void)noteNodeDidCache:(PGNode *)node;
- (void)addOperation:(NSOperation *)operation;

- (void)identifierIconDidChange:(NSNotification *)aNotif;
- (void)subscriptionEventDidOccur:(NSNotification *)aNotif;

@end
