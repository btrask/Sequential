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
#import "PGDisplayController.h"
#import <unistd.h>

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGContainerAdapter.h"
#import "PGGenericImageAdapter.h"
#import "PGResourceIdentifier.h"

// Views
#import "PGDocumentWindow.h"
#import "PGClipView.h"
#import "PGImageView.h"
#import "PGBezelPanel.h"
#import "PGAlertView.h"
#import "PGInfoView.h"
#import "PGFindView.h"
#import "PGThumbnailBrowser.h"

// Controllers
#import "PGDocumentController.h"
#import "PGPrefController.h"
#import "PGBookmarkController.h"
#import "PGExtractAlert.h"
#import "PGEncodingAlert.h"

// Other
#import "PGGeometry.h"
#import "PGKeyboardLayout.h"
#import "PGNonretainedObjectProxy.h"

// Categories
#import "NSControlAdditions.h"
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGDisplayControllerActiveNodeDidChangeNotification = @"PGDisplayControllerActiveNodeDidChange";
NSString *const PGDisplayControllerTimerDidChangeNotification      = @"PGDisplayControllerTimerDidChange";

#define PGScaleMax      16.0f
#define PGScaleMin      (1.0f / 8.0f)
#define PGWindowMinSize 400.0f

static inline NSSize PGConstrainSize(NSSize min, NSSize size, NSSize max)
{
	return NSMakeSize(MIN(MAX(min.width, size.width), max.width), MIN(MAX(min.height, size.height), max.height));
}

@interface PGDisplayController (Private)

- (void)_setImageView:(PGImageView *)aView;
- (BOOL)_setActiveNode:(PGNode *)aNode;
- (void)_readActiveNode;
- (void)_readFinished;
- (NSSize)_sizeForImageRep:(NSImageRep *)rep orientation:(PGOrientation)orientation;
- (void)_updateImageViewSizeAllowAnimation:(BOOL)flag;
- (void)_noteViewableNodeCountDidChange;
- (void)_updateNodeIndex;
- (void)_updateInfoPanelText;
- (void)_runTimer;

@end

@implementation PGDisplayController

#pragma mark Class Methods

+ (NSArray *)pasteboardTypes
{
	return [NSArray arrayWithObjects:NSStringPboardType, NSTIFFPboardType, NSRTFDPboardType, NSFileContentsPboardType, nil];
}

#pragma mark NSObject

+ (void)initialize
{
	[NSApp registerServicesMenuSendTypes:[self pasteboardTypes] returnTypes:[NSArray array]];
}
- (NSUserDefaultsController *)userDefaults
{
	return [NSUserDefaultsController sharedUserDefaultsController];
}

#pragma mark Instance Methods

