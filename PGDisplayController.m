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
#import "PGDisplayController.h"
#import <unistd.h>
#import <tgmath.h>

// Models
#import "PGDocument.h"
#import "PGNode.h"
#import "PGContainerAdapter.h"
#import "PGGenericImageAdapter.h"
#import "PGResourceIdentifier.h"
#import "PGBookmark.h"

// Views
#import "PGDocumentWindow.h"
#import "PGClipView.h"
#import "PGImageView.h"
#import "PGBezelPanel.h"
#import "PGAlertView.h"
#import "PGInfoView.h"
#import "PGFindView.h"

// Controllers
#import "PGDocumentController.h"
#import "PGPreferenceWindowController.h"
#import "PGBookmarkController.h"
#import "PGThumbnailController.h"
#import "PGImageSaveAlert.h"

// Other Sources
#import "PGAppKitAdditions.h"
#import "PGDebug.h"
#import "PGDelayedPerforming.h"
#import "PGFoundationAdditions.h"
#import "PGGeometry.h"
#import "PGKeyboardLayout.h"

NSString *const PGDisplayControllerActiveNodeDidChangeNotification = @"PGDisplayControllerActiveNodeDidChange";
NSString *const PGDisplayControllerActiveNodeWasReadNotification = @"PGDisplayControllerActiveNodeWasRead";
NSString *const PGDisplayControllerTimerDidChangeNotification = @"PGDisplayControllerTimerDidChange";

#define PGWindowMinSize ((NSSize){350.0f, 200.0f})

enum {
	PGZoomNone = 0,
	PGZoomIn   = 1 << 0,
	PGZoomOut  = 1 << 1
};
typedef NSUInteger PGZoomDirection;

static inline NSSize PGConstrainSize(NSSize min, NSSize size, NSSize max)
{
	return NSMakeSize(MIN(MAX(min.width, size.width), max.width), MIN(MAX(min.height, size.height), max.height));
}

@interface PGDisplayController(Private)

- (void)_setImageView:(PGImageView *)aView;
- (BOOL)_setActiveNode:(PGNode *)aNode;
- (void)_readActiveNode;
- (void)_readFinished;
- (NSSize)_sizeForImageRep:(NSImageRep *)rep orientation:(PGOrientation)orientation;
- (NSSize)_sizeForImageRep:(NSImageRep *)rep orientation:(PGOrientation)orientation scaleMode:(PGImageScaleMode)scaleMode factor:(float)factor;
- (void)_updateImageViewSizeAllowAnimation:(BOOL)flag;
- (void)_updateNodeIndex;
- (void)_updateInfoPanelText;
- (void)_setCopyAsDesktopPicturePanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo;
- (void)_offerToOpenBookmarkAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode bookmark:(PGBookmark *)bookmark;

@end

@implementation PGDisplayController

#pragma mark +PGDisplayController

+ (NSArray *)pasteboardTypes
{
	return [NSArray PG_arrayWithContentsOfArrays:[PGNode pasteboardTypes], [PGImageView pasteboardTypes], nil];
}

#pragma mark +NSObject

+ (void)initialize
{
	[NSApp registerServicesMenuSendTypes:[self pasteboardTypes] returnTypes:[NSArray array]];
}
- (NSUserDefaultsController *)userDefaults
{
	return [NSUserDefaultsController sharedUserDefaultsController];
}

#pragma mark -PGDisplayController

