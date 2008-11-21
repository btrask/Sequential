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

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGResourceAdapter.h"

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGContainerAdapter.h"
#import "PGResourceIdentifier.h"

// Other
#import "PGCFMutableArray.h"
#import "PGGeometry.h"

// Categories
#import "NSDateAdditions.h"
#import "NSImageRepAdditions.h"
#import "NSMenuItemAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGSubstitutedClassKey = @"PGSubstitutedClass";

NSString *const PGBundleTypeFourCCsKey      = @"PGBundleTypeFourCCs";
NSString *const PGCFBundleTypeMIMETypesKey  = @"CFBundleTypeMIMETypes";
NSString *const PGCFBundleTypeOSTypesKey    = @"CFBundleTypeOSTypes";
NSString *const PGCFBundleTypeExtensionsKey = @"CFBundleTypeExtensions";

NSString *const PGOrientationKey = @"PGOrientation";
NSString *const PGDateKey        = @"PGDate";

#define PGThumbnailSize 128

static NSConditionLock *PGThumbnailsNeededLock            = nil;
static NSMutableArray  *PGAdaptersThatRequestedThumbnails = nil;
static NSMutableArray  *PGAdaptersWaitingForThumbnails    = nil;
static NSMutableArray  *PGInfoDictionaries                = nil;

@interface PGResourceAdapter (Private)

+ (void)_threaded_generateRealThumbnails;
+ (void)_setRealThumbnailWithDictionary:(NSDictionary *)aDict;

- (id)_initWithPriority:(PGMatchPriority)priority info:(NSDictionary *)info;
- (NSComparisonResult)_matchPriorityCompare:(PGResourceAdapter *)adapter;

- (void)_threaded_requestThumbnailGenerationWithInfo:(NSDictionary *)info; // Request on a separate thread so the main one doesn't have to block.

@end

@implementation PGResourceAdapter

#pragma mark Class Methods

+ (NSDictionary *)typesDictionary
{
	return [[[NSBundle mainBundle] infoDictionary] objectForKey:@"PGResourceAdapterClasses"];
}
+ (NSDictionary *)typeDictionary
{
	return [[self typesDictionary] objectForKey:NSStringFromClass(self)];
}
+ (NSArray *)supportedExtensionsWhichMustAlwaysLoad:(BOOL)flag
{
	NSMutableArray *const exts = [NSMutableArray array];
	NSDictionary *const types = [self typesDictionary];
	NSString *classString;
	NSEnumerator *const classStringEnum = [types keyEnumerator];
	while((classString = [classStringEnum nextObject])) {
		id const adapterClass = NSClassFromString(classString);
		if(!adapterClass || (flag && ![adapterClass alwaysLoads])) continue;
		NSDictionary *const typeDict = [types objectForKey:classString];
		[exts addObjectsFromArray:[typeDict objectForKey:PGCFBundleTypeExtensionsKey]];
		NSArray *const OSTypes = [typeDict objectForKey:PGCFBundleTypeOSTypesKey];
		if(!OSTypes || ![OSTypes count]) continue;
		NSString *type;
		NSEnumerator *const typeEnum = [OSTypes objectEnumerator];
		while((type = [typeEnum nextObject])) [exts addObject:NSFileTypeForHFSTypeCode(PGHFSTypeCodeForPseudoFileType(type))];
	}
	return exts;
}
+ (NSArray *)adapterClassesInstantiated:(BOOL)flag
             forNode:(PGNode *)node
             withInfoDicts:(NSArray *)dicts
{
	NSParameterAssert(node);
	NSParameterAssert(dicts);
	NSMutableArray *const adapters = [NSMutableArray array];
	NSDictionary *const types = [self typesDictionary];
	NSDictionary *info;
	NSEnumerator *const infoEnum = [dicts objectEnumerator];
	while((info = [infoEnum nextObject])) {
		Class const agreedClass = [info objectForKey:PGAdapterClassKey];
		if(agreedClass) {
			[adapters addObject:(flag ? [[[agreedClass alloc] _initWithPriority:PGMatchByPriorAgreement info:info] autorelease] : agreedClass)];
			continue;
		}
		NSString *classString;
		NSEnumerator *const classStringEnum = [types keyEnumerator];
		while((classString = [classStringEnum nextObject])) {
			Class const class = NSClassFromString(classString);
			if(![node shouldLoadAdapterClass:class]) continue;
			NSMutableDictionary *const mutableInfo = [[info mutableCopy] autorelease];
			PGMatchPriority const p = [class matchPriorityForNode:node withInfo:mutableInfo];
			if(!p) continue;
			Class altClass = [mutableInfo objectForKey:PGSubstitutedClassKey];
			if(!altClass) altClass = class;
			[adapters addObject:(flag ? [[[altClass alloc] _initWithPriority:p info:mutableInfo] autorelease] : altClass)];
		}
	}
	if(flag) [adapters sortUsingSelector:@selector(_matchPriorityCompare:)];
	return adapters;
}
+ (PGMatchPriority)matchPriorityForNode:(PGNode *)node
                   withInfo:(NSMutableDictionary *)info
{
	if([[info objectForKey:PGDataExistenceKey] intValue] == PGDoesNotExist) return PGNotAMatch;
	NSDictionary *const type = [self typeDictionary];
	if([[type objectForKey:PGBundleTypeFourCCsKey] containsObject:[info objectForKey:PGFourCCDataKey]]) return PGMatchByFourCC;
	if([[type objectForKey:PGCFBundleTypeMIMETypesKey] containsObject:[info objectForKey:PGMIMETypeKey]]) return PGMatchByMIMEType;
	if([[type objectForKey:PGCFBundleTypeOSTypesKey] containsObject:[info objectForKey:PGOSTypeKey]]) return PGMatchByOSType;
	if([[type objectForKey:PGCFBundleTypeExtensionsKey] containsObject:[[info objectForKey:PGExtensionKey] lowercaseString]]) return PGMatchByExtension;
	return PGNotAMatch;
}
+ (BOOL)alwaysLoads
{
	return [PGResourceAdapter class] != self;
}