- (IBAction)revealInPathFinder:(id)sender
{
	if(![[[[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"tell application \"Path Finder\"\nactivate\nreveal \"%@\"\nend tell", [[[[self activeNode] identifier] superURLByFollowingAliases:NO] path]]] autorelease] executeAndReturnError:NULL]) NSBeep();
}
- (IBAction)revealInFinder:(id)sender
{
	if(![[NSWorkspace sharedWorkspace] selectFile:[[[[self activeNode] identifier] superURLByFollowingAliases:NO] path] inFileViewerRootedAtPath:nil]) NSBeep();
}
- (IBAction)revealInBrowser:(id)sender
{
	if(![[NSWorkspace sharedWorkspace] openURL:[[[self activeDocument] identifier] superURLByFollowingAliases:NO]]) NSBeep();
}
- (IBAction)extractImages:(id)sender
{
	[[[[PGExtractAlert alloc] initWithRoot:[[self activeDocument] node] initialNode:[self activeNode]] autorelease] beginSheetForWindow:nil];
}
- (IBAction)moveToTrash:(id)sender
{
	int tag;
	NSString *const path = [[[[self activeNode] identifier] URL] path];
	if(![[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[path stringByDeletingLastPathComponent] destination:@"" files:[NSArray arrayWithObject:[path lastPathComponent]] tag:&tag] || tag < 0) NSBeep();
}

#pragma mark -

- (IBAction)copy:(id)sender
{
	if(![self writeSelectionToPasteboard:[NSPasteboard generalPasteboard] types:[[self class] pasteboardTypes]]) NSBeep();
}
- (IBAction)changeOrientation:(id)sender
{
	[[self activeDocument] setBaseOrientation:PGAddOrientation([[self activeDocument] baseOrientation], [sender tag])];
}
- (IBAction)revertOrientation:(id)sender
{
	[[self activeDocument] setBaseOrientation:PGUpright];
}
- (IBAction)performFindPanelAction:(id)sender
{
	switch([sender tag]) {
		case NSFindPanelActionShowFindPanel:
			[self setFindPanelShown:!([self findPanelShown] && [_findPanel isKeyWindow])];
			break;
		case NSFindPanelActionNext:
		case NSFindPanelActionPrevious:
		{
			NSArray *const terms = [[searchField stringValue] AE_searchTerms];
			if(terms && [terms count] && ![self tryToSetActiveNode:[[self activeNode] sortedViewableNodeNext:([sender tag] == NSFindPanelActionNext) matchSearchTerms:terms] initialLocation:PGHomeLocation]) NSBeep();
			break;
		}
		default:
			NSBeep();
	}
	if([_findPanel isKeyWindow]) [_findPanel makeFirstResponder:searchField];
}
- (IBAction)hideFindPanel:(id)sender
{
	[self setFindPanelShown:NO];
}

#pragma mark -

- (IBAction)toggleFullscreen:(id)sender
{
	[[PGDocumentController sharedDocumentController] setFullscreen:![[PGDocumentController sharedDocumentController] fullscreen]];
}
- (IBAction)toggleInfo:(id)sender
{
	[[self activeDocument] setShowsInfo:![[self activeDocument] showsInfo]];
}
- (IBAction)toggleThumbnails:(id)sender
{
	[[self activeDocument] setShowsThumbnails:![[self activeDocument] showsThumbnails]];
}

#pragma mark -

- (IBAction)zoomIn:(id)sender
{
	PGDocument *const doc = [self activeDocument];
	[doc setImageScaleFactor:MIN(PGScaleMax, [_imageView averageScaleFactor] * 2)];
	[doc setImageScalingMode:PGConstantFactorScaling];
}
- (IBAction)zoomOut:(id)sender
{
	PGDocument *const doc = [self activeDocument];
	[doc setImageScaleFactor:MAX(PGScaleMin, [_imageView averageScaleFactor] / 2)];
	[doc setImageScalingMode:PGConstantFactorScaling];
}

#pragma mark -

- (IBAction)previousPage:(id)sender
{
	[self tryToGoForward:NO allowAlerts:YES];
}
- (IBAction)nextPage:(id)sender
{
	[self tryToGoForward:YES allowAlerts:YES];
}

- (IBAction)firstPage:(id)sender
{
	[self setActiveNode:[[[self activeDocument] node] sortedViewableNodeFirst:YES] initialLocation:PGHomeLocation];
}
- (IBAction)lastPage:(id)sender
{
	[self setActiveNode:[[[self activeDocument] node] sortedViewableNodeFirst:NO] initialLocation:PGEndLocation];
}

#pragma mark -

- (IBAction)skipBeforeFolder:(id)sender
{
	if([self tryToSetActiveNode:[[[self activeNode] containerAdapter] sortedViewableNodeNext:NO includeChildren:NO] initialLocation:PGEndLocation]) return;
	[self prepareToLoop];
	[self tryToLoopForward:NO toNode:[[[self activeDocument] node] sortedViewableNodeFirst:NO] initialLocation:PGEndLocation allowAlerts:YES];
}
- (IBAction)skipPastFolder:(id)sender
{
	if([self tryToSetActiveNode:[[[self activeNode] containerAdapter] sortedViewableNodeNext:YES includeChildren:NO] initialLocation:PGHomeLocation]) return;
	[self prepareToLoop];
	[self tryToLoopForward:YES toNode:[[[self activeDocument] node] sortedViewableNodeFirst:YES] initialLocation:PGHomeLocation allowAlerts:YES];
}
- (IBAction)firstOfPreviousFolder:(id)sender
{
	if([self tryToSetActiveNode:[[self activeNode] sotedFirstViewableNodeInFolderNext:NO] initialLocation:PGHomeLocation]) return;
	[self prepareToLoop];
	[self tryToLoopForward:NO toNode:[[[[[self activeDocument] node] sortedViewableNodeFirst:NO] containerAdapter] sortedViewableNodeFirst:YES] initialLocation:PGHomeLocation allowAlerts:YES];
}
- (IBAction)firstOfNextFolder:(id)sender
{
	if([self tryToSetActiveNode:[[self activeNode] sotedFirstViewableNodeInFolderNext:YES] initialLocation:PGHomeLocation]) return;
	[self prepareToLoop];
	[self tryToLoopForward:YES toNode:[[[self activeDocument] node] sortedViewableNodeFirst:YES] initialLocation:PGHomeLocation allowAlerts:YES];
}
- (IBAction)firstOfFolder:(id)sender
{
	[self setActiveNode:[[[self activeNode] containerAdapter] sortedViewableNodeFirst:YES] initialLocation:PGHomeLocation];
}
- (IBAction)lastOfFolder:(id)sender
{
	[self setActiveNode:[[[self activeNode] containerAdapter] sortedViewableNodeFirst:NO] initialLocation:PGEndLocation];
}

#pragma mark -

- (IBAction)jumpToPage:(id)sender
{
	PGNode *node = [[sender representedObject] PG_nonretainedObjectValue];
	if(![node isViewable]) node = [node sortedViewableNodeFirst:YES];
	if([self activeNode] == node || !node) return;
	[self setActiveNode:node initialLocation:PGHomeLocation];
}

#pragma mark -

- (IBAction)pauseDocument:(id)sender
{
	[[PGBookmarkController sharedBookmarkController] addBookmark:[[self activeNode] bookmark]];
}
- (IBAction)pauseAndCloseDocument:(id)sender
{
	[self pauseDocument:sender];
	[[self activeDocument] close];
}

#pragma mark -

- (IBAction)reload:(id)sender
{
	[reloadButton setEnabled:NO];
	[[self activeNode] startLoadWithInfo:nil];
	[self _readActiveNode];
}
- (IBAction)decrypt:(id)sender
{
	PGNode *const activeNode = [self activeNode];
	[activeNode AE_addObserver:self selector:@selector(nodeLoadingDidProgress:) name:PGNodeLoadingDidProgressNotification];
	[activeNode AE_addObserver:self selector:@selector(nodeReadyForViewing:) name:PGNodeReadyForViewingNotification];
	[[activeNode info] setObject:[passwordField stringValue] forKey:PGPasswordKey];
	[activeNode becomeViewed];
}
- (IBAction)chooseEncoding:(id)sender
{
	NSDictionary *const errInfo = [[[self activeNode] error] userInfo];
	PGEncodingAlert *const alert = [[[PGEncodingAlert alloc] initWithStringData:[errInfo objectForKey:PGUnencodedStringDataKey] guess:[[errInfo objectForKey:PGDefaultEncodingKey] unsignedIntValue]] autorelease];
	[alert beginSheetForWindow:nil withDelegate:self];
}

#pragma mark -

- (PGDocument *)activeDocument
{
	return _activeDocument;
}
- (BOOL)setActiveDocument:(PGDocument *)document
        closeIfAppropriate:(BOOL)flag
{
	if(document == _activeDocument) return NO;
	if(_activeDocument) {
		if(_reading) [_imageView setImageRep:nil orientation:PGUpright size:NSZeroSize];
		[_activeDocument storeNode:[self activeNode] imageView:_imageView offset:[clipView pinLocationOffset] query:[searchField stringValue]];
		[self _setImageView:nil];
		[_activeDocument AE_removeObserver:self name:PGDocumentWillRemoveNodesNotification];
		[_activeDocument AE_removeObserver:self name:PGDocumentSortedNodesDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGDocumentNodeDisplayNameDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGDocumentNodeIsViewableDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGDocumentNodeThumbnailDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGDocumentBaseOrientationDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGPrefObjectShowsInfoDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGPrefObjectShowsThumbnailsDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGPrefObjectReadingDirectionDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGPrefObjectImageScaleDidChangeNotification];
	}
	if(flag && !document && _activeDocument) {
		_activeDocument = nil;
		[[self retain] autorelease]; // Necessary if the find panel is open.
		[[self window] close];
		return YES;
	}
	_activeDocument = document;
	if([[self window] isMainWindow]) [[PGDocumentController sharedDocumentController] setCurrentDocument:_activeDocument];
	[_activeDocument AE_addObserver:self selector:@selector(documentWillRemoveNodes:) name:PGDocumentWillRemoveNodesNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentSortedNodesDidChange:) name:PGDocumentSortedNodesDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentNodeDisplayNameDidChange:) name:PGDocumentNodeDisplayNameDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentNodeIsViewableDidChange:) name:PGDocumentNodeIsViewableDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentNodeThumbnailDidChange:) name:PGDocumentNodeThumbnailDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentBaseOrientationDidChange:) name:PGDocumentBaseOrientationDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentShowsInfoDidChange:) name:PGPrefObjectShowsInfoDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentShowsThumbnailsDidChange:) name:PGPrefObjectShowsThumbnailsDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentReadingDirectionDidChange:) name:PGPrefObjectReadingDirectionDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentImageScaleDidChange:) name:PGPrefObjectImageScaleDidChangeNotification];
	[self setTimerInterval:0];
	if(_activeDocument) {
		NSDisableScreenUpdates();
		if(![self shouldShowThumbnails]) [_thumbnailPanel close];
		[self documentShowsThumbnailsDidChange:nil];
		PGNode *node;
		PGImageView *view;
		NSSize offset;
		NSString *query;
		[_activeDocument getStoredNode:&node imageView:&view offset:&offset query:&query];
		[self _setImageView:view];
		if([view rep]) {
			[self _setActiveNode:node];
			[clipView setDocumentView:view];
			[view setImageRep:[view rep] orientation:[view orientation] size:[self _sizeForImageRep:[view rep] orientation:[view orientation]]];
			[clipView scrollPinLocationToOffset:offset];
			[self _readFinished];
		} else {
			[clipView setDocumentView:view];
			[self setActiveNode:node initialLocation:PGHomeLocation];
		}
		[searchField setStringValue:query];
		[self documentReadingDirectionDidChange:nil];
		[self documentShowsInfoDidChange:nil];
		NSEnableScreenUpdates();
	}
	return NO;
}
- (void)activateDocument:(PGDocument *)document
{
	[self setActiveDocument:document closeIfAppropriate:NO];
	[[self window] makeKeyAndOrderFront:self];
}

