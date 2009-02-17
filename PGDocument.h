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
#import "PGPrefObject.h"

// Models
@class PGNode;
@class PGResourceIdentifier;
@class PGDisplayableIdentifier;
@class PGSubscription;
@class PGBookmark;

// Views
@class PGImageView;

// Controllers
@class PGDisplayController;

// Other
#import "PGGeometryTypes.h"

extern NSString *const PGDocumentWillRemoveNodesNotification;
extern NSString *const PGDocumentSortedNodesDidChangeNotification;
extern NSString *const PGDocumentNodeIsViewableDidChangeNotification;
extern NSString *const PGDocumentNodeThumbnailDidChangeNotification;
extern NSString *const PGDocumentNodeDisplayNameDidChangeNotification;
extern NSString *const PGDocumentBaseOrientationDidChangeNotification;

extern NSString *const PGDocumentNodeKey;
extern NSString *const PGDocumentRemovedChildrenKey;
extern NSString *const PGDocumentUpdateChildrenKey;

@interface PGDocument : PGPrefObject
{
	@private
	PGDisplayableIdentifier *_originalIdentifier;
	PGNode *_node;
	PGSubscription *_subscription;
	NSMutableArray *_cachedNodes;

	PGNode *_storedNode;
	PGImageView *_storedImageView;
	NSSize _storedOffset;
	NSString *_storedQuery;
	NSRect _storedFrame;

	PGDisplayableIdentifier *_initialIdentifier;
	PGDisplayController *_displayController;
	NSMenu *_pageMenu;
	PGOrientation _baseOrientation;

	unsigned _processingNodeCount;
	BOOL _sortedChildrenChanged;
}

- (id)initWithIdentifier:(PGDisplayableIdentifier *)ident;
- (id)initWithURL:(NSURL *)aURL;
- (id)initWithBookmark:(PGBookmark *)aBookmark;
- (PGDisplayableIdentifier *)originalIdentifier;
- (PGDisplayableIdentifier *)rootIdentifier;
- (PGNode *)node;
- (void)openBookmark:(PGBookmark *)aBookmark;

- (void)getStoredNode:(out PGNode **)outNode imageView:(out PGImageView **)outImageView offset:(out NSSize *)outOffset query:(out NSString **)outQuery; // No arguments may be NULL.
- (void)storeNode:(PGNode *)node imageView:(PGImageView *)imageView offset:(NSSize)offset query:(NSString *)query;
- (BOOL)getStoredWindowFrame:(out NSRect *)outFrame;
- (void)storeWindowFrame:(NSRect)frame;

- (PGDisplayController *)displayController;
- (void)setDisplayController:(PGDisplayController *)controller;

- (void)createUI;
- (void)close;

- (BOOL)isOnline;
- (NSMenu *)pageMenu;

- (PGOrientation)baseOrientation;
- (void)setBaseOrientation:(PGOrientation)anOrientation;

- (BOOL)isProcessingNodes;
- (void)setProcessingNodes:(BOOL)flag; // Batch changes for performance.

- (void)noteNode:(PGNode *)node willRemoveNodes:(NSArray *)anArray;
- (void)noteSortedChildrenDidChange;
- (void)noteNodeIsViewableDidChange:(PGNode *)node;
- (void)noteNodeThumbnailDidChange:(PGNode *)node children:(BOOL)flag;
- (void)noteNodeDisplayNameDidChange:(PGNode *)node;
- (void)noteNodeDidCache:(PGNode *)node;

- (void)identifierIconDidChange:(NSNotification *)aNotif;
- (void)subscriptionEventDidOccur:(NSNotification *)aNotif;

@end