#pragma mark -

+ (NSImage *)threaded_thumbnailOfSize:(float)size
             withCreationDictionary:(NSDictionary *)dict
{
	NSImageRep *const rep = [self threaded_thumbnailRepOfSize:size withCreationDictionary:dict];
	if(!rep) return nil;
	NSImage *const image = [[[NSImage alloc] initWithSize:NSMakeSize([rep pixelsWide], [rep pixelsHigh])] autorelease];
	[image addRepresentation:rep];
	return image;
}
+ (NSImageRep *)threaded_thumbnailRepOfSize:(float)size
                withCreationDictionary:(NSDictionary *)dict
{
	NSImageRep *rep = [dict objectForKey:PGImageRepKey];
	if(!rep) rep = [NSImageRep AE_bestImageRepWithData:[dict objectForKey:PGDataKey]];
	if(!rep) return nil;
	PGOrientation const orientation = [[dict objectForKey:PGOrientationKey] unsignedIntValue];
	NSSize const originalSize = PGRotated90CC & orientation ? NSMakeSize([rep pixelsHigh], [rep pixelsWide]) : NSMakeSize([rep pixelsWide], [rep pixelsHigh]);
	NSSize s = PGIntegralSize(PGScaleSizeByFloat(originalSize, MIN(1, MIN(size / originalSize.width, size / originalSize.height))));
	NSBitmapImageRep *const thumbRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:s.width pixelsHigh:s.height bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
	if(!thumbRep) return nil;
	NSGraphicsContext *const ctx = [NSGraphicsContext graphicsContextWithAttributes:[NSDictionary dictionaryWithObject:thumbRep forKey:NSGraphicsContextDestinationAttributeName]];
	[NSGraphicsContext setCurrentContext:ctx];
	[ctx setImageInterpolation:NSImageInterpolationHigh];
	if(PGUpright == orientation) [rep drawInRect:NSMakeRect(0, 0, s.width, s.height)];
	else {
		NSAffineTransform *const t = [NSAffineTransform transform];
		[t translateXBy:s.width / 2.0f yBy:s.height / 2.0f];
		if(PGRotated90CC & orientation) {
			s = NSMakeSize(s.height, s.width);
			[t rotateByDegrees:90];
		}
		[t scaleXBy:(PGFlippedHorz & orientation ? -1 : 1) yBy:(PGFlippedVert & orientation ? -1 : 1)];
		[t concat];
		[rep drawInRect:NSMakeRect(s.width / -2.0f, s.height / -2.0f, s.width, s.height)];
	}
	[NSGraphicsContext setCurrentContext:nil];
	return thumbRep;
}

#pragma mark Private Protocol