- (IBAction)reveal:(id)sender
{
	if([[self activeDocument] isOnline]) {
		if([[NSWorkspace sharedWorkspace] openURL:[[[self activeDocument] rootIdentifier] URLByFollowingAliases:NO]]) return;
	} else {
		NSString *const path = [[[[self activeNode] identifier] URLByFollowingAliases:NO] path];
		if([[PGDocumentController sharedDocumentController] pathFinderRunning]) {
			if([[[[NSAppleScript alloc] initWithSource:[NSString stringWithFormat:@"tell application \"Path Finder\"\nactivate\nreveal \"%@\"\nend tell", path]] autorelease] executeAndReturnError:NULL]) return;
		} else {
			if([[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil]) return;
		}
	}
	NSBeep();
}
- (IBAction)saveImagesTo:(id)sender
{
	[[[[PGImageSaveAlert alloc] initWithRoot:[[self activeDocument] node] initialSelection:[self selectedNodes]] autorelease] beginSheetForWindow:[self windowForSheet]];
}
- (IBAction)setAsDesktopPicture:(id)sender
{
	PGResourceIdentifier *const ident = [[self activeNode] identifier];
	if(![ident isFileIdentifier] || ![[NSScreen PG_mainScreen] PG_setDesktopImageURL:[ident URLByFollowingAliases:YES]]) NSBeep();
}
- (IBAction)setCopyAsDesktopPicture:(id)sender
{
	NSSavePanel *const savePanel = [NSSavePanel savePanel];
	[savePanel setTitle:NSLocalizedString(@"Save Copy as Desktop Picture", @"Title of save dialog when setting a copy as the desktop picture.")];
	PGDisplayableIdentifier *const ident = [[self activeNode] identifier];
	[savePanel setRequiredFileType:[[ident naturalDisplayName] pathExtension]];
	[savePanel setCanSelectHiddenExtension:YES];
	NSWindow *const window = [self windowForSheet];
	NSString *const file = [[ident naturalDisplayName] stringByDeletingPathExtension];
	if(window) [savePanel beginSheetForDirectory:nil file:file modalForWindow:window modalDelegate:self didEndSelector:@selector(_setCopyAsDesktopPicturePanelDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	else [self _setCopyAsDesktopPicturePanelDidEnd:savePanel returnCode:[savePanel runModalForDirectory:nil file:file] contextInfo:NULL];
}
- (IBAction)moveToTrash:(id)sender
{
	BOOL movedAnything = NO;
	for(PGNode *const node in [self selectedNodes]) {
		NSString *const path = [[[node identifier] URL] path];
		if([[NSWorkspace sharedWorkspace] performFileOperation:NSWorkspaceRecycleOperation source:[path stringByDeletingLastPathComponent] destination:@"" files:[NSArray arrayWithObject:[path lastPathComponent]] tag:NULL]) movedAnything = YES;
	}
	if(!movedAnything) NSBeep();
}

#pragma mark -

- (IBAction)copy:(id)sender
{
	if(![self writeSelectionToPasteboard:[NSPasteboard generalPasteboard] types:[[self class] pasteboardTypes]]) NSBeep();
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
			NSArray *const terms = [[searchField stringValue] PG_searchTerms];
			if(terms && [terms count] && ![self tryToSetActiveNode:[[[self activeNode] resourceAdapter] sortedViewableNodeNext:[sender tag] == NSFindPanelActionNext matchSearchTerms:terms] forward:YES]) NSBeep();
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
	[[PGDocumentController sharedDocumentController] setFullscreen:![PGDocumentController sharedDocumentController].fullscreen];
}
- (IBAction)toggleInfo:(id)sender
{
	[[self activeDocument] setShowsInfo:![[self activeDocument] showsInfo]];
}
- (IBAction)toggleThumbnails:(id)sender
{
	[[self activeDocument] setShowsThumbnails:![[self activeDocument] showsThumbnails]];
}
- (IBAction)changeReadingDirection:(id)sender
{
	[[self activeDocument] setReadingDirection:[sender tag]];
}
- (IBAction)changeSortOrder:(id)sender
{
	[[self activeDocument] setSortOrder:([sender tag] & PGSortOrderMask) | ([[self activeDocument] sortOrder] & PGSortOptionsMask)];
}
- (IBAction)changeSortDirection:(id)sender
{
	[[self activeDocument] setSortOrder:([[self activeDocument] sortOrder] & ~PGSortDescendingMask) | [sender tag]];
}
- (IBAction)changeSortRepeat:(id)sender
{
	[[self activeDocument] setSortOrder:([[self activeDocument] sortOrder] & ~PGSortRepeatMask) | [sender tag]];
}
- (IBAction)revertOrientation:(id)sender
{
	[[self activeDocument] setBaseOrientation:PGUpright];
}
- (IBAction)changeOrientation:(id)sender
{
	[[self activeDocument] setBaseOrientation:PGAddOrientation([[self activeDocument] baseOrientation], [sender tag])];
}
- (IBAction)toggleAnimation:(id)sender
{
	NSParameterAssert([_imageView canAnimateRep]);
	BOOL const nowPlaying = ![[self activeDocument] animatesImages];
	[[_graphicPanel content] pushGraphic:[PGBezierPathIconGraphic graphicWithIconType:nowPlaying ? AEPlayIcon : AEPauseIcon] window:[self window]];
	[[self activeDocument] setAnimatesImages:nowPlaying];
}

#pragma mark -

- (IBAction)changeImageScaleMode:(id)sender
{
	[[self activeDocument] setImageScaleMode:[sender tag]];
}
- (IBAction)zoomIn:(id)sender
{
	if(![self zoomKeyDown:[[self window] currentEvent]]) [self zoomBy:2.0f animate:YES];
}
- (IBAction)zoomOut:(id)sender
{
	if(![self zoomKeyDown:[[self window] currentEvent]]) [self zoomBy:0.5f animate:YES];
}
- (IBAction)changeImageScaleFactor:(id)sender
{
	[[self activeDocument] setImageScaleFactor:pow(2.0f, (CGFloat)[sender doubleValue]) animate:NO];
	[[[PGDocumentController sharedDocumentController] scaleMenu] update];
}
- (IBAction)minImageScaleFactor:(id)sender
{
	[[self activeDocument] setImageScaleFactor:PGScaleMin];
	[[[PGDocumentController sharedDocumentController] scaleMenu] update];
}
- (IBAction)maxImageScaleFactor:(id)sender
{
	[[self activeDocument] setImageScaleFactor:PGScaleMax];
	[[[PGDocumentController sharedDocumentController] scaleMenu] update];
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
	[self setActiveNode:[[[[self activeDocument] node] resourceAdapter] sortedViewableNodeFirst:YES] forward:YES];
}
- (IBAction)lastPage:(id)sender
{
	[self setActiveNode:[[[[self activeDocument] node] resourceAdapter] sortedViewableNodeFirst:NO] forward:NO];
}

#pragma mark -

- (IBAction)firstOfPreviousFolder:(id)sender
{
	if([self tryToSetActiveNode:[[[self activeNode] resourceAdapter] sortedFirstViewableNodeInFolderNext:NO inclusive:NO] forward:YES]) return;
	[self prepareToLoop]; // -firstOfPreviousFolder: is an exception to our usual looping mechanic, so we can't use -loopForward:.
	PGNode *const last = [[[[self activeDocument] node] resourceAdapter] sortedViewableNodeFirst:NO];
	[self tryToLoopForward:NO toNode:[[last resourceAdapter] isSortedFirstViewableNodeOfFolder] ? last : [[last resourceAdapter] sortedFirstViewableNodeInFolderNext:NO inclusive:YES] pageForward:YES allowAlerts:YES];
}
- (IBAction)firstOfNextFolder:(id)sender
{
	if([self tryToSetActiveNode:[[[self activeNode] resourceAdapter] sortedFirstViewableNodeInFolderNext:YES inclusive:NO] forward:YES]) return;
	[self loopForward:YES];
}
- (IBAction)skipBeforeFolder:(id)sender
{
	if([self tryToSetActiveNode:[[[[self activeNode] resourceAdapter] containerAdapter] sortedViewableNodeNext:NO includeChildren:NO] forward:NO]) return;
	[self loopForward:NO];
}
- (IBAction)skipPastFolder:(id)sender
{
	if([self tryToSetActiveNode:[[[[self activeNode] resourceAdapter] containerAdapter] sortedViewableNodeNext:YES includeChildren:NO] forward:YES]) return;
	[self loopForward:YES];
}
- (IBAction)firstOfFolder:(id)sender
{
	[self setActiveNode:[[[self activeNode] resourceAdapter] sortedViewableNodeInFolderFirst:YES] forward:YES];
}
- (IBAction)lastOfFolder:(id)sender
{
	[self setActiveNode:[[[self activeNode] resourceAdapter] sortedViewableNodeInFolderFirst:NO] forward:NO];
}

#pragma mark -

- (IBAction)jumpToPage:(id)sender
{
	PGNode *node = [[(NSMenuItem *)sender representedObject] nonretainedObjectValue];
	if(![node isViewable]) node = [[node resourceAdapter] sortedViewableNodeFirst:YES];
	if([self activeNode] == node || !node) return;
	[self setActiveNode:node forward:YES];
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
	[[self activeNode] reload];
	[self _readActiveNode];
}
- (IBAction)decrypt:(id)sender
{
	PGNode *const activeNode = [self activeNode];
	[activeNode PG_addObserver:self selector:@selector(nodeLoadingDidProgress:) name:PGNodeLoadingDidProgressNotification];
	[activeNode PG_addObserver:self selector:@selector(nodeReadyForViewing:) name:PGNodeReadyForViewingNotification];
	// TODO: Figure this out.
//	[[[activeNode resourceAdapter] info] setObject:[passwordField stringValue] forKey:PGPasswordKey];
	[activeNode becomeViewed];
}

#pragma mark -

@synthesize activeDocument = _activeDocument;
@synthesize activeNode = _activeNode;
- (NSWindow *)windowForSheet
{
	return [self window];
}
- (NSSet *)selectedNodes
{
	NSSet *const thumbnailSelection = [_thumbnailController selectedNodes];
	if([thumbnailSelection count]) return thumbnailSelection;
	return [self activeNode] ? [NSSet setWithObject:[self activeNode]] : [NSSet set];
}
- (PGNode *)selectedNode
{
	NSSet *const selectedNodes = [self selectedNodes];
	return [selectedNodes count] == 1 ? [selectedNodes anyObject] : nil;
}
@synthesize clipView;
@synthesize initialLocation = _initialLocation;
@synthesize reading = _reading;
- (BOOL)isDisplayingImage
{
	return [clipView documentView] == _imageView;
}
- (BOOL)canShowInfo
{
	return YES;
}
- (BOOL)shouldShowInfo
{
	return [[self activeDocument] showsInfo] && [self canShowInfo];
}
- (BOOL)loadingIndicatorShown
{
	return _loadingGraphic != nil;
}
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
- (NSDate *)nextTimerFireDate
{
	return [[_nextTimerFireDate retain] autorelease];
}
- (BOOL)timerRunning
{
	return !!_timer;
}
- (void)setTimerRunning:(BOOL)run
{
	[_nextTimerFireDate release];
	[_timer invalidate];
	[_timer release];
	if(run) {
		_nextTimerFireDate = [[NSDate alloc] initWithTimeIntervalSinceNow:[[self activeDocument] timerInterval]];
		_timer = [[self PG_performSelector:@selector(advanceOnTimer) withObject:nil fireDate:_nextTimerFireDate interval:0.0f options:kNilOptions mode:NSDefaultRunLoopMode] retain];
	} else {
		_nextTimerFireDate = nil;
		_timer = nil;
	}
	[self PG_postNotificationName:PGDisplayControllerTimerDidChangeNotification];
}

#pragma mark -

- (BOOL)setActiveDocument:(PGDocument *)document closeIfAppropriate:(BOOL)flag
{
	if(document == _activeDocument) return NO;
	if(_activeDocument) {
		if(_reading) [_imageView setImageRep:nil orientation:PGUpright size:NSZeroSize];
		[_activeDocument storeNode:[self activeNode] imageView:_imageView offset:[clipView pinLocationOffset] query:[searchField stringValue]];
		[self _setImageView:nil];
		[_activeDocument PG_removeObserver:self name:PGDocumentWillRemoveNodesNotification];
		[_activeDocument PG_removeObserver:self name:PGDocumentSortedNodesDidChangeNotification];
		[_activeDocument PG_removeObserver:self name:PGDocumentNodeDisplayNameDidChangeNotification];
		[_activeDocument PG_removeObserver:self name:PGDocumentNodeIsViewableDidChangeNotification];
		[_activeDocument PG_removeObserver:self name:PGPrefObjectBaseOrientationDidChangeNotification];

		[_activeDocument PG_removeObserver:self name:PGPrefObjectShowsInfoDidChangeNotification];
		[_activeDocument PG_removeObserver:self name:PGPrefObjectShowsThumbnailsDidChangeNotification];
		[_activeDocument PG_removeObserver:self name:PGPrefObjectReadingDirectionDidChangeNotification];
		[_activeDocument PG_removeObserver:self name:PGPrefObjectImageScaleDidChangeNotification];
		[_activeDocument PG_removeObserver:self name:PGPrefObjectAnimatesImagesDidChangeNotification];
		[_activeDocument PG_removeObserver:self name:PGPrefObjectTimerIntervalDidChangeNotification];
	}
	if(flag && !document && _activeDocument) {
		_activeDocument = nil;
		[[self retain] autorelease]; // Necessary if the find panel is open.
		[[self window] close];
		return YES;
	}
	_activeDocument = document;
	if([[self window] isMainWindow]) [[PGDocumentController sharedDocumentController] setCurrentDocument:_activeDocument];
	[_activeDocument PG_addObserver:self selector:@selector(documentWillRemoveNodes:) name:PGDocumentWillRemoveNodesNotification];
	[_activeDocument PG_addObserver:self selector:@selector(documentSortedNodesDidChange:) name:PGDocumentSortedNodesDidChangeNotification];
	[_activeDocument PG_addObserver:self selector:@selector(documentNodeDisplayNameDidChange:) name:PGDocumentNodeDisplayNameDidChangeNotification];
	[_activeDocument PG_addObserver:self selector:@selector(documentNodeIsViewableDidChange:) name:PGDocumentNodeIsViewableDidChangeNotification];
	[_activeDocument PG_addObserver:self selector:@selector(documentBaseOrientationDidChange:) name:PGPrefObjectBaseOrientationDidChangeNotification];

	[_activeDocument PG_addObserver:self selector:@selector(documentShowsInfoDidChange:) name:PGPrefObjectShowsInfoDidChangeNotification];
	[_activeDocument PG_addObserver:self selector:@selector(documentShowsThumbnailsDidChange:) name:PGPrefObjectShowsThumbnailsDidChangeNotification];
	[_activeDocument PG_addObserver:self selector:@selector(documentReadingDirectionDidChange:) name:PGPrefObjectReadingDirectionDidChangeNotification];
	[_activeDocument PG_addObserver:self selector:@selector(documentImageScaleDidChange:) name:PGPrefObjectImageScaleDidChangeNotification];
	[_activeDocument PG_addObserver:self selector:@selector(documentAnimatesImagesDidChange:) name:PGPrefObjectAnimatesImagesDidChangeNotification];
	[_activeDocument PG_addObserver:self selector:@selector(documentTimerIntervalDidChange:) name:PGPrefObjectTimerIntervalDidChangeNotification];
	[self setTimerRunning:NO];
	if(_activeDocument) {
		NSDisableScreenUpdates();
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
			[clipView scrollPinLocationToOffset:offset animation:PGNoAnimation];
			[self _readFinished];
		} else {
			[clipView setDocumentView:view];
			[self setActiveNode:node forward:YES];
		}
		[self documentNodeIsViewableDidChange:nil]; // In case the node has become unviewable in the meantime.
		[searchField setStringValue:query];

		[self documentReadingDirectionDidChange:nil];
		[self documentShowsInfoDidChange:nil];
		[self documentShowsThumbnailsDidChange:nil];
		[_thumbnailController setDocument:_activeDocument];
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

- (void)setActiveNode:(PGNode *)aNode forward:(BOOL)flag
{
	if(![self _setActiveNode:aNode]) return;
	if([[[self window] currentEvent] modifierFlags] & NSControlKeyMask) _initialLocation = PGPreserveLocation;
	else _initialLocation = flag ? PGHomeLocation : [[[NSUserDefaults standardUserDefaults] objectForKey:PGBackwardsInitialLocationKey] integerValue];
	[self _readActiveNode];
}
- (BOOL)tryToSetActiveNode:(PGNode *)aNode forward:(BOOL)flag
{
	if(!aNode) return NO;
	[self setActiveNode:aNode forward:flag];
	return YES;
}
- (BOOL)tryToGoForward:(BOOL)forward allowAlerts:(BOOL)flag
{
	if([self tryToSetActiveNode:[[[self activeNode] resourceAdapter] sortedViewableNodeNext:forward] forward:forward]) return YES;
	[self prepareToLoop];
	return [self tryToLoopForward:forward toNode:[[[[self activeDocument] node] resourceAdapter] sortedViewableNodeFirst:forward] pageForward:forward allowAlerts:flag];
}
- (void)loopForward:(BOOL)flag
{
	[self prepareToLoop];
	[self tryToLoopForward:flag toNode:[[[[self activeDocument] node] resourceAdapter] sortedViewableNodeFirst:flag] pageForward:flag allowAlerts:YES];
}
- (void)prepareToLoop
{
	PGSortOrder const o = [[self activeDocument] sortOrder];
	if(!(PGSortRepeatMask & o) || (PGSortOrderMask & o) != PGSortShuffle) return;
	PGDocument *const doc = [self activeDocument];
	[[doc node] noteSortOrderDidChange]; // Reshuffle.
	[doc noteSortedChildrenDidChange];
}
- (BOOL)tryToLoopForward:(BOOL)loopForward toNode:(PGNode *)node pageForward:(BOOL)pageForward allowAlerts:(BOOL)flag
{
	PGDocument *const doc = [self activeDocument];
	BOOL const left = ([doc readingDirection] == PGReadingDirectionLeftToRight) == !loopForward;
	PGSortOrder const o = [[self activeDocument] sortOrder];
	if(PGSortRepeatMask & o && [self tryToSetActiveNode:node forward:pageForward]) {
		if(flag) [[_graphicPanel content] pushGraphic:left ? [PGAlertGraphic loopedLeftGraphic] : [PGAlertGraphic loopedRightGraphic] window:[self window]];
		return YES;
	}
	if(flag) [[_graphicPanel content] pushGraphic:left ? [PGAlertGraphic cannotGoLeftGraphic] : [PGAlertGraphic cannotGoRightGraphic] window:[self window]];
	return NO;
}
- (void)activateNode:(PGNode *)node
{
	[self setActiveDocument:[node document] closeIfAppropriate:NO];
	[self setActiveNode:node forward:YES];
}

#pragma mark -

- (void)showLoadingIndicator
{
	if(_loadingGraphic) return;
	_loadingGraphic = [[PGLoadingGraphic loadingGraphic] retain];
	[_loadingGraphic setProgress:[[[[self activeNode] resourceAdapter] activity] progress]];
	[[_graphicPanel content] pushGraphic:_loadingGraphic window:[self window]];
}
- (void)offerToOpenBookmark:(PGBookmark *)bookmark
{
	NSAlert *const alert = [[NSAlert alloc] init];
	[alert setMessageText:[NSString stringWithFormat:NSLocalizedString(@"This document has a bookmark for the page %@.", @"Offer to resume from bookmark alert message text. %@ is replaced with the page name."), [[bookmark fileIdentifier] displayName]]];
	[alert setInformativeText:NSLocalizedString(@"If you don't resume from this page, the bookmark will be kept and you will start from the first page as usual.", @"Offer to resume from bookmark alert informative text.")];
	[[alert addButtonWithTitle:NSLocalizedString(@"Resume", @"Do resume from bookmark button.")] setKeyEquivalent:@"\r"];
	[[alert addButtonWithTitle:NSLocalizedString(@"Don't Resume", @"Don't resume from bookmark button.")] setKeyEquivalent:@"\e"];
	NSWindow *const window = [self windowForSheet];
	[bookmark retain];
	if(window) [alert beginSheetModalForWindow:window modalDelegate:self didEndSelector:@selector(_offerToOpenBookmarkAlertDidEnd:returnCode:bookmark:) contextInfo:bookmark];
	else [self _offerToOpenBookmarkAlertDidEnd:alert returnCode:[alert runModal] bookmark:bookmark];
}
- (void)advanceOnTimer
{
	[self setTimerRunning:[self tryToGoForward:YES allowAlerts:YES]];
}

#pragma mark -

- (void)zoomBy:(CGFloat)factor animate:(BOOL)flag
{
	[[self activeDocument] setImageScaleFactor:MAX(PGScaleMin, MIN([_imageView averageScaleFactor] * factor, PGScaleMax)) animate:flag];
}
- (BOOL)zoomKeyDown:(NSEvent *)firstEvent
{
	[NSCursor setHiddenUntilMouseMoves:YES];
	[_imageView setUsesCaching:NO];
	[NSEvent startPeriodicEventsAfterDelay:0.0f withPeriod:PGAnimationFramerate];
	NSEvent *latestEvent = firstEvent;
	PGZoomDirection dir = PGZoomNone;
	BOOL stop = NO, didAnything = NO;
	do {
		NSEventType const type = [latestEvent type];
		if(NSKeyDown == type || NSKeyUp == type) {
			PGZoomDirection newDir = PGZoomNone;
			switch([latestEvent keyCode]) {
				case PGKeyEquals:
				case PGKeyPadPlus:
					newDir = PGZoomIn; break;
				case PGKeyMinus:
				case PGKeyPadMinus:
					newDir = PGZoomOut; break;
			}
			switch(type) {
				case NSKeyDown: dir |= newDir;  break;
				case NSKeyUp:   dir &= ~newDir; break;
			}
		} else {
			switch(dir) {
				case PGZoomNone: stop = YES; break;
				case PGZoomIn:  [self zoomBy:1.1f animate:NO]; break;
				case PGZoomOut: [self zoomBy:1.0f / 1.1f animate:NO]; break;
			}
			if(!stop) didAnything = YES;
		}
	} while(!stop && (latestEvent = [[self window] nextEventMatchingMask:NSKeyDownMask | NSKeyUpMask | NSPeriodicMask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES]));
	[NSEvent stopPeriodicEvents];
	[[self window] discardEventsMatchingMask:NSAnyEventMask beforeEvent:latestEvent];
	[_imageView setUsesCaching:YES];
	return didAnything;
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
	[_loadingGraphic setProgress:[[[[self activeNode] resourceAdapter] activity] progress]];
}
- (void)nodeReadyForViewing:(NSNotification *)aNotif
{
	NSParameterAssert([aNotif object] == [self activeNode]);
	NSError *const error = [[[self activeNode] resourceAdapter] error];
	if(!error) {
		NSPoint const relativeCenter = [clipView relativeCenter];
		NSImageRep *const rep = [[aNotif userInfo] objectForKey:PGImageRepKey];
		PGOrientation const orientation = [[[self activeNode] resourceAdapter] orientationWithBase:YES];
		[_imageView setImageRep:rep orientation:orientation size:[self _sizeForImageRep:rep orientation:orientation]];
		[clipView setDocumentView:_imageView];
		if(PGPreserveLocation == _initialLocation) [clipView scrollRelativeCenterTo:relativeCenter animation:PGNoAnimation];
		else [clipView scrollToLocation:_initialLocation animation:PGNoAnimation];
		[[self window] makeFirstResponder:clipView];
	} else if(PGEqualObjects([error domain], PGNodeErrorDomain)) switch([error code]) {
		case PGGenericError:
			[errorLabel PG_setAttributedStringValue:[[[_activeNode resourceAdapter] dataProvider] attributedString]];
			[errorMessage setStringValue:[error localizedDescription]];
			[errorView setFrameSize:NSMakeSize(NSWidth([errorView frame]), NSHeight([errorView frame]) - NSHeight([errorMessage frame]) + [[errorMessage cell] cellSizeForBounds:NSMakeRect(0.0f, 0.0f, NSWidth([errorMessage frame]), CGFLOAT_MAX)].height)];
			[reloadButton setEnabled:YES];
			[clipView setDocumentView:errorView];
			break;
		case PGPasswordError:
			[passwordLabel PG_setAttributedStringValue:[[[_activeNode resourceAdapter] dataProvider] attributedString]];
			[passwordField setStringValue:@""];
			[clipView setDocumentView:passwordView];
			break;
	}
	if(![_imageView superview]) [_imageView setImageRep:nil orientation:PGUpright size:NSZeroSize];
	[self _readFinished];
	[_thumbnailController clipViewBoundsDidChange:nil];
}

#pragma mark -

- (void)documentWillRemoveNodes:(NSNotification *)aNotif
{
	PGNode *const changedNode = [[aNotif userInfo] objectForKey:PGDocumentNodeKey];
	NSArray *const removedChildren = [[aNotif userInfo] objectForKey:PGDocumentRemovedChildrenKey];
	PGNode *node = [[[self activeNode] resourceAdapter] sortedViewableNodeNext:YES afterRemovalOfChildren:removedChildren fromNode:changedNode];
	if(!node) node = [[[self activeNode] resourceAdapter] sortedViewableNodeNext:NO afterRemovalOfChildren:removedChildren fromNode:changedNode];
	[self setActiveNode:node forward:YES];
}
- (void)documentSortedNodesDidChange:(NSNotification *)aNotif
{
	[self documentShowsInfoDidChange:nil];
	[self documentShowsThumbnailsDidChange:nil];
	if(![self activeNode]) [self setActiveNode:[[[[self activeDocument] node] resourceAdapter] sortedViewableNodeFirst:YES] forward:YES];
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
	PGNode *const node = aNotif ? [[aNotif userInfo] objectForKey:PGDocumentNodeKey] : [self activeNode];
	if(![self activeNode]) {
		if([node isViewable]) [self setActiveNode:node forward:YES];
	} else if([self activeNode] == node) {
		if(![node isViewable] && ![self tryToGoForward:YES allowAlerts:NO] && ![self tryToGoForward:NO allowAlerts:NO]) [self setActiveNode:[[[[self activeDocument] node] resourceAdapter] sortedViewableNodeFirst:YES] forward:YES];
	}
	if(aNotif) {
		[self documentShowsInfoDidChange:nil];
		[self documentShowsThumbnailsDidChange:nil];
		[self _updateNodeIndex];
	}
}
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif
{
	PGOrientation const o = [[[self activeNode] resourceAdapter] orientationWithBase:YES];
	[_imageView setImageRep:[_imageView rep] orientation:o size:[self _sizeForImageRep:[_imageView rep] orientation:o]];
}

#pragma mark -

- (void)documentShowsInfoDidChange:(NSNotification *)aNotif
{
	if([self shouldShowInfo]) {
		[[_infoPanel content] setCount:[[[[self activeDocument] node] resourceAdapter] viewableNodeCount]];
		[_infoPanel displayOverWindow:[self window]];
	} else [_infoPanel fadeOut];
}
- (void)documentShowsThumbnailsDidChange:(NSNotification *)aNotif
{
	if([PGThumbnailController shouldShowThumbnailsForDocument:[self activeDocument]]) {
		if(_thumbnailController) return;
		_thumbnailController = [[PGThumbnailController alloc] init];
		NSDisableScreenUpdates();
		[_thumbnailController setDisplayController:self];
		[self thumbnailControllerContentInsetDidChange:nil];
		NSEnableScreenUpdates();
		[_thumbnailController PG_addObserver:self selector:@selector(thumbnailControllerContentInsetDidChange:) name:PGThumbnailControllerContentInsetDidChangeNotification];
	} else {
		[_thumbnailController PG_removeObserver:self name:PGThumbnailControllerContentInsetDidChangeNotification];
		[_thumbnailController fadeOut];
		[_thumbnailController release];
		_thumbnailController = nil;
		[self thumbnailControllerContentInsetDidChange:nil];
	}
}
- (void)documentReadingDirectionDidChange:(NSNotification *)aNotif
{
	if(![self activeDocument]) return;
	BOOL const ltr = [[self activeDocument] readingDirection] == PGReadingDirectionLeftToRight;
	PGRectCorner const corner = ltr ? PGMinXMinYCorner : PGMaxXMinYCorner;
	PGInset inset = PGZeroInset;
	switch(corner) {
		case PGMinXMinYCorner: inset.minY = [self findPanelShown] ? NSHeight([_findPanel frame]) : 0.0f; break;
		case PGMaxXMinYCorner: inset.minX = [self findPanelShown] ? NSWidth([_findPanel frame]) : 0.0f; break;
	}
	if(_thumbnailController) inset = PGAddInsets(inset, [_thumbnailController contentInset]);
	[_infoPanel setFrameInset:inset];
	[[_infoPanel content] setOriginCorner:corner];
	[_infoPanel updateFrameDisplay:YES];
	[[[self activeDocument] pageMenu] update];
}
- (void)documentImageScaleDidChange:(NSNotification *)aNotif
{
	[self _updateImageViewSizeAllowAnimation:[[[aNotif userInfo] objectForKey:PGPrefObjectAnimateKey] boolValue]];
}
- (void)documentAnimatesImagesDidChange:(NSNotification *)aNotif
{
	[_imageView setAnimates:[[self activeDocument] animatesImages]];
}
- (void)documentTimerIntervalDidChange:(NSNotification *)aNotif
{
	[self setTimerRunning:[self timerRunning]];
}

#pragma mark -

- (void)thumbnailControllerContentInsetDidChange:(NSNotification *)aNotif
{
	NSDisableScreenUpdates();
	PGInset inset = PGZeroInset;
	NSSize minSize = PGWindowMinSize;
	if(_thumbnailController) {
		PGInset const thumbnailInset = [_thumbnailController contentInset];
		inset = PGAddInsets(inset, thumbnailInset);
		minSize.width += thumbnailInset.minX + thumbnailInset.maxX;
	}
	[clipView setBoundsInset:inset];
	[clipView displayIfNeeded];
	[_findPanel setFrameInset:inset];
	[_graphicPanel setFrameInset:inset];
	[self _updateImageViewSizeAllowAnimation:NO];
	[self documentReadingDirectionDidChange:nil];
	[_findPanel updateFrameDisplay:YES];
	[_graphicPanel updateFrameDisplay:YES];
	NSWindow *const w = [self window];
	NSRect currentFrame = [w frame];
	if(NSWidth(currentFrame) < minSize.width) {
		currentFrame.size.width = minSize.width;
		[w setFrame:currentFrame display:YES];
	}
	[w setMinSize:minSize];
	NSEnableScreenUpdates();
}
- (void)prefControllerBackgroundPatternColorDidChange:(NSNotification *)aNotif;
{
	[clipView setBackgroundColor:[[PGPreferenceWindowController sharedPrefController] backgroundPatternColor]];
}

#pragma mark -PGDisplayController(Private)

- (void)_setImageView:(PGImageView *)aView
{
	if(aView == _imageView) return;
	[_imageView unbind:@"antialiasWhenUpscaling"];
	[_imageView unbind:@"usesRoundedCorners"];
	[_imageView release];
	_imageView = [aView retain];
	[_imageView bind:@"antialiasWhenUpscaling" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:PGAntialiasWhenUpscalingKey options:nil];
	[self documentAnimatesImagesDidChange:nil];
}
- (BOOL)_setActiveNode:(PGNode *)aNode
{
	if(aNode == _activeNode) return NO;
	[_activeNode PG_removeObserver:self name:PGNodeLoadingDidProgressNotification];
	[_activeNode PG_removeObserver:self name:PGNodeReadyForViewingNotification];
	[_activeNode release];
	_activeNode = [aNode retain];
	[self _updateNodeIndex];
	[self _updateInfoPanelText];
	[self PG_postNotificationName:PGDisplayControllerActiveNodeDidChangeNotification];
	return YES;
}
- (void)_readActiveNode
{
	[self PG_cancelPreviousPerformRequestsWithSelector:@selector(showLoadingIndicator) object:nil];
	if(!_activeNode) return [self nodeReadyForViewing:nil];
	_reading = YES;
	[self PG_performSelector:@selector(showLoadingIndicator) withObject:nil fireDate:nil interval:0.5f options:kNilOptions];
	[_activeNode PG_addObserver:self selector:@selector(nodeLoadingDidProgress:) name:PGNodeLoadingDidProgressNotification];
	[_activeNode PG_addObserver:self selector:@selector(nodeReadyForViewing:) name:PGNodeReadyForViewingNotification];
	[_activeNode becomeViewed];
	[self setTimerRunning:[self timerRunning]];
}
- (void)_readFinished
{
	_reading = NO;
	[self PG_cancelPreviousPerformRequestsWithSelector:@selector(showLoadingIndicator) object:nil];
	[[_graphicPanel content] popGraphicsOfType:PGSingleImageGraphic]; // Hide most alerts.
	[_loadingGraphic release];
	_loadingGraphic = nil;
	[self PG_postNotificationName:PGDisplayControllerActiveNodeWasReadNotification];
}
- (NSSize)_sizeForImageRep:(NSImageRep *)rep orientation:(PGOrientation)orientation
{
	return [self _sizeForImageRep:rep orientation:orientation scaleMode:[[self activeDocument] imageScaleMode] factor:[[self activeDocument] imageScaleFactor]];
}
- (NSSize)_sizeForImageRep:(NSImageRep *)rep orientation:(PGOrientation)orientation scaleMode:(PGImageScaleMode)scaleMode factor:(float)factor
{
	if(!rep) return NSZeroSize;
	NSSize originalSize = NSMakeSize([rep pixelsWide], [rep pixelsHigh]);
	if(orientation & PGRotated90CCW) {
		CGFloat const w = originalSize.width;
		originalSize.width = originalSize.height;
		originalSize.height = w;
	}
	NSSize newSize = originalSize;
	if(PGConstantFactorScale == scaleMode) {
		newSize.width *= factor;
		newSize.height *= factor;
	} else {
		PGImageScaleConstraint const constraint = [[[NSUserDefaults standardUserDefaults] objectForKey:PGImageScaleConstraintKey] unsignedIntegerValue];
		BOOL const resIndependent = [[[self activeNode] resourceAdapter] isResolutionIndependent];
		NSSize const minSize = constraint != PGUpscaleOnly || resIndependent ? NSZeroSize : newSize;
		NSSize const maxSize = constraint != PGDownscaleOnly || resIndependent ? NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX) : newSize;
		NSRect const bounds = [clipView insetBounds];
		CGFloat scaleX = NSWidth(bounds) / round(newSize.width);
		CGFloat scaleY = NSHeight(bounds) / round(newSize.height);
		if(PGAutomaticScale == scaleMode) {
			NSSize const scrollMax = [clipView maximumDistanceForScrollType:PGScrollByPage];
			if(scaleX > scaleY) scaleX = scaleY = MAX(scaleY, MIN(scaleX, (floor(newSize.height * scaleX / scrollMax.height + 0.3f) * scrollMax.height) / newSize.height));
			else if(scaleX < scaleY) scaleX = scaleY = MAX(scaleX, MIN(scaleY, (floor(newSize.width * scaleY / scrollMax.width + 0.3f) * scrollMax.width) / newSize.width));
		} else if(PGViewFitScale == scaleMode) scaleX = scaleY = MIN(scaleX, scaleY);
		newSize = PGConstrainSize(minSize, PGScaleSizeByXY(newSize, scaleX, scaleY), maxSize);
	}
	return PGIntegralSize(newSize);
}
- (void)_updateImageViewSizeAllowAnimation:(BOOL)flag
{
	[_imageView setSize:[self _sizeForImageRep:[_imageView rep] orientation:[_imageView orientation]] allowAnimation:flag];
}
- (void)_updateNodeIndex
{
	_displayImageIndex = [[[self activeNode] resourceAdapter] viewableNodeIndex];
	[(PGInfoView *)[_infoPanel content] setIndex:_displayImageIndex];
	[self synchronizeWindowTitleWithDocumentName];
}
- (void)_updateInfoPanelText
{
	NSString *text = nil;
	PGNode *const node = [self activeNode];
	if(node) {
		text = [[node identifier] displayName];
		PGNode *const parent = [node parentNode];
		if([parent parentNode]) text = [NSString stringWithFormat:@"%@ %C %@", [[parent identifier] displayName], (unichar)0x25B8, text];
	} else text = NSLocalizedString(@"No image", @"Label for when no image is being displayed in the window.");
	[[_infoPanel content] setStringValue:text];
}
- (void)_setCopyAsDesktopPicturePanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if(NSFileHandlingPanelOKButton != returnCode) return;
	NSURL *const URL = [[savePanel filename] PG_fileURL];
	[[[[self activeNode] resourceAdapter] data] writeToURL:URL atomically:NO];
	if(![[NSScreen PG_mainScreen] PG_setDesktopImageURL:URL]) NSBeep();
}
- (void)_offerToOpenBookmarkAlertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode bookmark:(PGBookmark *)bookmark
{
	[bookmark autorelease];
	if(NSAlertFirstButtonReturn == returnCode) [[self activeDocument] openBookmark:bookmark];
}

#pragma mark -NSWindowController

- (IBAction)showWindow:(id)sender
{
	[super showWindow:sender];
	[self documentReadingDirectionDidChange:nil];
	if([self shouldShowInfo]) [_infoPanel displayOverWindow:[self window]];
	[_thumbnailController display];
}

#pragma mark -

- (void)windowDidLoad
{
	[super windowDidLoad];
	[passwordView retain];

	[[self window] useOptimizedDrawing:YES];
	[[self window] setMinSize:PGWindowMinSize];

	NSImage *const cursorImage = [NSImage imageNamed:@"Cursor-Hand-Pointing"];
	[clipView setAcceptsFirstResponder:YES];
	[clipView setCursor:cursorImage ? [[[NSCursor alloc] initWithImage:cursorImage hotSpot:NSMakePoint(5.0f, 0.0f)] autorelease] : [NSCursor pointingHandCursor]];
	[clipView setPostsFrameChangedNotifications:YES];
	[clipView PG_addObserver:self selector:@selector(clipViewFrameDidChange:) name:NSViewFrameDidChangeNotification];

	_findPanel = [[PGBezelPanel alloc] initWithContentView:findView];
	[_findPanel setInitialFirstResponder:searchField];
	[_findPanel setDelegate:self];
	[_findPanel setAcceptsEvents:YES];
	[_findPanel setCanBecomeKey:YES];

	[self prefControllerBackgroundPatternColorDidChange:nil];
}
- (void)synchronizeWindowTitleWithDocumentName
{
	PGDisplayableIdentifier *const identifier = [[[self activeDocument] node] identifier];
	NSURL *const URL = [identifier URL];
	if([identifier isFileIdentifier]) {
		NSString *const path = [identifier isFileIdentifier] ? [URL path] : nil;
		[[self window] setRepresentedFilename:path ? path : @""];
	} else {
		[[self window] setRepresentedURL:URL];
		NSButton *const docButton = [[self window] standardWindowButton:NSWindowDocumentIconButton];
		NSImage *const image = [[[identifier icon] copy] autorelease];
		[image setSize:[docButton bounds].size];
		[image recache];
		[docButton setImage:image];
	}
	NSUInteger const count = [[[[self activeDocument] node] resourceAdapter] viewableNodeCount];
	NSString *const title = [identifier displayName];
	NSString *const titleDetails = count > 1 ? [NSString stringWithFormat:@" (%lu/%lu)", (unsigned long)_displayImageIndex + 1, (unsigned long)count] : @"";
	[[self window] setTitle:title ? [title stringByAppendingString:titleDetails] : @""];
	NSMutableAttributedString *const menuLabel = [[[identifier attributedStringWithAncestory:NO] mutableCopy] autorelease];
	[[menuLabel mutableString] appendString:titleDetails];
	[[[PGDocumentController sharedDocumentController] windowsMenuItemForDocument:[self activeDocument]] setAttributedTitle:menuLabel];
}
- (void)close
{
	[[self activeDocument] close];
}

#pragma mark -NSResponder

- (id)validRequestorForSendType:(NSString *)sendType returnType:(NSString *)returnType
{
	return ![returnType length] && [self writeSelectionToPasteboard:nil types:[NSArray arrayWithObject:sendType]] ? self : [super validRequestorForSendType:sendType returnType:returnType];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super initWithWindowNibName:@"PGDocument"])) {
		(void)[self window]; // Just load the window so we don't have to worry about it.

		_graphicPanel = [[PGAlertView PG_bezelPanel] retain];
		_infoPanel = [[PGInfoView PG_bezelPanel] retain];
		[self _updateInfoPanelText];

		[[PGPreferenceWindowController sharedPrefController] PG_addObserver:self selector:@selector(prefControllerBackgroundPatternColorDidChange:) name:PGPreferenceWindowControllerBackgroundPatternColorDidChangeNotification];
		[[NSUserDefaults standardUserDefaults] addObserver:self forKeyPath:PGImageScaleConstraintKey options:kNilOptions context:NULL];
	}
	return self;
}
- (void)dealloc
{
	[[NSUserDefaults standardUserDefaults] removeObserver:self forKeyPath:PGImageScaleConstraintKey];
	[self PG_cancelPreviousPerformRequests];
	[self PG_removeObserver];
	[self _setImageView:nil];
	[passwordView release];
	[_activeNode release];
	[_graphicPanel release];
	[_loadingGraphic release];
	[_infoPanel release];
	[_findPanel release];
	[_findFieldEditor release];
	[_thumbnailController release];
	[_nextTimerFireDate release];
	[_timer invalidate];
	[_timer release];
	[super dealloc];
}

