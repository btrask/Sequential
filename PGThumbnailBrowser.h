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
#import "PGColumnView.h"

// Views
#import "PGThumbnailView.h"

@interface PGThumbnailBrowser : PGColumnView
{
	@private
	IBOutlet id dataSource;
	IBOutlet id delegate;
}

- (id)dataSource;
- (void)setDataSource:(id)obj; // Should implement PGThumbnailViewDataSource. Get the item for the column with -[sender representedObject].
- (id)delegate;
- (void)setDelegate:(id)obj;

- (NSSet *)selection;
- (void)setSelection:(NSSet *)items;
- (void)setSelectedItem:(id)item;

- (void)reloadData;
- (void)reloadItem:(id)item reloadChildren:(BOOL)flag;

@end

@interface NSObject (PGThumbnailBrowserDataSource)

- (id)thumbnailBrowser:(PGThumbnailBrowser *)sender parentOfItem:(id)item;
- (BOOL)thumbnailBrowser:(PGThumbnailBrowser *)sender itemCanHaveChildren:(id)item;

@end

@interface NSObject (PGThumbnailBrowserDelegate)

- (void)thumbnailBrowserSelectionDidChange:(PGThumbnailBrowser *)sender;

@end