#pragma mark -

- (PGNode *)activeNode
{
	return [[_activeNode retain] autorelease];
}
- (void)setActiveNode:(PGNode *)aNode
        initialLocation:(PGPageLocation)location
{
	if(![self _setActiveNode:aNode]) return;
	_initialLocation = location;
	[self _readActiveNode];
}
- (BOOL)tryToSetActiveNode:(PGNode *)aNode
        initialLocation:(PGPageLocation)location
{
	if(!aNode) return NO;
	[self setActiveNode:aNode initialLocation:location];
	return YES;
}
- (BOOL)tryToGoForward:(BOOL)forward
        allowAlerts:(BOOL)flag
{
	PGPageLocation const l = forward ? PGHomeLocation : PGEndLocation;
	if([self tryToSetActiveNode:[[self activeNode] sortedViewableNodeNext:forward] initialLocation:l]) return YES;
	[self prepareToLoop];
	return [self tryToLoopForward:forward toNode:[[[self activeDocument] node] sortedViewableNodeFirst:forward] initialLocation:l allowAlerts:flag];
}
- (void)prepareToLoop
{
	PGSortOrder const o = [[self activeDocument] sortOrder];
	if(!(PGSortRepeatMask & o) || (PGSortOrderMask & o) != PGSortShuffle) return;
	PGDocument *const doc = [self activeDocument];
	[[doc node] noteSortOrderDidChange]; // Reshuffle.
	[doc noteSortedChildrenDidChange];
}
- (BOOL)tryToLoopForward:(BOOL)forward
        toNode:(PGNode *)node
	initialLocation:(PGPageLocation)loc
        allowAlerts:(BOOL)flag
{
	PGDocument *const doc = [self activeDocument];
	BOOL const left = ([doc readingDirection] == PGReadingDirectionLeftToRight) == !forward;
	PGSortOrder const o = [[self activeDocument] sortOrder];
	if(PGSortRepeatMask & o && [self tryToSetActiveNode:node initialLocation:loc]) {
		if(flag) [[_graphicPanel content] pushGraphic:(left ? [PGAlertGraphic loopedLeftGraphic] : [PGAlertGraphic loopedRightGraphic]) window:[self window]];
		return YES;
	}
	if(flag) [[_graphicPanel content] pushGraphic:(left ? [PGAlertGraphic cannotGoLeftGraphic] : [PGAlertGraphic cannotGoRightGraphic]) window:[self window]];
	return NO;
}
- (void)activateNode:(PGNode *)node
{
	[self setActiveDocument:[node document] closeIfAppropriate:NO];
	[self setActiveNode:node initialLocation:PGHomeLocation];
}

#pragma mark -

- (BOOL)canShowInfo
{
	return YES;
}
- (BOOL)shouldShowInfo
{
	return [[self activeDocument] showsInfo] && [self canShowInfo];
}
- (BOOL)canShowThumbnails
{
	return [[[self activeDocument] node] hasViewableNodeCountGreaterThan:1];
}
- (BOOL)shouldShowThumbnails
{
	return [[self activeDocument] showsThumbnails] && [self canShowThumbnails];
}

#pragma mark -

- (BOOL)loadingIndicatorShown
{
	return _loadingGraphic != nil;
}
- (void)showLoadingIndicator
{
	if(_loadingGraphic) return;
	_loadingGraphic = [[PGLoadingGraphic loadingGraphic] retain];
	[_loadingGraphic setProgress:[[self activeNode] loadProgress]];
	[[_graphicPanel content] pushGraphic:_loadingGraphic window:[self window]];
}

#pragma mark -

- (BOOL)findPanelShown
{
	return [_findPanel isVisible] && ![_findPanel isFadingOut];
}
- (void)setFindPanelShown:(BOOL)flag
{
	if(flag) {
		NSDisableScreenUpdates();
		[[self window] orderFront:self];
		if(![self findPanelShown]) [_findPanel displayOverWindow:[self window]];
		[_findPanel makeKeyWindow];
		[self documentReadingDirectionDidChange:nil];
		NSEnableScreenUpdates();
	} else {
		[_findPanel fadeOut];
		[self documentReadingDirectionDidChange:nil];
		[[self window] makeKeyWindow];
	}
}

#pragma mark -

- (NSDate *)nextTimerFireDate
{
	return [[_nextTimerFireDate retain] autorelease];
}
- (NSTimeInterval)timerInterval
{
	return _timerInterval;
}
- (void)setTimerInterval:(NSTimeInterval)time
{
	NSParameterAssert(time >= 0);
	if(time == _timerInterval) return;
	_timerInterval = time;
	[self _runTimer];
}
- (void)advanceOnTimer:(NSTimer *)timer
{
	if(![self tryToGoForward:YES allowAlerts:YES]) [self setTimerInterval:0];
}

#pragma mark -

- (void)clipViewFrameDidChange:(NSNotification *)aNotif
{
	[self _updateImageViewSizeAllowAnimation:NO];
}

#pragma mark -

- (void)nodeLoadingDidProgress:(NSNotification *)aNotif
{
	NSParameterAssert([aNotif object] == [self activeNode]);
	[_loadingGraphic setProgress:[[self activeNode] loadProgress]];
}
- (void)nodeReadyForViewing:(NSNotification *)aNotif
{
	NSParameterAssert([aNotif object] == [self activeNode]);
	NSError *const error = [[aNotif userInfo] objectForKey:PGErrorKey];
	if([PGNodeErrorDomain isEqualToString:[error domain]] && [error code] == PGGenericError) {
		[errorLabel AE_setAttributedStringValue:[[_activeNode identifier] attributedStringWithWithAncestory:NO]];
		[errorMessage setStringValue:[error localizedDescription]];
		[errorView setFrameSize:NSMakeSize(NSWidth([errorView frame]), NSHeight([errorView frame]) - NSHeight([errorMessage frame]) + [[errorMessage cell] cellSizeForBounds:NSMakeRect(0, 0, NSWidth([errorMessage frame]), FLT_MAX)].height)];
		[reloadButton setEnabled:YES];
		[clipView setDocumentView:errorView];
	} else if([PGNodeErrorDomain isEqualToString:[error domain]] && [error code] == PGPasswordError) {
		[passwordLabel AE_setAttributedStringValue:[[_activeNode identifier] attributedStringWithWithAncestory:NO]];
		[passwordField setStringValue:@""];
		[clipView setDocumentView:passwordView];
		[clipView setNextKeyView:passwordField];
		[passwordField setNextKeyView:clipView];
	} else if([PGNodeErrorDomain isEqualToString:[error domain]] && [error code] == PGEncodingError) {
		[encodingLabel AE_setAttributedStringValue:[[_activeNode identifier] attributedStringWithWithAncestory:NO]];
		[clipView setDocumentView:encodingView];
		[[self window] makeFirstResponder:clipView];
	} else {
		NSImageRep *const rep = [[aNotif userInfo] objectForKey:PGImageRepKey];
		PGOrientation const orientation = [[self activeNode] orientationWithBase:YES];
		[_imageView setImageRep:rep orientation:orientation size:[self _sizeForImageRep:rep orientation:orientation]];
		[clipView setDocumentView:_imageView];
		[clipView scrollToLocation:_initialLocation animation:PGNoAnimation];
		[[self window] makeFirstResponder:clipView];
	}
	if(![_imageView superview]) [_imageView setImageRep:nil orientation:PGUpright size:NSZeroSize];
	[self _readFinished];
}

