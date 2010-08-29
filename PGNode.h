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
#import "PGNodeParenting.h"
#import "PGResourceAdapting.h"
@class PGResourceAdapter;
@class PGContainerAdapter;
@class PGResourceIdentifier;
@class PGDisplayableIdentifier;
@class PGDataProvider;
@class PGBookmark;

// Other Sources
#import "PGGeometryTypes.h"

extern NSString *const PGNodeLoadingDidProgressNotification;
extern NSString *const PGNodeReadyForViewingNotification;

extern NSString *const PGImageRepKey;

extern NSString *const PGNodeErrorDomain;
enum {
	PGGenericError  = 1,
	PGPasswordError = 2,
};

typedef NSUInteger PGNodeStatus;

@interface PGNode : NSObject <PGResourceAdapting>
{
	@private
	id<PGNodeParenting> _parent;
	PGDisplayableIdentifier *_identifier;

	PGDataProvider *_dataProvider;
	NSMutableArray *_potentialAdapters;
	PGResourceAdapter *_adapter;
	PGNodeStatus _status;

	BOOL _viewable;
	NSMenuItem *_menuItem;
	BOOL _allowMenuItemUpdates;
}

+ (NSArray *)pasteboardTypes;

- (id)initWithParent:(id<PGNodeParenting>)parent identifier:(PGDisplayableIdentifier *)ident;
@property(readonly) PGDisplayableIdentifier *identifier;

@property(retain) PGDataProvider *dataProvider;
- (void)reload;
@property(readonly) PGResourceAdapter *resourceAdapter;
- (void)loadFinishedForAdapter:(PGResourceAdapter *)adapter;
- (void)fallbackFromFailedAdapter:(PGResourceAdapter *)adapter;

@property(readonly) NSImage *thumbnail;
@property(readonly) BOOL isViewable;
@property(readonly) PGNode *viewableAncestor;
@property(readonly) NSMenuItem *menuItem;
@property(readonly) BOOL canBookmark;
@property(readonly) PGBookmark *bookmark;

- (void)becomeViewed;
- (void)readIfNecessary;
- (void)readFinishedWithImageRep:(NSImageRep *)aRep;

- (void)removeFromDocument;
- (void)detachFromTree;
- (NSComparisonResult)compare:(PGNode *)node; // Uses the document's sort mode.
- (BOOL)writeToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types;
- (void)addToMenu:(NSMenu *)menu flatten:(BOOL)flatten;

- (PGNode *)ancestorThatIsChildOfNode:(PGNode *)aNode;
- (BOOL)isDescendantOfNode:(PGNode *)aNode;

- (void)identifierIconDidChange:(NSNotification *)aNotif;
- (void)identifierDisplayNameDidChange:(NSNotification *)aNotif;

- (void)noteIsViewableDidChange;

@end
