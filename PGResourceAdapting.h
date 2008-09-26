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

// Models
@class PGDocument;
@class PGNode;
@class PGContainerAdapter;
@class PGResourceIdentifier;
@class PGBookmark;

// Other
#import "PGGeometry.h"

extern NSString *const PGURLResponseKey;
extern NSString *const PGURLDataKey;
extern NSString *const PGPromisesURLDataKey;
extern NSString *const PGURLKey;
extern NSString *const PGAdapterClassKey;
extern NSString *const PGFourCCDataKey;
extern NSString *const PGMIMETypeKey;
extern NSString *const PGOSTypeKey; // Uses the pseudo-OS-type that doesn't include single quotes around it.
extern NSString *const PGExtensionKey;
extern NSString *const PGPasswordKey;
extern NSString *const PGStringEncodingKey;

enum {
	PGLoadToMaxDepth = 0,
	PGLoadAll        = 1,
	PGLoadNone       = 2
};
typedef int PGLoadPolicy;

@protocol PGResourceAdapting

- (PGNode *)parentNode;
- (PGContainerAdapter *)parentAdapter;
- (PGContainerAdapter *)containerAdapter;
- (PGNode *)rootNode;
- (PGContainerAdapter *)rootContainerAdapter;
- (PGDocument *)document;

- (PGResourceIdentifier *)identifier;
- (NSMutableDictionary *)info;
- (NSData *)data;
- (BOOL)canGetData;
- (BOOL)canExtractData;

- (BOOL)isContainer;
- (float)loadingProgress;
- (NSArray *)exifEntries;
- (PGOrientation)orientation; // Incorporates the document's -baseOrientation.
- (BOOL)isResolutionIndependent;
- (void)clearCache;

- (BOOL)hasViewableNodes;
- (BOOL)hasDataNodes; // Nodes that return YES from -canGetData.
- (unsigned)viewableNodeIndex;
- (unsigned)viewableNodeCount;

- (PGNode *)sortedViewableNodeFirst:(BOOL)flag;
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag stopAtNode:(PGNode *)descendent includeSelf:(BOOL)includeSelf;
- (PGNode *)sortedViewableNodeNext:(BOOL)flag;
- (PGNode *)sortedViewableNodeNext:(BOOL)flag includeChildren:(BOOL)children;
- (PGNode *)sortedViewableNodeNext:(BOOL)flag afterRemovalOfChildren:(NSArray *)removedChildren fromNode:(PGNode *)changedNode; // Returns a node that will still exist after the change.
- (PGNode *)sotedFirstViewableNodeInFolderNext:(BOOL)flag;
- (PGNode *)sortedFirstViewableNodeInFolderFirst:(BOOL)flag;
- (PGNode *)sortedViewableNodeNext:(BOOL)flag matchSearchTerms:(NSArray *)terms;
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag matchSearchTerms:(NSArray *)terms stopAtNode:(PGNode *)descendent;

- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident;
- (PGNode *)ancestorThatIsChildOfNode:(PGNode *)aNode;
- (BOOL)isDescendantOfNode:(PGNode *)aNode;

- (void)addMenuItemsToMenu:(NSMenu *)aMenu;

- (void)noteFileEventDidOccurDirect:(BOOL)flag;
- (void)noteSortOrderDidChange;
- (void)noteIsViewableDidChange;

@end