+ (void)_threaded_generateRealThumbnails
{
	NSParameterAssert(PGThumbnailsNeededLock);
	for(;;) {
		NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
		[PGThumbnailsNeededLock lockWhenCondition:YES];
		PGResourceAdapter *const adapter = [PGAdaptersThatRequestedThumbnails objectAtIndex:0];
		[PGAdaptersThatRequestedThumbnails removeObjectAtIndex:0];
		NSDictionary *const info = [[[PGInfoDictionaries objectAtIndex:0] retain] autorelease];
		[PGInfoDictionaries removeObjectAtIndex:0];
		NSDictionary *const dict = [adapter threaded_thumbnailCreationDictionaryWithInfo:info];
		Class const class = [adapter class];
		[PGThumbnailsNeededLock unlockWithCondition:!![PGAdaptersThatRequestedThumbnails count]];
		[self performSelectorOnMainThread:@selector(_setRealThumbnailWithDictionary:) withObject:[NSDictionary dictionaryWithObjectsAndKeys:[NSValue valueWithNonretainedObject:adapter], @"AdapterValue", [class threaded_thumbnailOfSize:PGThumbnailSize withCreationDictionary:dict], @"Thumbnail", [info objectForKey:PGDateKey], PGDateKey, nil] waitUntilDone:NO];
		[pool release];
	}
}
+ (void)_setRealThumbnailWithDictionary:(NSDictionary *)aDict
{
	PGResourceAdapter *const adapter = [[aDict objectForKey:@"AdapterValue"] nonretainedObjectValue];
	unsigned const i = [PGAdaptersWaitingForThumbnails indexOfObject:adapter];
	if(NSNotFound == i) return;
	[PGAdaptersWaitingForThumbnails removeObjectAtIndex:i];
	NSImage *const thumbnail = [aDict objectForKey:@"Thumbnail"];
	if(thumbnail) [adapter setRealThumbnail:thumbnail validAsOf:[aDict objectForKey:PGDateKey]];
}

#pragma mark Instance Methods

- (PGNode *)node
{
	return _node;
}
- (void)setNode:(PGNode *)aNode
{
	@synchronized(self) {
		if(aNode == _node) return;
		_node = aNode;
	}
	[self noteIsViewableDidChange];
}

#pragma mark -

- (BOOL)adapterIsViewable
{
	return NO;
}
- (BOOL)shouldLoad
{
	return [[self node] shouldLoadAdapterClass:[self class]];
}
- (PGLoadPolicy)descendentLoadPolicy
{
	return PGLoadToMaxDepth;
}
- (void)loadIfNecessary
{
	if(![self shouldLoad]) return [[self node] loadFinished];
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init]; // We load recursively, so memory use can be a problem.
	[self load];
	[pool release];
}
- (void)load
{
	[[self node] loadFinished];
}
- (void)fallbackLoad
{
	[self load];
}
- (BOOL)shouldFallbackOnError
{
	return YES;
}
- (void)read
{
	[[self node] readFinishedWithImageRep:nil error:nil];
}

#pragma mark -