#pragma mark -

- (void)documentWillRemoveNodes:(NSNotification *)aNotif
{
	PGNode *const changedNode = [[aNotif userInfo] objectForKey:PGDocumentNodeKey];
	NSArray *const removedChildren = [[aNotif userInfo] objectForKey:PGDocumentRemovedChildrenKey];
	PGNode *node = [[self activeNode] sortedViewableNodeNext:YES afterRemovalOfChildren:removedChildren fromNode:changedNode];
	if(!node) node = [[self activeNode] sortedViewableNodeNext:NO afterRemovalOfChildren:removedChildren fromNode:changedNode];
	[self setActiveNode:node initialLocation:PGHomeLocation];
}
- (void)documentSortedNodesDidChange:(NSNotification *)aNotif
{
	[self _noteViewableNodeCountDidChange];
	if(![self activeNode]) [self setActiveNode:[[[self activeDocument] node] sortedViewableNodeFirst:YES] initialLocation:PGHomeLocation];
	else [self _updateNodeIndex];
}
- (void)documentNodeDisplayNameDidChange:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	PGNode *const node = [[aNotif userInfo] objectForKey:PGDocumentNodeKey];
	if([self activeNode] == node || [[self activeNode] parentNode] == node) [self _updateInfoPanelText]; // The parent may be displayed too, depending.
}
- (void)documentNodeIsViewableDidChange:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	PGNode *const node = [[aNotif userInfo] objectForKey:PGDocumentNodeKey];
	if(![self activeNode]) {
		if([node isViewable]) [self setActiveNode:node initialLocation:PGHomeLocation];
	} else if([self activeNode] == node) {
		if(![node isViewable] && ![self tryToGoForward:YES allowAlerts:NO] && ![self tryToGoForward:NO allowAlerts:NO]) [self setActiveNode:[[[self activeDocument] node] sortedViewableNodeFirst:YES] initialLocation:PGHomeLocation];
	}
	[self documentShowsInfoDidChange:nil];
	[self _updateNodeIndex];
	if(![self shouldShowThumbnails] != ![_thumbnailPanel isVisible]) [self documentShowsThumbnailsDidChange:nil]; // Show or hide it.
	else if([self shouldShowThumbnails]) [[_thumbnailPanel content] reloadItem:[node parentNode] reloadChildren:YES];
}
- (void)documentNodeThumbnailDidChange:(NSNotification *)aNotif
{
	if([self shouldShowThumbnails]) [[_thumbnailPanel content] reloadItem:[[aNotif userInfo] objectForKey:PGDocumentNodeKey] reloadChildren:[[[aNotif userInfo] objectForKey:PGDocumentUpdateChildrenKey] boolValue]];
}

- (void)documentShowsInfoDidChange:(NSNotification *)aNotif
{
	if([self shouldShowInfo]) {
		[[_infoPanel content] setCount:[[[self activeDocument] node] viewableNodeCount]];
		[_infoPanel displayOverWindow:[self window]];
	} else [_infoPanel fadeOut];
}
- (void)documentShowsThumbnailsDidChange:(NSNotification *)aNotif
{
	if([self shouldShowThumbnails]) {
		NSDisableScreenUpdates();
		[_thumbnailPanel displayOverWindow:[self window]];
		[[_thumbnailPanel content] reloadData];
		[[_thumbnailPanel content] setSelectedItem:[self activeNode]];
		NSEnableScreenUpdates();
	} else {
		[self thumbnailPanelFrameDidChange:nil];
		[_thumbnailPanel fadeOut];
	}
}
- (void)documentReadingDirectionDidChange:(NSNotification *)aNotif
{
	if(![self activeDocument]) return;
	BOOL const ltr = [[self activeDocument] readingDirection] == PGReadingDirectionLeftToRight;
	PGInfoCorner const corner = ltr ? PGMinXMinYCorner : PGMaxXMinYCorner;
	PGInset inset = PGZeroInset;
	switch(corner) {
		case PGMinXMinYCorner: inset.minY = [self findPanelShown] ? NSHeight([_findPanel frame]) : 0; break;
		case PGMaxXMinYCorner: inset.minX = [self findPanelShown] ? NSWidth([_findPanel frame]) : 0; break;
	}
	if([self shouldShowThumbnails]) inset.minX += NSWidth([_thumbnailPanel frame]);
	[_infoPanel setFrameInset:inset];
	[[_infoPanel content] setOrigin:corner];
	[_infoPanel updateFrameDisplay:YES];
}
- (void)documentImageScaleDidChange:(NSNotification *)aNotif
{
	[self _updateImageViewSizeAllowAnimation:YES];
}
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif
{
	[_imageView setImageRep:[_imageView rep] orientation:[[self activeNode] orientationWithBase:YES] size:[self _sizeForImageRep:[_imageView rep] orientation:[[self activeNode] orientationWithBase:YES]]];
}

#pragma mark -

- (void)thumbnailPanelFrameDidChange:(NSNotification *)aNotif
{
	NSDisableScreenUpdates();
	if([self shouldShowThumbnails]) {
		float const panelWidth = NSWidth([_thumbnailPanel frame]);
		NSWindow *const w = [self window];
		[w setMinSize:NSMakeSize(PGWindowMinSize + panelWidth, PGWindowMinSize)];
		NSRect currentFrame = [w frame];
		if(NSWidth(currentFrame) < PGWindowMinSize + panelWidth) {
			currentFrame.size.width = PGWindowMinSize + panelWidth;
			[w setFrame:currentFrame display:YES];
		}
		PGInset const inset = PGMakeInset(panelWidth, 0, 0, 0);
		[clipView setBoundsInset:inset];
		[_findPanel setFrameInset:inset];
		[_graphicPanel setFrameInset:inset];
		[self _updateImageViewSizeAllowAnimation:NO];
		[self documentReadingDirectionDidChange:nil];
		[_findPanel updateFrameDisplay:YES];
		[_graphicPanel updateFrameDisplay:YES];
	} else {
		[clipView setBoundsInset:PGZeroInset];
		[_findPanel setFrameInset:PGZeroInset];
		[_graphicPanel setFrameInset:PGZeroInset];
		[self _updateImageViewSizeAllowAnimation:NO];
		[_findPanel updateFrameDisplay:YES];
		[_graphicPanel updateFrameDisplay:YES];
		[self documentReadingDirectionDidChange:nil];
		[[self window] setMinSize:NSMakeSize(PGWindowMinSize, PGWindowMinSize)];
	}
	NSEnableScreenUpdates();
}
- (void)prefControllerBackgroundPatternColorDidChange:(NSNotification *)aNotif;
{
	[clipView setBackgroundColor:[[PGPrefController sharedPrefController] backgroundPatternColor]];
}

