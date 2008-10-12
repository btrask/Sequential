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
#import "PGThumbnailView.h"

#define PGThumbnailSize      48.0
#define PGThumbnailMargin    8.0
#define PGThumbnailSizeTotal (PGThumbnailSize + PGThumbnailMargin)

@implementation PGThumbnailView

#pragma mark Instance Methods

- (id)dataSource
{
	return dataSource;
}
- (void)setDataSource:(id)obj
{
	dataSource = obj;
}
- (id)delegate
{
	return delegate;
}
- (void)setDelegate:(id)obj
{
	delegate = obj;
}
- (id)representedObject
{
	return [[_representedObject retain] autorelease];
}
- (void)setRepresentedObject:(id)obj
{
	if(obj == _representedObject) return;
	[_representedObject release];
	_representedObject = [obj retain];
}

#pragma mark -

- (unsigned)numberOfColumns
{
	return [self numberOfColumnsWithWidth:NSWidth([self bounds])];
}
- (unsigned)numberOfColumnsWithWidth:(unsigned)width
{
	return (width - PGThumbnailMargin) / PGThumbnailSizeTotal;
}

#pragma mark -

- (void)reloadData
{
	[self setFrameSize:NSMakeSize(NSWidth([self frame]), 0)];
	[self setNeedsDisplay:YES];
}

#pragma mark NSView

- (BOOL)isFlipped
{
	return YES;
}
- (void)drawRect:(NSRect)aRect
{
	[[NSColor blueColor] set];
	unsigned i = 0;
	unsigned const count = [[self dataSource] numberOfItemsForThumbnailView:self];
	unsigned const col = [self numberOfColumns];
	for(; i < count; i++) {
		NSImage *const thumb = [[self dataSource] thumbnailView:self thumbnailAtIndex:i];
		[thumb setFlipped:[self isFlipped]];
		[thumb drawInRect:NSMakeRect((i % col) * PGThumbnailSizeTotal + PGThumbnailMargin, (i / col) * PGThumbnailSizeTotal + PGThumbnailMargin, PGThumbnailSize, PGThumbnailSize) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:([[self dataSource] thumbnailView:self canSelectThumbnailAtIndex:i] ? 1.0 : 0.5)];
	}
}
- (void)setFrameSize:(NSSize)aSize
{
	[super setFrameSize:NSMakeSize(aSize.width, ceilf((float)[[self dataSource] numberOfItemsForThumbnailView:self] / [self numberOfColumnsWithWidth:aSize.width]) * PGThumbnailSizeTotal + PGThumbnailMargin)];
}

#pragma mark NSObject

- (void)dealloc
{
	[_representedObject release];
	[super dealloc];
}

@end

@implementation NSObject (PGThumbnailViewDataSource)

- (unsigned)numberOfItemsForThumbnailView:(PGThumbnailView *)sender
{
	return 0;
}
- (NSImage *)thumbnailView:(PGThumbnailView *)sender
             thumbnailAtIndex:(unsigned)index
{
	return nil;
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender
        canSelectThumbnailAtIndex:(unsigned)index
{
	return NO;
}

@end

@implementation NSObject (PGThumbnailViewDelegate)

- (void)thumbnailViewSelectionDidChange:(PGThumbnailView *)sender {}

@end
