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
#import "PGZooming.h"

// Categories
#import "NSWindowAdditions.h"

@implementation NSWindow (PGZooming)

#pragma mark Instance Methods

- (IBAction)PG_grow:(id)sender
{
	if(!([self styleMask] & NSResizableWindowMask)) return;
	NSRect const s = [[self screen] visibleFrame];
	NSRect z = [[self delegate] respondsToSelector:@selector(windowWillUseStandardFrame:defaultFrame:)] ? [[self delegate] windowWillUseStandardFrame:self defaultFrame:s] : s;
	NSRect const f = [self frame];
	if(NSWidth(z) < NSWidth(f)) z.size.width = NSWidth(f);
	if(NSHeight(z) < NSHeight(f)) {
		z.origin.y -= NSHeight(f) - NSHeight(z);
		z.size.height = NSHeight(f);
	}
	[self setFrame:[self PG_constrainedFrameRect:z] display:YES];
}

#pragma mark -

- (NSRect)PG_zoomedFrame
{
	NSRect f = [self contentRectForFrameRect:[self frame]];
	NSSize s = [[self contentView] PG_zoomedFrameSize];
	s.width /= [self AE_userSpaceScaleFactor];
	s.height /= [self AE_userSpaceScaleFactor];
	f.origin.y += NSHeight(f) - s.height;
	f.size = s;
	return [self PG_constrainedFrameRect:[self frameRectForContentRect:f]];
}
- (NSRect)PG_constrainedFrameRect:(NSRect)aRect
{
	NSRect const b = [[self screen] visibleFrame];
	NSRect r = aRect;
	r.size.width = MIN(MAX(MIN(NSWidth(r), NSWidth(b)), [self minSize].width), [self maxSize].width);
	r.size.height = MIN(MAX(MIN(NSHeight(r), NSHeight(b)), [self minSize].height), [self maxSize].height);
	r.origin.y += NSHeight(aRect) - NSHeight(r);
	r.origin.x -= MAX(NSMaxX(r) - NSMaxX(b), 0);
	r.origin.y += MAX(NSMinY(b) - NSMinY(r), 0);
	r.origin.x += MAX(NSMinX(b) - NSMinX(r), 0);
	r.origin.y -= MAX(NSMaxY(r) - NSMaxY(b), 0);
	return r;
}

@end

@implementation NSView (PGZooming)

- (NSSize)PG_zoomedFrameSize
{
	return [[self window] contentView] == self ? [self PG_zoomedBoundsSize] : [self convertSize:[self PG_zoomedBoundsSize] toView:[self superview]];
}
- (NSSize)PG_zoomedBoundsSize
{
	NSSize size = NSZeroSize;
	NSRect const bounds = [self bounds];
	NSView *subview;
	NSEnumerator *const subviewEnum = [[self subviews] objectEnumerator];
	while((subview = [subviewEnum nextObject])) {
		NSSize s = [subview PG_zoomedFrameSize];
		unsigned const m = [subview autoresizingMask];
		NSRect const f = [subview frame];
		if(!(m & NSViewWidthSizable)) s.width = NSWidth(f);
		if(!(m & NSViewHeightSizable)) s.height = NSHeight(f);
		if(!(m & NSViewMinXMargin)) s.width += MAX(NSMinX(f), 0);
		if(!(m & NSViewMinYMargin)) s.height += MAX(NSMinY(f), 0);
		if(!(m & NSViewMaxXMargin) && m & (NSViewMinXMargin | NSViewWidthSizable)) s.width += MAX(NSMaxX(bounds) - NSMaxX(f), 0);
		if(!(m & NSViewMaxYMargin) && m & (NSViewMinYMargin | NSViewHeightSizable)) s.height += MAX(NSMaxY(bounds) - NSMaxY(f), 0);
		size.width = MAX(size.width, s.width);
		size.height = MAX(size.height, s.height);
	}
	return size;
}

@end

@implementation NSTextField (PGZooming)

- (NSSize)PG_zoomedBoundsSize
{
	return [[self cell] cellSizeForBounds:NSMakeRect(0, 0, [self autoresizingMask] & NSViewWidthSizable ? FLT_MAX : NSWidth([self bounds]), FLT_MAX)];
}

@end

@implementation NSScrollView (PGZooming)

- (NSSize)PG_zoomedBoundsSize
{
	NSSize const s = [self convertSize:[[self documentView] PG_zoomedFrameSize] fromView:[self contentView]];
	NSRect const c = [[self contentView] frame];
	NSRect const b = [self bounds];
	return NSMakeSize(s.width + NSMinX(c) + NSMaxX(b) - NSMaxX(c), s.height + NSMinY(c) + NSMaxY(b) - NSMaxY(c));
}

@end

@implementation NSTableView (PGZooming)

- (NSSize)PG_zoomedBoundsSize
{
	float totalWidth = 0;
	NSArray *const columns = [self tableColumns];
	BOOL const resizesAllColumns = [self respondsToSelector:@selector(columnAutoresizingStyle)] ? NSTableViewUniformColumnAutoresizingStyle == [self columnAutoresizingStyle] : [self autoresizesAllColumnsToFit];
	if(resizesAllColumns) {
		NSTableColumn *column;
		NSEnumerator *const columnEnum = [columns objectEnumerator];
		while((column = [columnEnum nextObject])) {
			float const width = [column PG_zoomedWidth];
			[column setWidth:width];
			totalWidth += width;
		}
	} else {
		unsigned i = 0;
		for(; i < [columns count] - 1; i++) totalWidth += NSWidth([self rectOfColumn:i]);
		totalWidth += [[columns lastObject] PG_zoomedWidth];
	}
	return NSMakeSize(totalWidth, NSMaxY([self rectOfRow:[self numberOfRows] - 1]));
}

@end

@implementation NSTableColumn (PGZooming)

- (float)PG_zoomedWidth
{
	float width = 0;
	int i = 0;
	for(; i < [[self tableView] numberOfRows]; i++) {
		NSCell *const cell = [self dataCellForRow:i];
		[cell setObjectValue:[[[self tableView] dataSource] tableView:[self tableView] objectValueForTableColumn:self row:i]];
		width = MAX(width, [cell cellSizeForBounds:NSMakeRect(0, 0, FLT_MAX, FLT_MAX)].width);
	}
	return MIN(MAX(ceilf(width + 3), [self minWidth]), [self maxWidth]);
}

@end
