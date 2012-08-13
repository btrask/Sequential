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
// Models
@class PGDocument;

// Views
@class PGBezelPanel;
#import "PGThumbnailBrowser.h"

// Controllers
#import "PGDisplayController.h"

// Other Sources
#import "PGGeometryTypes.h"

extern NSString *const PGThumbnailControllerContentInsetDidChangeNotification;

@interface PGThumbnailController : NSObject <
#ifdef MAC_OS_X_VERSION_10_6
NSWindowDelegate,
#endif
PGThumbnailBrowserDataSource, PGThumbnailBrowserDelegate, PGThumbnailViewDataSource>
{
	@private
	PGBezelPanel *_window;
	PGThumbnailBrowser *_browser;
	PGDisplayController *_displayController;
	PGDocument *_document;
	BOOL _selfRetained;
}

+ (BOOL)canShowThumbnailsForDocument:(PGDocument *)aDoc;
+ (BOOL)shouldShowThumbnailsForDocument:(PGDocument *)aDoc;

@property(assign, nonatomic) PGDisplayController *displayController;
@property(assign, nonatomic) PGDocument *document;
@property(readonly) PGInset contentInset;
@property(readonly) NSSet *selectedNodes;

- (void)display;
- (void)fadeOut;

- (void)displayControllerActiveNodeDidChange:(NSNotification *)aNotif;
- (void)displayControllerActiveNodeWasRead:(NSNotification *)aNotif;
- (void)clipViewBoundsDidChange:(NSNotification *)aNotif;
- (void)parentWindowDidResize:(NSNotification *)aNotif;
- (void)parentWindowWillBeginSheet:(NSNotification *)aNotif;
- (void)parentWindowDidEndSheet:(NSNotification *)aNotif;

- (void)documentNodeThumbnailDidChange:(NSNotification *)aNotif;
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif;
- (void)documentSortedNodesDidChange:(NSNotification *)aNotif;
- (void)documentNodeIsViewableDidChange:(NSNotification *)aNotif;

@end

@interface PGDisplayController(PGThumbnailControllerCallbacks)

- (void)thumbnailPanelDidBecomeKey:(NSNotification *)aNotif;
- (void)thumbnailPanelDidResignKey:(NSNotification *)aNotif;

@end
