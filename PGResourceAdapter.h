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
@class PGNode;

extern NSString *const PGSubstitutedClassKey;

extern NSString *const PGBundleTypeFourCCsKey;
extern NSString *const PGCFBundleTypeMIMETypesKey;
extern NSString *const PGCFBundleTypeOSTypesKey;
extern NSString *const PGCFBundleTypeExtensionsKey;

extern NSString *const PGOrientationKey;

enum {
	PGMatchByPriorAgreement     = 6000,
	PGMatchByIntrinsicAttribute = 5000,
	PGMatchByFourCC             = 4000,
	PGMatchByMIMEType           = 3000,
	PGMatchByOSType             = 2000,
	PGMatchByExtension          = 1000,
	PGNotAMatch                 = 0
};
typedef NSUInteger PGMatchPriority;

@interface PGResourceAdapter : NSObject <PGActivityOwner, PGResourceAdapting>
{
	@private
	PGMatchPriority _priority;
	PGNode *_node;
	NSMutableDictionary *_info;
	NSImage *_realThumbnail;
	NSOperation *_thumbnailGenerationOperation;
	PGActivity *_activity;
}

+ (NSDictionary *)typesDictionary; // For all resource adapters.
+ (NSDictionary *)typeDictionary; // For this class.
+ (NSArray *)supportedExtensionsWhichMustAlwaysLoad:(BOOL)flag;
+ (NSArray *)adapterClassesInstantiated:(BOOL)flag forNode:(PGNode *)node withInfoDicts:(NSArray *)dicts;
+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node withInfo:(NSMutableDictionary *)info;
+ (BOOL)alwaysLoads;

@property(assign) PGNode *node;

@property(readonly) PGContainerAdapter *containerAdapter;
@property(readonly) PGContainerAdapter *rootContainerAdapter;

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
- (BOOL)hasViewableNodeCountGreaterThan:(NSUInteger)anInt;

- (BOOL)adapterIsViewable;
- (BOOL)shouldLoad;
- (PGLoadPolicy)descendentLoadPolicy;
- (void)loadIfNecessary;
- (void)load; // Sent by -[PGResourceAdapter loadIfNecessary], never call it directly. -loadFinished must be sent sometime hereafter.
- (void)fallbackLoad; // By default sends -load. Sent by -[PGNode continueLoadWithInfo:]. -loadFinished must be sent sometime hereafter.
- (BOOL)shouldFallbackOnError;
- (void)read; // Sent by -[PGNode readIfNecessary], never call it directly. -readFinishedWithImageRep:error: must be sent sometime hereafter.

- (NSImage *)thumbnail;
- (NSImage *)fastThumbnail;
- (NSImage *)realThumbnail;
- (void)setRealThumbnail:(NSImage *)anImage;
- (BOOL)canGenerateRealThumbnail;
- (NSImage *)threaded_thumbnailOfSize:(NSSize)size withInfo:(NSDictionary *)info;
- (void)invalidateThumbnail;

- (PGOrientation)orientationWithBase:(BOOL)flag;
- (void)addMenuItemsToMenu:(NSMenu *)aMenu;
- (void)clearCache;

- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident;
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

- (void)noteResourceDidChange;

@end

@interface PGResourceAdapter(PGAbstract)

- (NSImageRep *)threaded_thumbnailRepOfSize:(NSSize)size withInfo:(NSDictionary *)info;

@end