#pragma mark -NSObject(NSKeyValueObserving)

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if(PGEqualObjects(keyPath, PGImageScaleConstraintKey)) [self _updateImageViewSizeAllowAnimation:YES];
	else [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
}

#pragma mark -NSObject(NSMenuValidation)

#define PGFuzzyEqualityToCellState(a, b) ({ double __a = (double)(a); double __b = (double)(b); (fabs(__a - __b) < 0.001f ? NSOnState : (fabs(round(__a) - round(__b)) < 0.1f ? NSMixedState : NSOffState)); })
- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	SEL const action = [anItem action];
	NSInteger const tag = [anItem tag];

	// File:
	if(@selector(reveal:) == action) {
		if([[self activeDocument] isOnline]) [anItem setTitle:NSLocalizedString(@"Reveal in Browser", @"Reveal in Finder, Path Finder (www.cocoatech.com) or web browser. Three states of the same item.")];
		else if([[PGDocumentController sharedDocumentController] pathFinderRunning]) [anItem setTitle:NSLocalizedString(@"Reveal in Path Finder", @"Reveal in Finder, Path Finder (www.cocoatech.com) or web browser. Three states of the same item.")];
		else [anItem setTitle:NSLocalizedString(@"Reveal in Finder", @"Reveal in Finder, Path Finder (www.cocoatech.com) or web browser. Three states of the same item.")];
	}

	// Edit:
	if(@selector(performFindPanelAction:) == action) switch([anItem tag]) {
		case NSFindPanelActionShowFindPanel:
		case NSFindPanelActionNext:
		case NSFindPanelActionPrevious: break;
		default: return NO;
	}

	// View:
	if(@selector(toggleFullscreen:) == action) [anItem setTitle:NSLocalizedString(([[PGDocumentController sharedDocumentController] isFullscreen] ? @"Exit Full Screen" : @"Enter Full Screen"), @"Enter/exit full screen. Two states of the same item.")];
	if(@selector(toggleInfo:) == action) [anItem setTitle:NSLocalizedString(([[self activeDocument] showsInfo] ? @"Hide Info" : @"Show Info"), @"Lets the user toggle the on-screen display. Two states of the same item.")];
	if(@selector(toggleThumbnails:) == action) [anItem setTitle:NSLocalizedString(([[self activeDocument] showsThumbnails] ? @"Hide Thumbnails" : @"Show Thumbnails"), @"Lets the user toggle whether thumbnails are shown. Two states of the same item.")];
	if(@selector(changeReadingDirection:) == action) [anItem setState:[[self activeDocument] readingDirection] == tag];
	if(@selector(revertOrientation:) == action) [anItem setState:[[self activeDocument] baseOrientation] == PGUpright];
	if(@selector(toggleAnimation:) == action) {
		BOOL const canAnimate = [_imageView canAnimateRep];
		[anItem setTitle:canAnimate && [[self activeDocument] animatesImages] ? NSLocalizedString(@"Turn Animation Off", @"Title of menu item for toggling animation. Two states.") : NSLocalizedString(@"Turn Animation On", @"Title of menu item for toggling animation. Two states.")];
		if(!canAnimate) return NO;
	}

	// Scale:
	if(@selector(changeImageScaleMode:) == action) {
		if(PGViewFitScale == tag) {
			if([[PGDocumentController sharedDocumentController] isFullscreen]) [anItem setTitle:NSLocalizedString(@"Fit to Screen", @"Scale image down so the entire thing fits menu item. Two labels, depending on mode.")];
			else [anItem setTitle:NSLocalizedString(@"Fit to Window", @"Scale image down so the entire thing fits menu item. Two labels, depending on mode.")];
		}
		if(PGConstantFactorScale == tag) [anItem setState:[[self activeDocument] imageScaleMode] == tag ? PGFuzzyEqualityToCellState(0.0f, log2([[self activeDocument] imageScaleFactor])) : NSOffState];
		else [anItem setState:[[self activeDocument] imageScaleMode] == tag];
	}
	if(@selector(changeImageScaleFactor:) == action) [[[PGDocumentController sharedDocumentController] scaleSlider] setDoubleValue:log2([[self activeDocument] imageScaleFactor])];

	// Sort:
	if(@selector(changeSortOrder:) == action) [anItem setState:(PGSortOrderMask & [[self activeDocument] sortOrder]) == tag];
	if(@selector(changeSortDirection:) == action) {
		[anItem setState:tag == (PGSortDescendingMask & [[self activeDocument] sortOrder])];
		if(([[self activeDocument] sortOrder] & PGSortOrderMask) == PGSortShuffle) return NO;
	}
	if(@selector(changeSortRepeat:) == action) [anItem setState:(PGSortRepeatMask & [[self activeDocument] sortOrder]) == tag];

	// Page:
	if(@selector(nextPage:) == action || @selector(lastPage:) == action) [anItem setKeyEquivalent:[[self activeDocument] readingDirection] == PGReadingDirectionLeftToRight ? @"]" : @"["];
	if(@selector(previousPage:) == action || @selector(firstPage:) == action) [anItem setKeyEquivalent:[[self activeDocument] readingDirection] == PGReadingDirectionLeftToRight ? @"[" : @"]"];
	if(@selector(nextPage:) == action || @selector(previousPage:) == action) [anItem setKeyEquivalentModifierMask:kNilOptions];
	if(@selector(jumpToPage:) == action) {
		PGNode *const node = [[anItem representedObject] nonretainedObjectValue];
		NSCellStateValue state = NSOffState;
		if(node && node == [self activeNode]) state = NSOnState;
		else if([[self activeNode] isDescendantOfNode:node]) state = NSMixedState;
		[anItem setState:state];
		return [node isViewable] || [anItem submenu];
	}

	if(![[self activeNode] isViewable]) {
		if(@selector(reveal:) == action) return NO;
		if(@selector(setAsDesktopPicture:) == action) return NO;
		if(@selector(setCopyAsDesktopPicture:) == action) return NO;
		if(@selector(pauseDocument:) == action) return NO;
		if(@selector(pauseAndCloseDocument:) == action) return NO;
		if(@selector(copy:) == action) return NO;
	}
	if(![[[[self activeDocument] node] resourceAdapter] hasNodesWithData]) {
		if(@selector(saveImagesTo:) == action) return NO;
	}
	if(![[[self activeNode] resourceAdapter] canSaveData]) {
		if(@selector(setCopyAsDesktopPicture:) == action) return NO;
	}
	PGResourceIdentifier *const activeNodeIdent = [[self activeNode] identifier];
	if(![activeNodeIdent isFileIdentifier] || ![activeNodeIdent URL]) {
		if(@selector(setAsDesktopPicture:) == action) return NO;
	}
	PGResourceIdentifier *const selectedNodeIdent = [[self selectedNode] identifier];
	if(![selectedNodeIdent isFileIdentifier] || ![selectedNodeIdent URL]) {
		if(@selector(moveToTrash:) == action) return NO;
	}
	if(![[PGDocumentController sharedDocumentController] canToggleFullscreen]) {
		if(@selector(toggleFullscreen:) == action) return NO;
	}
	if(![self canShowInfo]) {
		if(@selector(toggleInfo:) == action) return NO;
	}
	if(![PGThumbnailController canShowThumbnailsForDocument:[self activeDocument]]) {
		if(@selector(toggleThumbnails:) == action) return NO;
	}
	if(![_imageView canAnimateRep]) {
		if(@selector(toggleAnimation:) == action) return NO;
	}
	PGDocument *const doc = [self activeDocument];
	if([doc imageScaleMode] == PGConstantFactorScale) {
		if(@selector(zoomIn:) == action && fabs([_imageView averageScaleFactor] - PGScaleMax) < 0.01f) return NO;
		if(@selector(zoomOut:) == action && fabs([_imageView averageScaleFactor] - PGScaleMin) < 0.01f) return NO;
	}
	PGNode *const firstNode = [[[[self activeDocument] node] resourceAdapter] sortedViewableNodeFirst:YES];
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
		if(@selector(firstOfFolder:) == action) return NO;
	}
	if([self activeNode] == [[[[self activeDocument] node] resourceAdapter] sortedViewableNodeFirst:NO]) {
		if(@selector(lastPage:) == action) return NO;
		if(@selector(lastOfFolder:) == action) return NO;
	}
	if(![[[[self activeNode] resourceAdapter] containerAdapter] parentAdapter]) {
		if(@selector(skipBeforeFolder:) == action) return NO;
		if(@selector(skipPastFolder:) == action) return NO;
	}
	return [super validateMenuItem:anItem];
}