- (NSImage *)thumbnail
{
	NSImage *const realThumbnail = [self realThumbnail];
	if(realThumbnail) return realThumbnail;
	if([self canGenerateRealThumbnail] && ![PGAdaptersWaitingForThumbnails containsObject:self]) {
		if(!PGThumbnailsNeededLock) {
			PGThumbnailsNeededLock = [[NSConditionLock alloc] initWithCondition:NO];
			PGAdaptersThatRequestedThumbnails = [[NSMutableArray alloc] initWithCallbacks:NULL];
			PGAdaptersWaitingForThumbnails = [[NSMutableArray alloc] initWithCallbacks:NULL];
			PGInfoDictionaries = [[NSMutableArray alloc] init];
			ItemCount processorCount = MIN((ItemCount)4, MPProcessorsScheduled());
			while(processorCount--) [NSApplication detachDrawingThread:@selector(_threaded_generateRealThumbnails) toTarget:[PGResourceAdapter class] withObject:nil];
		}
		[PGAdaptersWaitingForThumbnails addObject:self];
		NSMutableDictionary *const info = [[[self info] mutableCopy] autorelease];
		[info setObject:[NSNumber numberWithUnsignedInt:[self orientationWithBase:NO]] forKey:PGOrientationKey];
		[info setObject:[NSDate date] forKey:PGDateKey];
		[NSThread detachNewThreadSelector:@selector(_threaded_requestThumbnailGenerationWithInfo:) toTarget:self withObject:info];
	}
	if(_fastThumbnail) return [[_fastThumbnail retain] autorelease];
	_fastThumbnail = [[self fastThumbnail] retain];
	return _fastThumbnail;
}
- (NSImage *)fastThumbnail
{
	NSImage *thumbnail = nil;
	do {
		PGResourceIdentifier *const ident = [self identifier];
		if([ident isFileIdentifier]) {
			NSURL *const URL = [ident URL];
			if(URL && [URL isFileURL]) thumbnail = [[NSWorkspace sharedWorkspace] iconForFile:[URL path]];
		}
		if(thumbnail) break;
		NSDictionary *const info = [self info];
		do {
			NSString *const OSType = [info objectForKey:PGOSTypeKey];
			NSString *const MIMEType = [info objectForKey:PGMIMETypeKey];
			if(!OSType && !MIMEType) break;
			IconRef iconRef = NULL;
			if(noErr != GetIconRefFromTypeInfo('????', PGHFSTypeCodeForPseudoFileType(OSType), NULL, (CFStringRef)MIMEType, kIconServicesNormalUsageFlag, &iconRef)) break;
			NSBitmapImageRep *const thumbRep = [[[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL pixelsWide:PGThumbnailSize pixelsHigh:PGThumbnailSize bitsPerSample:8 samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace bytesPerRow:0 bitsPerPixel:0] autorelease];
			if(!thumbRep) {
				ReleaseIconRef(iconRef);
				break;
			}
			CGRect rect = CGRectMake(0, 0, PGThumbnailSize, PGThumbnailSize);
			PlotIconRefInContext([[NSGraphicsContext graphicsContextWithAttributes:[NSDictionary dictionaryWithObject:thumbRep forKey:NSGraphicsContextDestinationAttributeName]] graphicsPort], &rect, kAlignNone, kTransformNone, NULL, kPlotIconRefNormalFlags, iconRef);
			ReleaseIconRef(iconRef);
			thumbnail = [[[NSImage alloc] initWithSize:NSMakeSize(PGThumbnailSize, PGThumbnailSize)] autorelease];
			[thumbnail addRepresentation:thumbRep];
		} while(NO);
		if(thumbnail) break;
		NSString *const extension = [info objectForKey:PGExtensionKey];
		if(extension) thumbnail = [[NSWorkspace sharedWorkspace] iconForFileType:extension];
		if(thumbnail) break;
		thumbnail = [[NSWorkspace sharedWorkspace] iconForFileType:@""];
	} while(NO);
	[thumbnail setSize:NSMakeSize(PGThumbnailSize, PGThumbnailSize)]; // -iconForFile: returns images "sized" at 32x32, although they actually contain reps of at least 128x128. Our thumbnail view checks the size and doesn't upscale beyond that, though.
	return thumbnail;
}
- (NSImage *)realThumbnail
{
	return [[_realThumbnail retain] autorelease];
}
- (void)setRealThumbnail:(NSImage *)anImage
        validAsOf:(NSDate *)date
{
	if(anImage == _realThumbnail) return;
	if(date && _lastThumbnailInvalidation && [_lastThumbnailInvalidation AE_isAfter:date]) {
		(void)[self thumbnail];
		return;
	}
	[_realThumbnail release];
	_realThumbnail = [anImage retain];
	if(anImage) {
		[_fastThumbnail release];
		_fastThumbnail = nil;
	}
	[[self document] noteNodeThumbnailDidChange:[self node] children:NO];
}
- (BOOL)canGenerateRealThumbnail
{
	return NO;
}
- (NSDictionary *)threaded_thumbnailCreationDictionaryWithInfo:(NSDictionary *)info
{
	NSData *data = nil;
	@synchronized(self) {
		data = [[self node] dataWithInfo:info fast:NO];
	}
	return [NSDictionary dictionaryWithObjectsAndKeys:data, PGDataKey, [info objectForKey:PGOrientationKey], PGOrientationKey, nil];
}
- (void)cancelThumbnailGeneration
{
	[PGAdaptersWaitingForThumbnails removeObject:self];
	[PGThumbnailsNeededLock lock];
	unsigned const i = [PGAdaptersThatRequestedThumbnails indexOfObject:self];
	if(NSNotFound != i) {
		[PGAdaptersThatRequestedThumbnails removeObjectAtIndex:i];
		[PGInfoDictionaries removeObjectAtIndex:i];
	}
	[PGThumbnailsNeededLock unlockWithCondition:!![PGAdaptersThatRequestedThumbnails count]];
}
- (void)invalidateThumbnail
{
	if(![self canGenerateRealThumbnail]) return;
	[_realThumbnail release];
	_realThumbnail = nil;
	[_lastThumbnailInvalidation release];
	_lastThumbnailInvalidation = [[NSDate alloc] init];
	(void)[self thumbnail];
}

#pragma mark -

- (void)noteResourceDidChange {}

#pragma mark Private Protocol

- (id)_initWithPriority:(PGMatchPriority)priority
      info:(NSDictionary *)info
{
	if((self = [self init])) {
		_priority = priority;
		[[self info] addEntriesFromDictionary:info];
	}
	return self;
}
- (NSComparisonResult)_matchPriorityCompare:(PGResourceAdapter *)adapter
{
	NSParameterAssert([adapter isKindOfClass:[PGResourceAdapter class]]);
	if(_priority < adapter->_priority) return NSOrderedAscending;
	if(_priority > adapter->_priority) return NSOrderedDescending;
	return NSOrderedSame;
}

#pragma mark -

- (void)_threaded_requestThumbnailGenerationWithInfo:(NSDictionary *)info
{
	NSAutoreleasePool *const pool = [[NSAutoreleasePool alloc] init];
	[PGThumbnailsNeededLock lock];
	[PGAdaptersThatRequestedThumbnails addObject:self];
	[PGInfoDictionaries addObject:info];
	[PGThumbnailsNeededLock unlockWithCondition:YES];
	[pool release];
}

#pragma mark PGResourceAdapting Protocol

- (PGNode *)parentNode
{
	return [[self parentAdapter] node];
}
- (PGContainerAdapter *)parentAdapter
{
	return [_node parentAdapter];
}
- (PGContainerAdapter *)containerAdapter
{
	return [self parentAdapter];
}
- (PGNode *)rootNode
{
	return [[self node] rootNode];
}
- (PGContainerAdapter *)rootContainerAdapter
{
	return [[self parentAdapter] rootContainerAdapter];
}
- (PGDocument *)document
{
	return [_node document];
}

#pragma mark -

- (PGResourceIdentifier *)identifier
{
	return [[self node] identifier];
}
- (NSMutableDictionary *)info
{
	return [[_info retain] autorelease];
}
- (NSData *)data
{
	return [[self node] dataWithInfo:_info fast:NO];
}
- (BOOL)canGetData
{
	return [[self node] canGetDataWithInfo:_info];
}
- (BOOL)hasNodesWithData
{
	return [[self node] canGetData];
}

#pragma mark -

- (BOOL)isContainer
{
	return NO;
}
- (BOOL)isResolutionIndependent
{
	return NO;
}
- (BOOL)canExtractData
{
	return NO;
}
- (BOOL)hasExtractableChildren
{
	return NO;
}

#pragma mark -

- (NSArray *)exifEntries
{
	return nil;
}
- (PGOrientation)orientationWithBase:(BOOL)flag
{
	return flag ? [[self document] baseOrientation] : PGUpright;
}
- (void)clearCache {}

#pragma mark -

- (unsigned)viewableNodeIndex
{
	return [[self parentAdapter] viewableIndexOfChild:[self node]];
}
- (unsigned)viewableNodeCount
{
	return [[self node] isViewable] ? 1 : 0;
}
- (BOOL)hasViewableNodeCountGreaterThan:(unsigned)anInt
{
	return [self viewableNodeCount] > anInt;
}

#pragma mark -

- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
{
	return [self sortedViewableNodeFirst:flag stopAtNode:nil includeSelf:YES];
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
            stopAtNode:(PGNode *)descendent
            includeSelf:(BOOL)includeSelf
{
	return includeSelf && [[self node] isViewable] && [self node] != descendent ? [self node] : nil;
}

- (PGNode *)sortedViewableNodeNext:(BOOL)flag
{
	return [self sortedViewableNodeNext:flag includeChildren:YES];
}
- (PGNode *)sortedViewableNodeNext:(BOOL)flag
            includeChildren:(BOOL)children
{
	return [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] withSelector:@selector(sortedViewableNodeFirst:) context:nil];
}
- (PGNode *)sortedViewableNodeNext:(BOOL)flag
            afterRemovalOfChildren:(NSArray *)removedChildren
            fromNode:(PGNode *)changedNode
{
	if(!removedChildren) return [self node];
	PGNode *const potentiallyRemovedAncestor = [[self node] ancestorThatIsChildOfNode:changedNode];
	if(!potentiallyRemovedAncestor || NSNotFound == [removedChildren indexOfObjectIdenticalTo:potentiallyRemovedAncestor]) return [self node];
	return [[self sortedViewableNodeNext:flag] sortedViewableNodeNext:flag afterRemovalOfChildren:removedChildren fromNode:changedNode];
}

- (PGNode *)sortedFirstViewableNodeInFolderNext:(BOOL)flag
{
	PGNode *const node = [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] withSelector:@selector(sortedFirstViewableNodeInFolderFirst:) context:nil];
	return node || flag ? node : [[self rootContainerAdapter] sortedViewableNodeFirst:YES stopAtNode:[self node] includeSelf:YES];
}
- (PGNode *)sortedFirstViewableNodeInFolderFirst:(BOOL)flag
{
	return nil;
}

