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
@class PGDocument;
@class PGResourceAdapter;
@class PGContainerAdapter;
@class PGResourceIdentifier;

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

typedef unsigned PGNodeStatus;

@interface PGNode : NSObject
{
	@private
	PGContainerAdapter   *_parentAdapter;
	PGDocument           *_document;

	PGResourceIdentifier *_identifier;
	id                    _dataSource;

	NSMutableArray       *_adapters;
	PGResourceAdapter    *_adapter;
	PGNodeStatus          _status;
	NSError              *_error;
	PGNodeStatus          _errorPhase;

	BOOL                  _viewable;
	NSMenuItem           *_menuItem;
	BOOL                  _allowMenuItemUpdates; // Just an optimization.

	NSDate               *_dateModified;
	NSDate               *_dateCreated;
	NSNumber             *_dataLength;
}

- (id)initWithParentAdapter:(PGContainerAdapter *)parent document:(PGDocument *)doc identifier:(PGResourceIdentifier *)ident dataSource:(id)dataSource;

- (id)dataSource;
- (NSData *)dataWithInfo:(NSDictionary *)info fast:(BOOL)flag;
- (BOOL)canGetDataWithInfo:(NSDictionary *)info;

- (PGResourceAdapter *)resourceAdapter;
- (PGLoadPolicy)ancestorLoadPolicy;
- (BOOL)shouldLoadAdapterClass:(Class)aClass;
- (void)startLoadWithInfo:(id)info;
- (void)continueLoadWithInfo:(id)info;
- (void)loadFinished;

- (void)becomeViewed;
- (void)readIfNecessary;
- (void)readFinishedWithImageRep:(NSImageRep *)aRep error:(NSError *)error;

- (NSError *)error;
- (void)setError:(NSError *)error;

- (NSImage *)thumbnail;

- (BOOL)isViewable;
- (unsigned)depth;
- (PGNode *)viewableAncestor;
- (NSMenuItem *)menuItem;

- (void)removeFromDocument;
- (void)detachFromTree;

- (NSDate *)dateModified;
- (NSDate *)dateCreated;
- (NSNumber *)dataLength;
- (NSComparisonResult)compare:(PGNode *)node; // Uses the document's sort mode.

- (BOOL)canBookmark;
- (PGBookmark *)bookmark;

- (void)identifierIconDidChange:(NSNotification *)aNotif;
- (void)identifierDisplayNameDidChange:(NSNotification *)aNotif;

@end

@interface PGNode (PGResourceAdapterProxy) <PGResourceAdapting>
@end

@interface NSObject (PGNodeDataSource)

- (NSDate *)dateModifiedForNode:(PGNode *)sender;
- (NSDate *)dateCreatedForNode:(PGNode *)sender;
- (NSNumber *)dataLengthForNode:(PGNode *)sender;
- (void)node:(PGNode *)sender willLoadWithInfo:(NSMutableDictionary *)info;
- (BOOL)node:(PGNode *)sender getData:(out NSData **)outData info:(NSDictionary *)info fast:(BOOL)flag; // Return NO if a problem occurred. Implementations must be thread-safe.

@end
