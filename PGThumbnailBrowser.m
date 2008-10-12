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
#import "PGThumbnailBrowser.h"

// Views
@class PGBezelPanel;
#import "PGThumbnailView.h"

@implementation PGThumbnailBrowser

#pragma mark Instance Methods

- (id)dataSource
{
	return dataSource;
}
- (void)setDataSource:(id)obj
{
	dataSource = obj;
}

#pragma mark -

- (void)reloadData
{
	[self removeAllColumns];
	PGThumbnailView *const thumbnailView = [[[PGThumbnailView alloc] init] autorelease];
	[thumbnailView setDataSource:self];
	[thumbnailView setDelegate:self];
	[thumbnailView setRepresentedObject:nil];
	[self insertColumnWithView:thumbnailView atIndex:0];
	[thumbnailView reloadData];
}
- (void)reloadChildrenOfItem:(id)item
{
}
- (void)reloadChildOfItem:(id)item
        atIndex:(unsigned)index
{
}

#pragma mark PGThumbnailViewDataSource Protocol

- (unsigned)numberOfItemsForThumbnailView:(PGThumbnailView *)sender
{
	return [[self dataSource] browser:self numberOfChildrenOfItem:[sender representedObject]];
}
- (NSImage *)thumbnailView:(PGThumbnailView *)sender
             thumbnailAtIndex:(unsigned)index
{
	return [[self dataSource] browser:self thumbnailForChildOfItem:[sender representedObject] atIndex:index];
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender
        canSelectThumbnailAtIndex:(unsigned)index
{
	return [[self dataSource] browser:self canSelectorChildOfItem:[sender representedObject] atIndex:index];
}

#pragma mark PGBezelPanelContentView Protocol

- (NSRect)bezelPanel:(PGBezelPanel *)sender
          frameForContentRect:(NSRect)aRect
          scale:(float)scaleFactor
{
	return NSMakeRect(NSMinX(aRect), NSMaxY(aRect) - 300, NSWidth(aRect), 300);
}

@end

@implementation NSObject (PGThumbnailBrowserDataSource)

- (unsigned)browser:(PGThumbnailBrowser *)sender
            numberOfChildrenOfItem:(id)item
{
	return 0;
}
- (id)browser:(PGThumbnailBrowser *)sender
      childOfItem:(id)item
      atIndex:(unsigned)index
{
	return nil;
}
- (NSImage *)browser:(PGThumbnailBrowser *)sender
             thumbnailForChildOfItem:(id)item
             atIndex:(unsigned)index
{
	return nil;
}
- (BOOL)browser:(PGThumbnailBrowser *)sender
        canSelectorChildOfItem:(id)item
        atIndex:(unsigned)index
{
	return NO;
}

@end
