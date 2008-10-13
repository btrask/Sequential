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
#import "PGColumnView.h"

// Views
#import "PGClipView.h"

#define PGMinColumnWidth 200

@implementation PGColumnView

#pragma mark Instance Methods

- (NSArray *)views
{
	return [[_views copy] autorelease];
}
- (void)insertColumnWithView:(NSView *)aView
        atIndex:(unsigned)index
{
	NSParameterAssert(aView);
	NSParameterAssert([_views indexOfObjectIdenticalTo:aView] == NSNotFound);
	PGClipView *const clip = [[[PGClipView alloc] init] autorelease];
	[_clipViews insertObject:clip atIndex:index];
	[_views insertObject:aView atIndex:index];
	[_view addSubview:clip];
	[clip setBackgroundColor:[NSColor colorWithDeviceWhite:(48.0f / 255.0f) alpha:0.75f]];
	[clip setShowsBorder:NO];
	[clip setDocumentView:aView];
	[self layout];
	[aView setFrameSize:NSMakeSize(NSWidth([clip bounds]), NSHeight([aView frame]))];
	[aView setAutoresizingMask:NSViewWidthSizable];
}
- (void)removeColumnWithView:(NSView *)aView
{
	NSParameterAssert(aView);
	unsigned const i = [_views indexOfObjectIdenticalTo:aView];
	NSParameterAssert(NSNotFound != i);
	(void)[[aView retain] autorelease];
	PGClipView *const clip = [_clipViews objectAtIndex:i];
	[clip setDocumentView:nil];
	[clip removeFromSuperview];
	[_clipViews removeObjectAtIndex:i];
	[_views removeObjectAtIndex:i];
	[self layout];
}
- (void)removeAllColumns
{
	[_clipViews makeObjectsPerformSelector:@selector(setDocumentView:) withObject:nil];
	[_clipViews makeObjectsPerformSelector:@selector(removeFromSuperview)];
	[_clipViews removeAllObjects];
	[_views removeAllObjects];
	[self layout];
}

#pragma mark -

- (void)layout
{
	NSRect const b = [self bounds];
	float const colWidth = MAX(floorf(NSWidth(b) / [_views count]), PGMinColumnWidth);
	[_view setFrameSize:NSMakeSize(colWidth * [_views count], NSHeight(b))];
	NSRect const vb = [_view bounds];
	unsigned i = 0;
	unsigned const count = [_clipViews count];
	for(; i < count; i++) {
		float const min = NSMinX(vb) + colWidth * i;
		[[_clipViews objectAtIndex:i] setFrame:NSMakeRect(min, NSMinY(vb) + 1, (count - 1 == i ? NSWidth(b) - min : colWidth - 1), NSHeight(vb) - 1)];
	}
}

#pragma mark NSView

- (id)initWithFrame:(NSRect)aRect
{
	if((self = [super initWithFrame:aRect])) {
		_clipView = [[PGClipView alloc] initWithFrame:[self bounds]];
		[_clipView setBackgroundColor:nil];
		[_clipView setShowsBorder:NO];
		[_clipView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[self addSubview:_clipView];
		_view = [[NSView alloc] initWithFrame:NSZeroRect];
		[_clipView setDocumentView:_view];
		_clipViews = [[NSMutableArray alloc] init];
		_views = [[NSMutableArray alloc] init];
	}
	return self;
}
- (void)drawRect:(NSRect)aRect
{
	[[NSColor whiteColor] set];
	NSRectFill(aRect);
}
- (void)setFrameSize:(NSSize)aSize
{
	[super setFrameSize:aSize];
	[self layout];
}

#pragma mark NSObject

- (id)init
{
	return [self initWithFrame:NSZeroRect];
}
- (void)dealloc
{
	[_clipView release];
	[_view release];
	[_clipViews release];
	[_views release];
	[super dealloc];
}

@end
