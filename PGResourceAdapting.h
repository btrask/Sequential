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

// Models
@class PGDocument;
@class PGNode;
@class PGContainerAdapter;
@class PGResourceIdentifier;
#import "PGExifEntry.h"
@class PGBookmark;

enum {
	PGWrongPassword   = -1,
	PGDataUnavailable = 0,
	PGDataAvailable   = 1
};
typedef int PGDataAvailability;

@protocol PGResourceAdapting

- (PGContainerAdapter *)parentAdapter;
- (PGContainerAdapter *)containerAdapter;
- (PGContainerAdapter *)rootContainerAdapter;
- (PGDocument *)document;
- (PGNode *)parentNode;

- (PGResourceIdentifier *)identifier;
- (id)dataSource;

- (BOOL)isViewable;
- (float)loadingProgress;
- (BOOL)canGetImageData;
- (PGDataAvailability)getImageData:(out NSData **)outData;
- (NSArray *)exifEntries;
- (PGOrientation)orientation; // Incorporates the document's -baseOrientation.
- (BOOL)isResolutionIndependent;
- (void)clearCache;
- (BOOL)isContainer;

- (NSString *)lastPassword;
- (BOOL)expectsReturnedImage;
- (void)returnImage:(NSImage *)anImage error:(NSError *)error;

- (BOOL)hasViewableNodes;
- (BOOL)hasImageDataNodes; // Nodes that return YES from -canGetImageData.
- (unsigned)viewableNodeIndex;
- (unsigned)viewableNodeCount;

- (PGNode *)sortedViewableNodeFirst:(BOOL)flag;
- (PGNode *)sortedViewableNodeFirst:(BOOL)flag stopAtNode:(PGNode *)descendent;
- (PGNode *)sortedViewableNodeNext:(BOOL)flag;
- (PGNode *)sotedFirstViewableNodeInFolderNext:(BOOL)flag;
- (PGNode *)sortedFirstViewableNodeInFolderFirst:(BOOL)flag;

- (PGNode *)nodeForIdentifier:(PGResourceIdentifier *)ident;
- (PGNode *)ancestorThatIsChildOfNode:(PGNode *)aNode;
- (BOOL)isDescendantOfNode:(PGNode *)aNode;

- (NSDate *)dateModified;
- (NSDate *)dateCreated;
- (NSNumber *)dataLength;

- (void)addMenuItemsToMenu:(NSMenu *)aMenu;

- (char const *)unencodedSampleString;
- (NSStringEncoding)defaultEncoding;
- (void)setEncoding:(NSStringEncoding)encoding;

- (BOOL)canBookmark;
- (PGBookmark *)bookmark;

- (void)sortOrderDidChange;

@end