- (PGNode *)sortedViewableNodeNext:(BOOL)flag
	    matchSearchTerms:(NSArray *)terms
{
	PGNode *const node = [[self parentAdapter] outwardSearchForward:flag fromChild:[self node] withSelector:@selector(sortedViewableNodeFirst:matchSearchTerms:stopAtNode:) context:terms];
	return node ? node : [[self rootContainerAdapter] sortedViewableNodeFirst:flag matchSearchTerms:terms stopAtNode:[self node]];
}
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag
            matchSearchTerms:(NSArray *)terms
            stopAtNode:(PGNode *)descendent
{
	return [[self node] isViewable] && [self node] != descendent && [[[self identifier] displayName] AE_matchesSearchTerms:terms] ? [self node] : nil;
}

#pragma mark -

- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident
{
	return ident && [[self identifier] isEqual:ident] ? [self node] : nil;
}
- (PGNode *)ancestorThatIsChildOfNode:(PGNode *)aNode
{
	PGNode *const parent = [self parentNode];
	return aNode == parent ? [self node] : [parent ancestorThatIsChildOfNode:aNode];
}
- (BOOL)isDescendantOfNode:(PGNode *)aNode
{
	return [self ancestorThatIsChildOfNode:aNode] != nil;
}

#pragma mark -

