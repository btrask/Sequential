/* Copyright © 2007-2009, The Sequential Project
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:
    * Redistributions of source code must retain the above copyright
      notice, this list of conditions and the following disclaimer.
    * Redistributions in binary form must reproduce the above copyright
      notice, this list of conditions and the following disclaimer in the
      documentation and/or other materials provided with the distribution.
    * Neither the name of the the Sequential Project nor the
      names of its contributors may be used to endorse or promote products
      derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE SEQUENTIAL PROJECT ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE SEQUENTIAL PROJECT BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "PGColumnView.h"

// Views
#import "PGThumbnailView.h"

@protocol PGThumbnailBrowserDataSource;
@protocol PGThumbnailBrowserDelegate;

@interface PGThumbnailBrowser : PGColumnView <PGThumbnailViewDelegate>
{
	@private
	IBOutlet NSObject<PGThumbnailBrowserDataSource, PGThumbnailViewDataSource> *dataSource;
	IBOutlet NSObject<PGThumbnailBrowserDelegate> *delegate;
	PGOrientation _thumbnailOrientation;
	NSUInteger _updateCount;
}

@property(assign, nonatomic) NSObject<PGThumbnailBrowserDataSource, PGThumbnailViewDataSource> *dataSource;
@property(assign, nonatomic) NSObject<PGThumbnailBrowserDelegate> *delegate;
@property(assign, nonatomic) PGOrientation thumbnailOrientation;
@property(copy, nonatomic) NSSet *selection;

- (void)redisplayItem:(id)item recursively:(BOOL)flag;

@end

@protocol PGThumbnailBrowserDataSource <NSObject>

@optional
- (id)thumbnailBrowser:(PGThumbnailBrowser *)sender parentOfItem:(id)item;
- (BOOL)thumbnailBrowser:(PGThumbnailBrowser *)sender itemCanHaveChildren:(id)item;

@end

@protocol PGThumbnailBrowserDelegate <NSObject>

@optional
- (void)thumbnailBrowserSelectionDidChange:(PGThumbnailBrowser *)sender;
- (void)thumbnailBrowser:(PGThumbnailBrowser *)sender numberOfColumnsDidChangeFrom:(NSUInteger)oldCount;

@end
