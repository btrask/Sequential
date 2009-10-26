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
// Models
@class PGDocument;
@class PGNode;
@class PGContainerAdapter;
@class PGResourceIdentifier;
@class PGDisplayableIdentifier;
#import "PGLoading.h"
@class PGBookmark;

// Other Sources
#import "PGGeometryTypes.h"

extern NSString *const PGIdentifierKey;
extern NSString *const PGDataKey;
extern NSString *const PGURLResponseKey;
extern NSString *const PGAdapterClassKey;
extern NSString *const PGFourCCDataKey;
extern NSString *const PGMIMETypeKey;
extern NSString *const PGOSTypeKey; // Unquoted string.
extern NSString *const PGExtensionKey;
extern NSString *const PGPasswordKey;
extern NSString *const PGStringEncodingKey;

extern NSString *const PGDataExistenceKey;
enum {
	PGDoesNotExist  = -1,
	PGWillSoonExist = 0,
	PGExists        = 1
};

enum {
	PGLoadToMaxDepth = 0,
	PGLoadAll        = 1,
	PGLoadNone       = 2
};
typedef NSInteger PGLoadPolicy;

@protocol PGResourceAdapting <PGLoading>

@required
@property(readonly) PGNode *parentNode;
@property(readonly) PGContainerAdapter *parentAdapter;
@property(readonly) PGContainerAdapter *containerAdapter;
@property(readonly) PGNode *rootNode;
@property(readonly) PGContainerAdapter *rootContainerAdapter;
@property(readonly) PGDocument *document;

@property(readonly) PGDisplayableIdentifier *identifier;
@property(readonly) NSMutableDictionary *info;
@property(readonly) NSData *data;
@property(readonly) BOOL canGetData;
@property(readonly) BOOL hasNodesWithData;

@property(readonly) BOOL isContainer;
@property(readonly) BOOL isSortedFirstViewableNodeOfFolder;
@property(readonly) BOOL hasRealThumbnail;
@property(readonly, getter = isResolutionIndependent) BOOL resolutionIndependent;
@property(readonly) BOOL canSaveData;
@property(readonly) BOOL hasSavableChildren;

@property(readonly) NSArray *exifEntries;
@property(readonly) NSUInteger viewableNodeIndex;
@property(readonly) NSUInteger viewableNodeCount;

- (PGOrientation)orientationWithBase:(BOOL)flag;
- (void)clearCache;
- (BOOL)hasViewableNodeCountGreaterThan:(NSUInteger)anInt;

- (PGNode *)sortedViewableNodeFirst:(BOOL)flag;
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag stopAtNode:(PGNode *)descendent includeSelf:(BOOL)includeSelf;
- (PGNode *)sortedViewableNodeNext:(BOOL)flag;
- (PGNode *)sortedViewableNodeNext:(BOOL)flag includeChildren:(BOOL)children;
- (PGNode *)sortedViewableNodeNext:(BOOL)flag afterRemovalOfChildren:(NSArray *)removedChildren fromNode:(PGNode *)changedNode; // Returns a node that will still exist after the change.
- (PGNode *)sortedFirstViewableNodeInFolderNext:(BOOL)forward inclusive:(BOOL)inclusive;
- (PGNode *)sortedFirstViewableNodeInFolderFirst:(BOOL)flag;
- (PGNode *)sortedViewableNodeInFolderFirst:(BOOL)flag;
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