#pragma mark Private Protocol

- (void)_setImageView:(PGImageView *)aView
{
	if(aView == _imageView) return;
	[_imageView unbind:@"animates"];
	[_imageView unbind:@"antialiasWhenUpscaling"];
	[_imageView unbind:@"drawsRoundedCorners"];
	[_imageView release];
	_imageView = [aView retain];
	[_imageView bind:@"animates" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:PGAnimatesImagesKey options:nil];
	[_imageView bind:@"antialiasWhenUpscaling" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:PGAntialiasWhenUpscalingKey options:nil];
	[_imageView bind:@"drawsRoundedCorners" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:PGRoundsImageCornersKey options:nil];
}
- (BOOL)_setActiveNode:(PGNode *)aNode
{
	if(aNode == _activeNode) return NO;
	[_activeNode AE_removeObserver:self name:PGNodeLoadingDidProgressNotification];
	[_activeNode AE_removeObserver:self name:PGNodeReadyForViewingNotification];
	[_activeNode release];
	_activeNode = [aNode retain];
	[self _updateNodeIndex];
	[self _updateInfoPanelText];
	if([self shouldShowThumbnails]) [[_thumbnailPanel content] setSelectedItem:aNode];
	return YES;
}
- (void)_readActiveNode
{
	[self PG_cancelPreviousPerformRequestsWithSelector:@selector(showLoadingIndicator) object:nil];
	if(!_activeNode) return [self nodeReadyForViewing:nil];
	_reading = YES;
	[self PG_performSelector:@selector(showLoadingIndicator) withObject:nil afterDelay:0.5 retain:NO];
	[_activeNode AE_addObserver:self selector:@selector(nodeLoadingDidProgress:) name:PGNodeLoadingDidProgressNotification];
	[_activeNode AE_addObserver:self selector:@selector(nodeReadyForViewing:) name:PGNodeReadyForViewingNotification];
	[_activeNode becomeViewed];
}
- (void)_readFinished
{
	_reading = NO;
	[self PG_cancelPreviousPerformRequestsWithSelector:@selector(showLoadingIndicator) object:nil];
	[[_graphicPanel content] popGraphicsOfType:PGSingleImageGraphic]; // Hide most alerts.
	[_loadingGraphic release];
	_loadingGraphic = nil;
	[self _runTimer];
	[self AE_postNotificationName:PGDisplayControllerActiveNodeDidChangeNotification];
}
- (NSSize)_sizeForImageRep:(NSImageRep *)rep
          orientation:(PGOrientation)orientation
{
	if(!rep) return NSZeroSize;
	PGImageScalingMode const scalingMode = [[self activeDocument] imageScalingMode];
	NSSize originalSize = PGActualSizeWithDPI == scalingMode ? [rep size] : NSMakeSize([rep pixelsWide], [rep pixelsHigh]);
	if(orientation & PGRotated90CC) {
		float const w = originalSize.width;
		originalSize.width = originalSize.height;
		originalSize.height = w;
	}
	NSSize newSize = originalSize;
	if(PGConstantFactorScaling == scalingMode) {
		float const factor = [[self activeDocument] imageScaleFactor];
		newSize.width *= factor;
		newSize.height *= factor;
	} else if(PGActualSizeWithDPI != scalingMode) {
		PGImageScalingConstraint const constraint = [[self activeDocument] imageScalingConstraint];
		BOOL const resIndependent = [[self activeNode] isResolutionIndependent];
		NSSize const minSize = constraint != PGUpscale || resIndependent ? NSZeroSize : newSize;
		NSSize const maxSize = constraint != PGDownscale || resIndependent ? NSMakeSize(FLT_MAX, FLT_MAX) : newSize;
		NSRect const bounds = [clipView insetBounds];
		float scaleX = NSWidth(bounds) / roundf(newSize.width);
		float scaleY = NSHeight(bounds) / roundf(newSize.height);
		if(PGAutomaticScaling == scalingMode) {
			NSSize const scrollMax = [clipView maximumDistanceForScrollType:PGScrollByPage];
			if(scaleX > scaleY) scaleX = scaleY = MAX(scaleY, MIN(scaleX, (floorf(newSize.height * scaleX / scrollMax.height + 0.3) * scrollMax.height) / newSize.height));
			else if(scaleX < scaleY) scaleX = scaleY = MAX(scaleX, MIN(scaleY, (floorf(newSize.width * scaleY / scrollMax.width + 0.3) * scrollMax.width) / newSize.width));
		} else if(PGViewFitScaling == scalingMode) scaleX = scaleY = MIN(scaleX, scaleY);
		newSize = PGConstrainSize(minSize, PGScaleSizeByXY(newSize, scaleX, scaleY), maxSize);
	}
	return PGIntegralSize(newSize);
}
- (void)_updateImageViewSizeAllowAnimation:(BOOL)flag
{
	[_imageView setSize:[self _sizeForImageRep:[_imageView rep] orientation:[_imageView orientation]] allowAnimation:flag];
}
- (void)_noteViewableNodeCountDidChange
{
	[self documentShowsInfoDidChange:nil];
	[self documentShowsThumbnailsDidChange:nil];
}
- (void)_updateNodeIndex
{
	_displayImageIndex = [[self activeNode] viewableNodeIndex];
	[[_infoPanel content] setIndex:_displayImageIndex];
	[self synchronizeWindowTitleWithDocumentName];
}
- (void)_updateInfoPanelText
{
	NSString *text = nil;
	PGNode *const node = [self activeNode];
	if(node) {
		text = [[node identifier] displayName];
		PGNode *const parent = [node parentNode];
		if([parent parentNode]) text = [NSString stringWithFormat:@"%@\n%@", [[parent identifier] displayName], text];
	} else text = NSLocalizedString(@"No image", @"Label for when no image is being displayed in the window.");
	[[_infoPanel content] setMessageText:text];
}
- (void)_runTimer
{
	[_nextTimerFireDate release];
	[_timer invalidate];
	[_timer release];
	if([self timerInterval]) {
		_nextTimerFireDate = [[NSDate alloc] initWithTimeIntervalSinceNow:[self timerInterval]];
		_timer = [[NSTimer alloc] initWithFireDate:_nextTimerFireDate interval:0 target:[self PG_nonretainedObjectProxy] selector:@selector(advanceOnTimer:) userInfo:nil repeats:NO];
		[[NSRunLoop currentRunLoop] addTimer:_timer forMode:NSDefaultRunLoopMode];
	} else {
		_nextTimerFireDate = nil;
		_timer = nil;
	}
	[self AE_postNotificationName:PGDisplayControllerTimerDidChangeNotification];
}