#pragma mark -NSObject(NSServicesRequests)

- (BOOL)writeSelectionToPasteboard:(NSPasteboard *)pboard types:(NSArray *)types
{
	BOOL wrote = NO;
	[pboard declareTypes:[NSArray array] owner:nil];
	if([clipView documentView] == _imageView && [_imageView writeToPasteboard:pboard types:types]) wrote = YES;
	if([[self activeNode] writeToPasteboard:pboard types:types]) wrote = YES;
	return wrote;
}

#pragma mark -<NSWindowDelegate>

- (BOOL)window:(NSWindow *)window shouldPopUpDocumentPathMenu:(NSMenu *)menu
{
	return ![[self activeDocument] isOnline];
}
- (BOOL)window:(NSWindow *)window shouldDragDocumentWithEvent:(NSEvent *)event from:(NSPoint)dragImageLocation withPasteboard:(NSPasteboard *)pboard
{
	if([self window] != window) return YES;
	PGDisplayableIdentifier *const ident = [[[self activeDocument] node] identifier];
	if(![ident isFileIdentifier]) {
		[pboard declareTypes:[NSArray arrayWithObject:NSURLPboardType] owner:nil];
		[[ident URL] writeToPasteboard:pboard];
	}
	NSImage *const image = [[[ident icon] copy] autorelease];
	[[self window] dragImage:image at:PGOffsetPointByXY(dragImageLocation, 24 - [image size].width / 2, 24 - [image size].height / 2) offset:NSZeroSize event:event pasteboard:pboard source:nil slideBack:YES]; // Left to its own devices, OS X will start the drag image 16 pixels down and to the left of the button, which looks bad at both 16x16 and at 32x32, so always do our own drags.
	return NO;
}
- (id)windowWillReturnFieldEditor:(NSWindow *)window toObject:(id)anObject
{
	if(window != _findPanel) return nil;
	if(!_findFieldEditor) {
		_findFieldEditor = [[PGFindlessTextView alloc] init];
		[_findFieldEditor setFieldEditor:YES];
	}
	return _findFieldEditor;
}

