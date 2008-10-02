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
#import <Cocoa/Cocoa.h>
#import "PGPrefObject.h"

// Models
@class PGNode;
@class PGResourceIdentifier;
@class PGSubscription;
@class PGBookmark;

// Views
@class PGImageView;

// Controllers
@class PGDisplayController;

// Other
#import "PGGeometry.h"

extern NSString *const PGDocumentWillRemoveNodesNotification;
extern NSString *const PGDocumentSortedNodesDidChangeNotification;
extern NSString *const PGDocumentNodeIsViewableDidChangeNotification;
extern NSString *const PGDocumentNodeDisplayNameDidChangeNotification;
extern NSString *const PGDocumentBaseOrientationDidChangeNotification;

extern NSString *const PGDocumentNodeKey;
extern NSString *const PGDocumentRemovedChildrenKey;

@interface PGDocument : PGPrefObject
{
	@private
	PGResourceIdentifier *_identifier;
	PGNode               *_node;
	PGSubscription       *_subscription;
	NSMutableArray       *_cachedNodes;

	PGNode               *_storedNode;
	PGImageView          *_storedImageView;
	NSPoint               _storedCenter;
	NSString             *_storedQuery;
	NSRect                _storedFrame;

	PGResourceIdentifier *_initialIdentifier;
	PGDisplayController  *_displayController;
	NSMenu               *_pageMenu;
	PGOrientation         _baseOrientation;

	unsigned              _processingNodeCount;
	BOOL                  _sortedChildrenChanged;
}

- (id)initWithResourceIdentifier:(PGResourceIdentifier *)ident;
- (id)initWithURL:(NSURL *)aURL;
- (id)initWithBookmark:(PGBookmark *)aBookmark;
- (PGResourceIdentifier *)identifier;
- (PGNode *)node;
- (void)openBookmark:(PGBookmark *)aBookmark;

- (void)getStoredNode:(out PGNode **)outNode imageView:(out PGImageView **)outImageView center:(out NSPoint *)outCenter query:(out NSString **)outQuery; // No arguments may be NULL.
- (void)storeNode:(PGNode *)node imageView:(PGImageView *)imageView center:(NSPoint)center query:(NSString *)query;
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
- (void)noteNodeDisplayNameDidChange:(PGNode *)node;
- (void)noteNodeDidCache:(PGNode *)node;

- (void)subscriptionEventDidOccur:(NSNotification *)aNotif;

@end