#pragma mark NSMenuValidation Protocol

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	SEL const action = [anItem action];
	if(@selector(jumpToPage:) == action) {
		PGNode *const node = [[anItem representedObject] PG_nonretainedObjectValue];
		NSCellStateValue state = NSOffState;
		if(node && node == [self activeNode]) state = NSOnState;
		else if([[self activeNode] isDescendantOfNode:node]) state = NSMixedState;
		[anItem setState:state];
		return [node isViewable] || [anItem submenu];
	}
	if(![[self activeNode] isViewable]) {
		if(@selector(revealInPathFinder:) == action) return NO;
		if(@selector(revealInFinder:) == action) return NO;
		if(@selector(revealInBrowser:) == action) return NO;
		if(@selector(pauseDocument:) == action) return NO;
		if(@selector(pauseAndCloseDocument:) == action) return NO;
	}
	if(![[[self activeDocument] node] hasDataNodes]) {
		if(@selector(extractImages:) == action) return NO;
	}
	if(![[[self activeNode] identifier] isFileIdentifier]) {
		if(@selector(moveToTrash:) == action) return NO;
	}
	if(![[[self activeNode] identifier] URL]) {
		if(@selector(moveToTrash:) == action) return NO;
	}
	if(![self activeNode]) {
		if(@selector(copy:) == action) return NO;
	}
	if(@selector(performFindPanelAction:) == action) switch([anItem tag]) {
		case NSFindPanelActionShowFindPanel:
		case NSFindPanelActionNext:
		case NSFindPanelActionPrevious: break;
		default: return NO;
	}
	if(![self canShowInfo]) {
		if(@selector(toggleInfo:) == action) return NO;
	}
	if(![self canShowThumbnails]) {
		if(@selector(toggleThumbnails:) == action) return NO;
	}
	if([[self activeDocument] baseOrientation] == PGUpright) {
		if(@selector(revertOrientation:) == action) return NO;
	}
	PGDocument *const doc = [self activeDocument];
	if([doc imageScalingMode] == PGConstantFactorScaling) {
		if(@selector(zoomIn:) == action && [_imageView averageScaleFactor] >= PGScaleMax) return NO;
		if(@selector(zoomOut:) == action && [_imageView averageScaleFactor] <= PGScaleMin) return NO;
	}
	PGNode *const firstNode = [[[self activeDocument] node] sortedViewableNodeFirst:YES];
	if(!firstNode) { // We might have to get -firstNode anyway.
		if(@selector(firstPage:) == action) return NO;
		if(@selector(previousPage:) == action) return NO;
		if(@selector(nextPage:) == action) return NO;
		if(@selector(lastPage:) == action) return NO;
		if(@selector(skipBeforeFolder:) == action) return NO;
		if(@selector(skipPastFolder:) == action) return NO;
		if(@selector(firstOfNextFolder:) == action) return NO;
		if(@selector(firstOfPreviousFolder:) == action) return NO;
		if(@selector(firstOfFolder:) == action) return NO;
		if(@selector(lastOfFolder:) == action) return NO;
	}
	if([self activeNode] == firstNode) {
		if(@selector(firstPage:) == action) return NO;
	}
	if([self activeNode] == [[[self activeDocument] node] sortedViewableNodeFirst:NO]) {
		if(@selector(lastPage:) == action) return NO;
	}
	if(![[[self activeNode] containerAdapter] parentAdapter]) {
		if(@selector(skipBeforeFolder:) == action) return NO;
		if(@selector(skipPastFolder:) == action) return NO;
	}
	if(@selector(firstOfFolder:) == action) {
		PGNode *const firstOfFolder = [[[self activeNode] containerAdapter] sortedViewableNodeFirst:YES];
		if(!firstOfFolder || [self activeNode] == firstOfFolder) return NO;
	}
	if(@selector(lastOfFolder:) == action) {
		PGNode *const lastOfFolder = [[[self activeNode] containerAdapter] sortedViewableNodeFirst:NO];
		if(!lastOfFolder || [self activeNode] == lastOfFolder) return NO;
	}
	return [super validateMenuItem:anItem];
}

#pragma mark PGDocumentWindowDelegate Protocol

- (void)selectNextOutOfWindowKeyView:(NSWindow *)window
{
	NSParameterAssert(window == [self window]);
	if(![self findPanelShown]) return;
	[_findPanel makeKeyWindow];
	[_findPanel makeFirstResponder:[_findPanel initialFirstResponder]];
}
- (void)selectPreviousOutOfWindowKeyView:(NSWindow *)window
{
	NSParameterAssert(window == [self window]);
	if(![self findPanelShown]) return;
	[_findPanel makeKeyWindow];
	NSView *const previousKeyView = [[_findPanel initialFirstResponder] previousValidKeyView];
	[_findPanel makeFirstResponder:(previousKeyView ? previousKeyView : [_findPanel initialFirstResponder])];
}

#pragma mark NSWindowNotifications Protocol

- (void)windowDidBecomeMain:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	if([aNotif object] != [self window]) return;
	[[PGDocumentController sharedDocumentController] setCurrentDocument:[self activeDocument]];
}
- (void)windowDidResignMain:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	if([aNotif object] != [self window]) return;
	[[PGDocumentController sharedDocumentController] setCurrentDocument:nil];
}

- (void)windowDidBecomeKey:(NSNotification *)aNotif
{
	if([aNotif object] == _findPanel) [_findPanel makeFirstResponder:searchField];
}
- (void)windowDidResignKey:(NSNotification *)aNotif
{
	if([aNotif object] == _findPanel) [_findPanel makeFirstResponder:nil];
}

- (void)windowWillClose:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	if([aNotif object] != [self window]) return;
	if([_findPanel parentWindow]) [_findPanel close];
	[self close];
}

#pragma mark NSWindowDelegate Protocol