#pragma mark -

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

- (void)windowWillBeginSheet:(NSNotification *)aNotif
{
	[_findPanel setIgnoresMouseEvents:YES];
}
- (void)windowDidEndSheet:(NSNotification *)aNotif
{
	[_findPanel setIgnoresMouseEvents:NO];
}

- (void)windowWillClose:(NSNotification *)aNotif
{
	NSParameterAssert(aNotif);
	if([aNotif object] != [self window]) return;
	if([_findPanel parentWindow]) [_findPanel close];
	[self close];
}

#pragma mark -<PGClipViewDelegate>

- (BOOL)clipView:(PGClipView *)sender handleMouseEvent:(NSEvent *)anEvent first:(BOOL)flag
{
	if(flag) return NO;
	BOOL const primary = [anEvent type] == NSLeftMouseDown;
	BOOL const rtl = [[self activeDocument] readingDirection] == PGReadingDirectionRightToLeft;
	BOOL forward;
	switch([[[NSUserDefaults standardUserDefaults] objectForKey:PGMouseClickActionKey] integerValue]) {
		case PGLeftRightAction: forward = primary == rtl; break;
		case PGRightLeftAction: forward = primary != rtl; break;
		default: forward = primary; break;
	}
	if([anEvent modifierFlags] & NSShiftKeyMask) forward = !forward;
	if(forward) [self nextPage:self];
	else [self previousPage:self];
	return YES;
}
- (BOOL)clipView:(PGClipView *)sender handleKeyDown:(NSEvent *)anEvent
{
	NSUInteger const modifiers = (NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask) & [anEvent modifierFlags];
	unsigned short const keyCode = [anEvent keyCode];
	if(!modifiers) switch(keyCode) {
		case PGKeyEscape: return [[PGDocumentController sharedDocumentController] performEscapeKeyAction];
	}
	if(!modifiers || !(~(NSCommandKeyMask | NSShiftKeyMask) & modifiers)) switch(keyCode) {
		case PGKeyPadPlus:
		case PGKeyPadMinus:
		case PGKeyEquals:
		case PGKeyMinus: [self zoomKeyDown:anEvent]; return YES;
	}
	CGFloat const timerFactor = NSAlternateKeyMask == modifiers ? 10.0f : 1.0f;
	PGDocument *const d = [self activeDocument];
	if(!modifiers || NSAlternateKeyMask == modifiers) switch(keyCode) {
		case PGKey0: [self setTimerRunning:NO]; return YES;
		case PGKey1: [d setTimerInterval:1.0f * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey2: [d setTimerInterval:2.0f * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey3: [d setTimerInterval:3.0f * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey4: [d setTimerInterval:4.0f * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey5: [d setTimerInterval:5.0f * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey6: [d setTimerInterval:6.0f * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey7: [d setTimerInterval:7.0f * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey8: [d setTimerInterval:8.0f * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey9: [d setTimerInterval:9.0f * timerFactor]; [self setTimerRunning:YES]; return YES;
	}
	return [self performKeyEquivalent:anEvent];
}
- (BOOL)clipView:(PGClipView *)sender shouldExitEdges:(PGRectEdgeMask)mask
{
	NSAssert(mask, @"At least one edge must be set.");
	NSAssert(!PGHasContradictoryRectEdges(mask), @"Contradictory edges aren't allowed.");
	BOOL const ltr = [[self activeDocument] readingDirection] == PGReadingDirectionLeftToRight;
	PGNode *const activeNode = [self activeNode];
	if(mask & (ltr ? PGMinXEdgeMask : PGMaxXEdgeMask)) [self previousPage:self];
	else if(mask & (ltr ? PGMaxXEdgeMask : PGMinXEdgeMask)) [self nextPage:self];
	return [self activeNode] != activeNode;
}
- (PGRectEdgeMask)clipView:(PGClipView *)sender directionFor:(PGPageLocation)nodeLocation
{
	return PGReadingDirectionAndLocationToRectEdgeMask(nodeLocation, [[self activeDocument] readingDirection]);
}
- (void)clipView:(PGClipView *)sender magnifyBy:(CGFloat)amount
{
	[_imageView setUsesCaching:NO];
	[[self activeDocument] setImageScaleFactor:MAX(PGScaleMin, MIN([_imageView averageScaleFactor] * (amount / 500.0f + 1.0f), PGScaleMax))];
}
- (void)clipView:(PGClipView *)sender rotateByDegrees:(CGFloat)amount
{
	[clipView scrollCenterTo:[clipView convertPoint:[_imageView rotateByDegrees:amount adjustingPoint:[_imageView convertPoint:[clipView center] fromView:clipView]] fromView:_imageView] animation:PGNoAnimation];
}
- (void)clipViewGestureDidEnd:(PGClipView *)sender
{
	[_imageView setUsesCaching:YES];
	CGFloat const deg = [_imageView rotationInDegrees];
	[_imageView setRotationInDegrees:0.0f];
	PGOrientation o;
	switch((NSInteger)round((deg + 360.0f) / 90.0f) % 4) {
		case 0: o = PGUpright; break;
		case 1: o = PGRotated90CCW; break;
		case 2: o = PGUpsideDown; break;
		case 3: o = PGRotated90CW; break;
		default: PGAssertNotReached(@"Rotation wasn't simplified into an orientation.");
	}
	[[self activeDocument] setBaseOrientation:PGAddOrientation([[self activeDocument] baseOrientation], o)];
}

@end
