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

@implementation PGColumnView

#pragma mark Instance Methods

- (unsigned)numberOfColumns
{
	return [_views count];
}
- (NSArray *)views
{
	return [[_views copy] autorelease];
}
- (id)lastView
{
	return [_views lastObject];
}
- (id)viewAtIndex:(unsigned)index
{
	return [_views objectAtIndex:index];
}

#pragma mark -

- (void)addColumnWithView:(NSView *)aView
{
	[self insertColumnWithView:aView atIndex:[_views count]];
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
	[clip setDelegate:self];
	[clip setBackgroundColor:nil];
	[clip setShowsBorder:NO];
	[clip setDocumentView:aView];
	[self layout];
	[aView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
	[aView setFrameSize:NSMakeSize(NSWidth([clip bounds]), NSHeight([aView frame]))];
	[self scrollToTopOfColumnWithView:aView];
}
- (void)removeColumnsAfterView:(NSView *)aView
{
	unsigned const i = aView ? [_views indexOfObject:aView] : 0;
	NSParameterAssert(NSNotFound != i);
	if([_views count] <= i + 1) return;
	while([_views count] > i + 1) {
		PGClipView *const clip = [_clipViews lastObject];
		[clip setDocumentView:nil];
		[clip removeFromSuperview];
		[_clipViews removeLastObject];
		[_views removeLastObject];
	}
	[self layout];
	return;
}

#pragma mark -

- (float)columnWidth
{
	return _columnWidth;
}
- (void)setColumnWidth:(float)width
{
	_columnWidth = roundf(width);
	[self layout];
}

#pragma mark -

- (void)scrollToTopOfColumnWithView:(NSView *)aView
{
	[[_clipViews objectAtIndex:[_views indexOfObjectIdenticalTo:aView]]  scrollToEdge:PGMaxYEdgeMask animation:PGAllowAnimation];
}
- (void)scrollToLastColumnAnimate:(BOOL)flag
{
	[_clipView scrollToEdge:PGMaxXEdgeMask animation:(flag ? PGPreferAnimation : PGNoAnimation)];
}

#pragma mark -

- (void)layout
{
	NSRect const b = [self bounds];
	[_view setFrameSize:NSMakeSize(MAX(_columnWidth * [_views count] - 1, NSWidth(b)), NSHeight(b))];
	NSRect const vb = [_view bounds];
	unsigned i = 0;
	unsigned const count = [_clipViews count];
	for(; i < count; i++) [[_clipViews objectAtIndex:i] setFrame:NSMakeRect(NSMinX(vb) + _columnWidth * i, NSMinY(vb), _columnWidth - 1, NSHeight(vb))];
	[self setNeedsDisplay:YES];
}

#pragma mark PGClipViewDelegate Protocol

- (BOOL)clipView:(PGClipView *)sender
        handleMouseEvent:(NSEvent *)anEvent
        first:(BOOL)flag
{
	unsigned const i = [_clipViews indexOfObjectIdenticalTo:sender];
	if(NSNotFound == i) return NO;
	[[_views objectAtIndex:i] mouseDown:anEvent];
	return YES;
}

#pragma mark NSView

- (id)initWithFrame:(NSRect)aRect
{
	if((self = [super initWithFrame:aRect])) {
		_clipView = [[PGClipView alloc] initWithFrame:[self bounds]];
		[_clipView setBackgroundColor:nil];
		[_clipView setShowsBorder:NO];
		[_clipView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
		[_clipView setPinLocation:PGMinXEdgeMask];
		[self addSubview:_clipView];
		_view = [[NSView alloc] initWithFrame:NSZeroRect];
		[_clipView setDocumentView:_view];
		_clipViews = [[NSMutableArray alloc] init];
		_views = [[NSMutableArray alloc] init];
		_columnWidth = (128.0f + 12.0f) + 1;
	}
	return self;
}
- (void)setFrameSize:(NSSize)aSize
{
	if(NSEqualSizes([self frame].size, aSize)) return;
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