- (BOOL)window:(NSWindow *)window
        shouldDragDocumentWithEvent:(NSEvent *)event
        from:(NSPoint)dragImageLocation
        withPasteboard:(NSPasteboard *)pboard
{
	if([self window] != window) return YES;
	PGResourceIdentifier *const ident = [[[self activeDocument] node] identifier];
	if(![ident isFileIdentifier]) {
		[pboard declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
		[[ident URL] writeToPasteboard:pboard];
	}
	NSImage *const image = [[[ident icon] copy] autorelease];
	[[self window] dragImage:image at:PGOffsetPointByXY(dragImageLocation, 24 - [image size].width / 2, 24 - [image size].height / 2) offset:NSZeroSize event:event pasteboard:pboard source:nil slideBack:YES]; // Left to its own devices, OS X will start the drag image 16 pixels down and to the left of the button, which looks bad at both 16x16 and at 32x32, so always do our own drags.
	return NO;
}
- (id)windowWillReturnFieldEditor:(NSWindow *)window
      toObject:(id)anObject
{
	if(window != _findPanel) return nil;
	if(!_findFieldEditor) {
		_findFieldEditor = [[PGFindlessTextView alloc] init];
		[_findFieldEditor setFieldEditor:YES];
	}
	return _findFieldEditor;
}

#pragma mark PGClipViewDelegate Protocol

- (BOOL)clipView:(PGClipView *)sender
        handleMouseEvent:(NSEvent *)anEvent
        first:(BOOL)flag
{
	if(flag) return NO;
	BOOL const primary = [anEvent type] == NSLeftMouseDown;
	BOOL const rtl = [[self activeDocument] readingDirection] == PGReadingDirectionRightToLeft;
	BOOL forward;
	switch([[[NSUserDefaults standardUserDefaults] objectForKey:PGMouseClickActionKey] intValue]) {
		case PGLeftRightAction: forward = primary == rtl; break;
		case PGRightLeftAction: forward = primary != rtl; break;
		default: forward = primary; break;
	}
	if([anEvent modifierFlags] & NSShiftKeyMask) forward = !forward;
	if(forward) [self nextPage:self];
	else [self previousPage:self];
	return YES;
}
- (BOOL)clipView:(PGClipView *)sender
        handleKeyDown:(NSEvent *)anEvent
{
	unsigned const modifiers = NSDeviceIndependentModifierFlagsMask & [anEvent modifierFlags];
	PGDocumentController *const d = [PGDocumentController sharedDocumentController];
	unsigned short const keyCode = [anEvent keyCode];
	if(!(modifiers & (NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask | NSControlKeyMask))) switch(keyCode) {
		case PGKeyEscape: return [d performEscapeKeyAction];
		case PGKeyPadPlus: [self nextPage:self]; return YES;
		case PGKeyPadMinus: [self previousPage:self]; return YES;
	} else if(NSCommandKeyMask == modifiers) switch(keyCode) {
		case PGKeyI: return [d performToggleInfo];
	}
	if(0 == modifiers || (NSCommandKeyMask | NSShiftKeyMask) & modifiers) switch(keyCode) {
		case PGKeyEquals: return [d performZoomIn];
		case PGKeyMinus: return [d performZoomOut];
	}
	float const timerFactor = NSAlternateKeyMask & modifiers ? 10.0f : 1.0f;
	if(0 == modifiers || NSAlternateKeyMask == modifiers) switch(keyCode) {
		case PGKey0: [self setTimerInterval:0]; return YES;
		case PGKey1: [self setTimerInterval:1 * timerFactor]; return YES;
		case PGKey2: [self setTimerInterval:2 * timerFactor]; return YES;
		case PGKey3: [self setTimerInterval:3 * timerFactor]; return YES;
		case PGKey4: [self setTimerInterval:4 * timerFactor]; return YES;
		case PGKey5: [self setTimerInterval:5 * timerFactor]; return YES;
		case PGKey6: [self setTimerInterval:6 * timerFactor]; return YES;
		case PGKey7: [self setTimerInterval:7 * timerFactor]; return YES;
		case PGKey8: [self setTimerInterval:8 * timerFactor]; return YES;
		case PGKey9: [self setTimerInterval:9 * timerFactor]; return YES;
	}
	return NO;
}
- (BOOL)clipView:(PGClipView *)sender
        shouldExitEdges:(PGRectEdgeMask)mask
{
	NSAssert(mask, @"At least one edge must be set.");
	NSAssert(!PGHasContradictoryRectEdges(mask), @"Contradictory edges aren't allowed.");
	BOOL const ltr = [[self activeDocument] readingDirection] == PGReadingDirectionLeftToRight;
	PGNode *const activeNode = [self activeNode];
	if(mask & (ltr ? PGMinXEdgeMask : PGMaxXEdgeMask)) [self previousPage:self];
	else if(mask & (ltr ? PGMaxXEdgeMask : PGMinXEdgeMask)) [self nextPage:self];
	return [self activeNode] != activeNode;
}
- (PGRectEdgeMask)clipView:(PGClipView *)sender
                  directionFor:(PGPageLocation)nodeLocation
{
	return PGReadingDirectionAndLocationToRectEdgeMask(nodeLocation, [[self activeDocument] readingDirection]);
}
- (void)clipView:(PGClipView *)sender
        magnifyBy:(float)amount
{
	[_imageView setUsesCaching:NO];
	PGDocument *const doc = [self activeDocument];
	[doc setImageScaleFactor:MAX(PGScaleMin, MIN(PGScaleMax, [_imageView averageScaleFactor] * (amount / 500 + 1)))];
	[doc setImageScalingMode:PGConstantFactorScaling];
}
- (void)clipView:(PGClipView *)sender
        rotateByDegrees:(float)amount
{
	[clipView scrollCenterTo:[clipView convertPoint:[_imageView rotateByDegrees:amount adjustingPoint:[_imageView convertPoint:[clipView center] fromView:clipView]] fromView:_imageView] animation:PGNoAnimation];
}
- (void)clipViewGestureDidEnd:(PGClipView *)sender
{
	[_imageView setUsesCaching:YES];
	float const deg = [_imageView rotationInDegrees];
	[_imageView setRotationInDegrees:0];
	PGOrientation o;
	switch((int)roundf((deg + 360) / 90) % 4) {
		case 0: o = PGUpright; break;
		case 1: o = PGRotated90CC; break;
		case 2: o = PGUpsideDown; break;
		case 3: o = PGRotated270CC; break;
		default: PGAssertNotReached(@"Rotation wasn't simplified into an orientation.");
	}
	[[self activeDocument] setBaseOrientation:PGAddOrientation([[self activeDocument] baseOrientation], o)];
}

#pragma mark PGThumbnailBrowserDataSource Protocol

- (id)thumbnailBrowser:(PGThumbnailBrowser *)sender
      parentOfItem:(id)item
{
	PGNode *const parent = [(PGNode *)item parentNode];
	return [[self activeDocument] node] == parent && ![parent isViewable] ? nil : parent;
}
- (BOOL)thumbnailBrowser:(PGThumbnailBrowser *)sender
        itemCanHaveChildren:(id)item
{
	return [item isContainer];
}

#pragma mark PGThumbnailBrowserDelegate Protocol

- (void)thumbnailBrowserSelectionDidChange:(PGThumbnailBrowser *)sender
{
	NSSet *const selection = [sender selection];
	id const item = [selection anyObject];
	(void)[self tryToSetActiveNode:[([selection count] == 1 ? item : [item parentNode]) viewableAncestor] initialLocation:PGHomeLocation];
}

#pragma mark PGThumbnailViewDataSource Protocol

- (NSArray *)itemsForThumbnailView:(PGThumbnailView *)sender
{
	id const item = [sender representedObject];
	if(item) return [item isContainer] ? [item sortedChildren] : nil;
	PGNode *const root = [[self activeDocument] node];
	if([root isViewable]) return [root AE_asArray];
	return [root isContainer] ? [(PGContainerAdapter *)root sortedChildren] : nil;
}
- (NSImage *)thumbnailView:(PGThumbnailView *)sender
             thumbnailForItem:(id)item
{
	return [item thumbnail];
}
- (NSString *)thumbnailView:(PGThumbnailView *)sender
              labelForItem:(id)item
{
	return [[item identifier] displayName];
}
- (BOOL)thumbnailView:(PGThumbnailView *)sender
        canSelectItem:(id)item;
{
	return [item hasViewableNodeCountGreaterThan:0];
}

#pragma mark NSServicesRequests Protocol

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard
        types:(NSArray *)types
{
	BOOL wrote = NO;
	[pboard declareTypes:[NSArray array] owner:nil];
	do {
		if(![types containsObject:NSStringPboardType] || ![self activeNode]) break;
		wrote = YES;
		if(!pboard) break;
		[pboard addTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
		[pboard setString:[[[self activeNode] identifier] displayName] forType:NSStringPboardType];
	} while(NO);
	do {
		if(![types containsObject:NSTIFFPboardType] || [clipView documentView] != _imageView) break;
		NSImageRep *const rep = [_imageView rep];
		if(!rep || ![rep respondsToSelector:@selector(TIFFRepresentation)]) break;
		wrote = YES;
		if(!pboard) break;
		[pboard addTypes:[NSArray arrayWithObject:NSTIFFPboardType] owner:nil];
		[pboard setData:[(NSBitmapImageRep *)rep TIFFRepresentation] forType:NSTIFFPboardType];
	} while(NO);
	do {
		if(![[self activeNode] canGetData]) break;
		if(![types containsObject:NSRTFDPboardType] && ![types containsObject:NSFileContentsPboardType]) break;
		wrote = YES;
		if(!pboard) break;
		NSData *const data = [[self activeNode] data];
		if(!data) break;
		if([types containsObject:NSRTFDPboardType]) {
			[pboard addTypes:[NSArray arrayWithObject:NSRTFDPboardType] owner:nil];
			NSFileWrapper *const wrapper = [[[NSFileWrapper alloc] initRegularFileWithContents:data] autorelease];
			[wrapper setPreferredFilename:[[[self activeNode] identifier] displayName]];
			NSAttributedString *const string = [NSAttributedString attributedStringWithAttachment:[[[NSTextAttachment alloc] initWithFileWrapper:wrapper] autorelease]];
			[pboard setData:[string RTFDFromRange:NSMakeRange(0, [string length]) documentAttributes:nil] forType:NSRTFDPboardType];
		}
		if([types containsObject:NSFileContentsPboardType]) {
			[pboard addTypes:[NSArray arrayWithObject:NSFileContentsPboardType] owner:nil];
			[pboard setData:data forType:NSFileContentsPboardType];
		}
	} while(NO);
	return wrote;
}

#pragma mark PGEncodingAlertDelegate Protocol

- (void)encodingAlertDidEnd:(PGEncodingAlert *)sender
        selectedEncoding:(NSStringEncoding)encoding
{
	if(encoding) [[self activeNode] startLoadWithInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:encoding], PGStringEncodingKey, nil]];
}

