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

@interface PGNode : NSObject
{
	@private
	PGContainerAdapter   *_parentAdapter;
	PGDocument           *_document;

	PGResourceIdentifier *_identifier;
	NSMutableArray       *_URLs;
	NSData               *_data;
	id                    _dataSource;

	NSString             *_password;

	NSMenuItem           *_menuItem;
	BOOL                  _allowMenuItemUpdates; // Just an optimization.
	BOOL                  _viewable;
	BOOL                  _loading;
	NSError              *_loadError;

	BOOL                  _shouldRead;

	PGResourceAdapter    *_resourceAdapter;

	NSDate               *_dateModified;
	NSDate               *_dateCreated;
	NSNumber             *_dataLength;
}

- (id)initWithParentAdapter:(PGContainerAdapter *)parent document:(PGDocument *)doc identifier:(PGResourceIdentifier *)ident;

- (BOOL)canGetData;
- (void)setData:(NSData *)data;
- (id)dataSource;
- (void)setDataSource:(id)anObject;
- (PGDataError)getData:(out NSData **)outData;

- (PGResourceAdapter *)resourceAdapter;
- (void)setResourceAdapterClass:(Class)aClass;
- (Class)classWithInfo:(NSDictionary *)info;
- (BOOL)shouldLoadAdapterClass:(Class)aClass;
- (void)setLoadError:(NSError *)error;
- (void)loadFinished;
- (void)becomeViewed;
- (void)readIfNecessary;
- (void)readFinishedWithImageRep:(NSImageRep *)aRep error:(NSError *)error;

- (NSString *)password;
- (void)setPassword:(NSString *)password;

- (unsigned)depth;
- (BOOL)isRooted;
- (NSMenuItem *)menuItem;
- (BOOL)isViewable;

- (void)removeFromDocument;

- (NSDate *)dateModified;
- (NSDate *)dateCreated;
- (NSNumber *)dataLength;
- (NSComparisonResult)compare:(PGNode *)node; // Uses the document's sort mode.

- (BOOL)canBookmark;
- (PGBookmark *)bookmark;

- (void)identifierDidChange:(NSNotification *)aNotif;

@end

@interface PGNode (PGResourceAdapterProxy) <PGResourceAdapting>
@end

@interface NSObject (PGNodeDataSource)

- (Class)classForNode:(PGNode *)sender;
- (NSDate *)dateModifiedForNode:(PGNode *)sender;
- (NSDate *)dateCreatedForNode:(PGNode *)sender;
- (NSNumber *)dataLengthForNode:(PGNode *)sender;
- (NSData *)dataForNode:(PGNode *)sender; // If a problem occurred, the data source should send -setLoadError: and return nil.

@end
