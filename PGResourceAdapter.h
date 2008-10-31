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
#import "PGResourceAdapting.h"

// Models
@class PGNode;

extern NSString *const PGSubstitutedClassKey;

extern NSString *const PGBundleTypeFourCCsKey;
extern NSString *const PGCFBundleTypeMIMETypesKey;
extern NSString *const PGCFBundleTypeOSTypesKey;
extern NSString *const PGCFBundleTypeExtensionsKey;

extern NSString *const PGImageDataKey;
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
typedef unsigned PGMatchPriority;

@interface PGResourceAdapter : NSObject <PGResourceAdapting>
{
	@private
	PGMatchPriority      _priority;
	PGNode              *_node;
	NSMutableDictionary *_info;
	NSImage             *_fastThumbnail;
	NSImage             *_realThumbnail;
	NSMutableArray      *_subloads;
}

+ (NSDictionary *)typesDictionary; // For all resource adapters.
+ (NSDictionary *)typeDictionary; // For this class.
+ (NSArray *)supportedExtensionsWhichMustAlwaysLoad:(BOOL)flag;
+ (NSArray *)adapterClassesInstantiated:(BOOL)flag forNode:(PGNode *)node withInfoDicts:(NSArray *)dicts;
+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node withInfo:(NSMutableDictionary *)info;
+ (BOOL)alwaysLoads;

+ (NSImage *)threaded_thumbnailOfSize:(float)size withCreationDictionary:(NSDictionary *)dict;
+ (NSImageRep *)threaded_thumbnailRepOfSize:(float)size withCreationDictionary:(NSDictionary *)dict;

- (PGNode *)node;
- (void)setNode:(PGNode *)aNode;

- (BOOL)adapterIsViewable;
- (BOOL)shouldLoad;
- (PGLoadPolicy)descendentLoadPolicy;
- (void)loadIfNecessary;
- (void)load; // Sent by -[PGResourceAdapter loadIfNecessary], never call it directly. -loadFinished must be sent sometime hereafter.
- (void)fallbackLoad; // By default sends -load. Sent by -[PGNode continueLoadWithInfo:]. -loadFinished must be sent sometime hereafter.
- (void)read; // Sent by -[PGNode readIfNecessary], never call it directly. -readFinishedWithImageRep:error: must be sent sometime hereafter.

- (NSImage *)thumbnail;
- (NSImage *)fastThumbnail;
- (NSImage *)realThumbnail;
- (void)setRealThumbnail:(NSImage *)anImage;
- (BOOL)canGenerateRealThumbnail;
- (NSDictionary *)threaded_thumbnailCreationDictionaryWithInfo:(NSDictionary *)info;
- (void)cancelThumbnailGeneration;

- (void)noteResourceDidChange;

@end