#pragma mark NSWindowController

- (IBAction)showWindow:(id)sender
{
	[super showWindow:sender];
	[self documentReadingDirectionDidChange:nil];
	[self _noteViewableNodeCountDidChange];
}

#pragma mark -

- (void)windowDidLoad
{
	[super windowDidLoad];
	[passwordView retain];
	[encodingView retain];

	[[self window] useOptimizedDrawing:YES];

	NSImage *const cursorImage = [NSImage imageNamed:@"Cursor-Hand-Pointing"];
	[clipView setCursor:(cursorImage ? [[[NSCursor alloc] initWithImage:cursorImage hotSpot:NSMakePoint(5, 0)] autorelease] : [NSCursor pointingHandCursor])];
	[clipView setPostsFrameChangedNotifications:YES];
	[clipView AE_addObserver:self selector:@selector(clipViewFrameDidChange:) name:NSViewFrameDidChangeNotification];

	_findPanel = [[PGBezelPanel alloc] initWithContentView:findView];
	[_findPanel setInitialFirstResponder:searchField];
	[_findPanel setDelegate:self];
	[_findPanel setAcceptsEvents:YES];
	[_findPanel setCanBecomeKey:YES];

	[self prefControllerBackgroundPatternColorDidChange:nil];
}
- (void)synchronizeWindowTitleWithDocumentName
{
	PGResourceIdentifier *const identifier = [[[self activeDocument] node] identifier];
	NSURL *const URL = [identifier URL];
	if(PGIsLeopardOrLater() && ![identifier isFileIdentifier]) {
		[[self window] setRepresentedURL:URL];
		if(![identifier isFileIdentifier]) {
			NSButton *const docButton = [[self window] standardWindowButton:NSWindowDocumentIconButton];
			NSImage *const image = [[[identifier icon] copy] autorelease];
			[image setFlipped:![docButton isFlipped]];
			[image setScalesWhenResized:YES]; // If we aren't careful about this, it changes randomly sometimes.
			[image setSize:[docButton bounds].size];
			[docButton setImage:image];
		}
	} else {
		NSString *const path = [identifier isFileIdentifier] ? [URL path] : nil;
		[[self window] setRepresentedFilename:(path ? path : @"")];
	}
	unsigned const count = [[[self activeDocument] node] viewableNodeCount];
	NSString *const title = [identifier displayName];
	NSString *const titleDetails = count > 1 ? [NSString stringWithFormat:@" (%u/%u)", _displayImageIndex + 1, count] : @"";
	[[self window] setTitle:(title ? [title stringByAppendingString:titleDetails] : @"")];
	NSMutableAttributedString *const menuLabel = [[[identifier attributedStringWithWithAncestory:NO] mutableCopy] autorelease];
	[[menuLabel mutableString] appendString:titleDetails];
	[[[PGDocumentController sharedDocumentController] windowsMenuItemForDocument:[self activeDocument]] setAttributedTitle:menuLabel];
}
- (void)close
{
	[[self activeDocument] close];
}

#pragma mark NSResponder

- (id)validRequestorForSendType:(NSString *)sendType
      returnType:(NSString *)returnType
{
	return (!returnType || [@"" isEqual:returnType]) && [self writeSelectionToPasteboard:nil types:[NSArray arrayWithObject:sendType]] ? self : [super validRequestorForSendType:sendType returnType:returnType];
}

#pragma mark NSObject

- (id)init
{
	if((self = [super initWithWindowNibName:@"PGWindow"])) {
		(void)[self window]; // Just load the window so we don't have to worry about it.

		_graphicPanel = [[PGAlertView PG_bezelPanel] retain];
		_infoPanel = [[PGInfoView PG_bezelPanel] retain];
		[self _updateInfoPanelText];
		_thumbnailPanel = [[PGThumbnailBrowser PG_bezelPanel] retain];
		[_thumbnailPanel setAcceptsEvents:YES];
		[_thumbnailPanel setDelegate:self];
		[[_thumbnailPanel content] setDataSource:self];
		[[_thumbnailPanel content] setDelegate:self];
		[_thumbnailPanel AE_addObserver:self selector:@selector(thumbnailPanelFrameDidChange:) name:PGBezelPanelFrameDidChangeNotification];

		[[PGPrefController sharedPrefController] AE_addObserver:self selector:@selector(prefControllerBackgroundPatternColorDidChange:) name:PGPrefControllerBackgroundPatternColorDidChangeNotification];
	}
	return self;
}
- (void)dealloc
{
	[self PG_cancelPreviousPerformRequests];
	[self AE_removeObserver];
	[self _setImageView:nil];
	[passwordView release];
	[encodingView release];
	[_activeNode release];
	[_graphicPanel release];
	[_loadingGraphic release];
	[_infoPanel release];
	[_findPanel release];
	[_findFieldEditor release];
	[_thumbnailPanel release];
	[_nextTimerFireDate release];
	[_timer invalidate];
	[_timer release];
	[super dealloc];
}

@end
