/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

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
#import "PGExifEntry.h"
@class PGBookmark;

// Controllers
@class PGDisplayController;

extern NSString *const PGDocumentSortedNodesDidChangeNotification;
extern NSString *const PGDocumentNodeIsViewableDidChangeNotification;
extern NSString *const PGDocumentNodeDisplayNameDidChangeNotification;
extern NSString *const PGDocumentBaseOrientationDidChangeNotification;

extern NSString *const PGDocumentNodeKey;
extern NSString *const PGDocumentOldSortedChildrenKey;

@interface PGDocument : PGPrefObject
{
	@private
	PGResourceIdentifier *_identifier;
	PGNode               *_node;
	NSMutableArray       *_cachedNodes;
	PGNode               *_storedNode;
	NSPoint               _storedCenter;
	NSRect                _storedFrame;
	PGResourceIdentifier *_initialIdentifier;
	PGDisplayController  *_displayController;
	NSMenu               *_pageMenu;
	PGOrientation         _baseOrientation;
}

- (id)initWithResourceIdentifier:(PGResourceIdentifier *)ident;
- (id)initWithURL:(NSURL *)aURL;
- (id)initWithBookmark:(PGBookmark *)aBookmark;
- (PGResourceIdentifier *)identifier;
- (PGNode *)node;

- (BOOL)getStoredNode:(out PGNode **)outNode center:(out NSPoint *)outCenter;
- (void)storeNode:(PGNode *)node center:(NSPoint)center;
- (BOOL)getStoredWindowFrame:(out NSRect *)outFrame;
- (void)storeWindowFrame:(NSRect)frame;

- (PGNode *)initialNode;
- (void)setInitialIdentifier:(PGResourceIdentifier *)ident;
- (void)openBookmark:(PGBookmark *)aBookmark;

- (PGDisplayController *)displayController;
- (void)setDisplayController:(PGDisplayController *)controller;

- (NSString *)displayName;
- (void)createUI;
- (void)close;
- (void)validate:(BOOL)knownInvalid;

- (BOOL)isOnline;
- (NSMenu *)pageMenu;

- (PGOrientation)baseOrientation;
- (void)addToBaseOrientation:(PGOrientation)anOrientation;

- (void)noteSortedChildrenOfNodeDidChange:(PGNode *)node oldSortedChildren:(NSArray *)children;
- (void)noteNodeIsViewableDidChange:(PGNode *)node;
- (void)noteNodeDisplayNameDidChange:(PGNode *)node;
- (void)noteNodeDidCache:(PGNode *)node;

@end