- (void)addMenuItemsToMenu:(NSMenu *)aMenu
{
	[[[self node] menuItem] AE_removeFromMenu];
	[aMenu addItem:[[self node] menuItem]];
}

#pragma mark -

- (void)noteFileEventDidOccurDirect:(BOOL)flag {}
- (void)noteSortOrderDidChange {}
- (void)noteIsViewableDidChange
{
	[[self node] noteIsViewableDidChange];
}

#pragma mark PGLoading Protocol

- (NSString *)loadDescription
{
	return [[self identifier] displayName];
}
- (float)loadProgress
{
	return 0;
}
- (id<PGLoading>)parentLoad
{
	return [self parentAdapter] ? [self parentAdapter] : [PGLoadManager sharedLoadManager];
}
- (NSArray *)subloads
{
	return [[_subloads retain] autorelease];
}
- (void)setSubload:(id<PGLoading>)obj
        isLoading:(BOOL)flag
{
	if(!flag) [_subloads removeObjectIdenticalTo:obj];
	else if([_subloads indexOfObjectIdenticalTo:obj] == NSNotFound) [_subloads addObject:obj];
	[[self parentLoad] setSubload:[self node] isLoading:[_subloads count] != 0];
}
- (void)prioritizeSubload:(id<PGLoading>)obj
{
	unsigned const i = [_subloads indexOfObjectIdenticalTo:[[obj retain] autorelease]];
	if(NSNotFound == i) return;
	[_subloads removeObjectAtIndex:i];
	[_subloads insertObject:obj atIndex:0];
	[[self parentLoad] prioritizeSubload:[self node]];
}
- (void)cancelLoad
{
	[_subloads makeObjectsPerformSelector:@selector(cancelLoad)];
}

#pragma mark NSObject Protocol

- (NSString *)description
{
	return [NSString stringWithFormat:@"<%@ %p [%u]: %@>", [self class], self, [self retainCount], [self identifier]];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super init])) {
		_info = [[NSMutableDictionary alloc] init];
		_subloads = [[NSMutableArray alloc] initWithCallbacks:NULL];
	}
	return self;
}
- (void)dealloc
{
	[self cancelThumbnailGeneration];
	[_info release];
	[_fastThumbnail release];
	[_realThumbnail release];
	[_lastThumbnailInvalidation release];
	[_subloads release];
	[super dealloc];
}

@end
