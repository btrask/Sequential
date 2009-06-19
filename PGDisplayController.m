/* Copyright © 2007-2008, The Sequential Project
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
#import "PGPrefController.h"
#import "PGBookmarkController.h"
#import "PGThumbnailController.h"
#import "PGImageSaveAlert.h"
#import "PGEncodingAlert.h"

// Other
#import "PGDelayedPerforming.h"
#import "PGGeometry.h"
#import "PGKeyboardLayout.h"

// Categories
#import "NSControlAdditions.h"
#import "NSObjectAdditions.h"
#import "NSScreenAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGDisplayControllerActiveNodeDidChangeNotification = @"PGDisplayControllerActiveNodeDidChange";
NSString *const PGDisplayControllerActiveNodeWasReadNotification = @"PGDisplayControllerActiveNodeWasRead";
NSString *const PGDisplayControllerTimerDidChangeNotification = @"PGDisplayControllerTimerDidChange";

#define PGScaleMax      16.0f
#define PGScaleMin      (1.0f / 8.0f)
#define PGWindowMinSize ((NSSize){350.0f, 200.0f})

enum {
	PGZoomNone = 0,
	PGZoomIn   = 1 << 0,
	PGZoomOut  = 1 << 1
};
typedef unsigned PGZoomDirection;

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
	return [NSArray arrayWithObjects:NSStringPboardType, NSTIFFPboardType, NSRTFDPboardType, NSFileContentsPboardType, nil];
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
		if([[NSWorkspace sharedWorkspace] openURL:[[[self activeDocument] originalIdentifier] superURLByFollowingAliases:NO]]) return;
	} else {
		NSString *const path = [[[[self activeNode] identifier] superURLByFollowingAliases:NO] path];
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
	if(![ident isFileIdentifier] || ![[NSScreen AE_mainScreen] AE_setDesktopPicturePath:[[ident URLByFollowingAliases:YES] path]]) NSBeep();
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
	int tag;
	NSString *const path = [[[[self selectedNode] identifier] URL] path];
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

- (IBAction)zoomIn:(id)sender
{
	[self zoomBy:2.0f];
}
- (IBAction)zoomOut:(id)sender
{
	[self zoomBy:1 / 2.0f];
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

- (IBAction)firstOfPreviousFolder:(id)sender
{
	if([self tryToSetActiveNode:[[self activeNode] sortedFirstViewableNodeInFolderNext:NO inclusive:NO] initialLocation:PGHomeLocation]) return;
	[self prepareToLoop]; // -firstOfPreviousFolder: is an exception to our usual looping mechanic, so we can't use -loopForward:.
	PGNode *const last = [[[self activeDocument] node] sortedViewableNodeFirst:NO];
	[self tryToLoopForward:NO toNode:([last isSortedFirstViewableNodeOfFolder] ? last : [last sortedFirstViewableNodeInFolderNext:NO inclusive:YES]) initialLocation:PGHomeLocation allowAlerts:YES];
}
- (IBAction)firstOfNextFolder:(id)sender
{
	if([self tryToSetActiveNode:[[self activeNode] sortedFirstViewableNodeInFolderNext:YES inclusive:NO] initialLocation:PGHomeLocation]) return;
	[self loopForward:YES];
}
- (IBAction)skipBeforeFolder:(id)sender
{
	if([self tryToSetActiveNode:[[[self activeNode] containerAdapter] sortedViewableNodeNext:NO includeChildren:NO] initialLocation:PGEndLocation]) return;
	[self loopForward:NO];
}
- (IBAction)skipPastFolder:(id)sender
{
	if([self tryToSetActiveNode:[[[self activeNode] containerAdapter] sortedViewableNodeNext:YES includeChildren:NO] initialLocation:PGHomeLocation]) return;
	[self loopForward:YES];
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
	PGNode *node = [[sender representedObject] nonretainedObjectValue];
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
	[alert beginSheetForWindow:[self windowForSheet] withDelegate:self];
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
		[_activeDocument AE_removeObserver:self name:PGDocumentBaseOrientationDidChangeNotification];

		[_activeDocument AE_removeObserver:self name:PGPrefObjectShowsInfoDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGPrefObjectShowsThumbnailsDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGPrefObjectReadingDirectionDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGPrefObjectImageScaleDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGPrefObjectAnimatesImagesDidChangeNotification];
		[_activeDocument AE_removeObserver:self name:PGPrefObjectTimerIntervalDidChangeNotification];
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
	[_activeDocument AE_addObserver:self selector:@selector(documentBaseOrientationDidChange:) name:PGDocumentBaseOrientationDidChangeNotification];

	[_activeDocument AE_addObserver:self selector:@selector(documentShowsInfoDidChange:) name:PGPrefObjectShowsInfoDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentShowsThumbnailsDidChange:) name:PGPrefObjectShowsThumbnailsDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentReadingDirectionDidChange:) name:PGPrefObjectReadingDirectionDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentImageScaleDidChange:) name:PGPrefObjectImageScaleDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentAnimatesImagesDidChange:) name:PGPrefObjectAnimatesImagesDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentTimerIntervalDidChange:) name:PGPrefObjectTimerIntervalDidChangeNotification];
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
			[clipView scrollPinLocationToOffset:offset];
			[self _readFinished];
		} else {
			[clipView setDocumentView:view];
			[self setActiveNode:node initialLocation:PGHomeLocation];
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

- (PGNode *)activeNode
{
	return [[_activeNode retain] autorelease];
}
- (void)setActiveNode:(PGNode *)aNode
        initialLocation:(PGPageLocation)location
{
	if(![self _setActiveNode:aNode]) return;
	_initialLocation = [[[self window] currentEvent] modifierFlags] & NSControlKeyMask ? PGPreserveLocation : location;
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
- (void)loopForward:(BOOL)flag
{
	[self prepareToLoop];
	[self tryToLoopForward:flag toNode:[[[self activeDocument] node] sortedViewableNodeFirst:flag] initialLocation:(flag ? PGHomeLocation : PGEndLocation) allowAlerts:YES];
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
- (PGClipView *)clipView
{
	return [[clipView retain] autorelease];
}
- (PGPageLocation)initialLocation
{
	return _initialLocation;
}
- (BOOL)isReading
{
	return _reading;
}
- (BOOL)isDisplayingImage
{
	return [clipView documentView] == _imageView;
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

#pragma mark -

- (NSDate *)nextTimerFireDate
{
	return [[_nextTimerFireDate retain] autorelease];
}
- (BOOL)isTimerRunning
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
		_timer = [[self PG_performSelector:@selector(advanceOnTimer) withObject:nil fireDate:_nextTimerFireDate interval:0.0f options:0 mode:NSDefaultRunLoopMode] retain];
	} else {
		_nextTimerFireDate = nil;
		_timer = nil;
	}
	[self AE_postNotificationName:PGDisplayControllerTimerDidChangeNotification];
}
- (void)advanceOnTimer
{
	[self setTimerRunning:[self tryToGoForward:YES allowAlerts:YES]];
}

#pragma mark -

- (void)zoomBy:(float)aFloat
{
	PGDocument *const doc = [self activeDocument];
	[doc setImageScaleFactor:MAX(PGScaleMin, MIN([_imageView averageScaleFactor] * aFloat, PGScaleMax))];
}
- (void)zoomKeyDown:(NSEvent *)firstEvent
{
	[NSCursor setHiddenUntilMouseMoves:YES];
	[_imageView setUsesCaching:NO];
	_allowZoomAnimation = NO;
	[NSEvent startPeriodicEventsAfterDelay:0 withPeriod:PGAnimationFramerate];
	NSEvent *latestEvent = firstEvent;
	PGZoomDirection dir = PGZoomNone;
	BOOL stop = NO;
	do {
		NSEventType const type = [latestEvent type];
		if(NSKeyDown == type || NSKeyUp == type) {
			PGZoomDirection newDir = PGZoomNone;
			switch([latestEvent keyCode]) {
				case PGKeyEquals: newDir = PGZoomIn;  break;
				case PGKeyMinus:  newDir = PGZoomOut; break;
			}
			switch(type) {
				case NSKeyDown: dir |= newDir;  break;
				case NSKeyUp:   dir &= ~newDir; break;
			}
		}
		switch(dir) {
			case PGZoomNone: stop = YES; break;
			case PGZoomIn:  [self zoomBy:1.1f]; break;
			case PGZoomOut: [self zoomBy:1.0f / 1.1f]; break;
		}
	} while(!stop && (latestEvent = [[self window] nextEventMatchingMask:NSKeyDownMask | NSKeyUpMask | NSPeriodicMask untilDate:[NSDate distantFuture] inMode:NSEventTrackingRunLoopMode dequeue:YES]));
	[NSEvent stopPeriodicEvents];
	[[self window] discardEventsMatchingMask:NSAnyEventMask beforeEvent:latestEvent];
	_allowZoomAnimation = YES;
	[_imageView setUsesCaching:YES];
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
		NSPoint const relativeCenter = [clipView relativeCenter];
		NSImageRep *const rep = [[aNotif userInfo] objectForKey:PGImageRepKey];
		PGOrientation const orientation = [[self activeNode] orientationWithBase:YES];
		[_imageView setImageRep:rep orientation:orientation size:[self _sizeForImageRep:rep orientation:orientation]];
		[clipView setDocumentView:_imageView];
		if(PGPreserveLocation == _initialLocation) [clipView scrollRelativeCenterTo:relativeCenter animation:PGNoAnimation];
		else [clipView scrollToLocation:_initialLocation animation:PGNoAnimation];
		[[self window] makeFirstResponder:clipView];
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
	PGNode *node = [[self activeNode] sortedViewableNodeNext:YES afterRemovalOfChildren:removedChildren fromNode:changedNode];
	if(!node) node = [[self activeNode] sortedViewableNodeNext:NO afterRemovalOfChildren:removedChildren fromNode:changedNode];
	[self setActiveNode:node initialLocation:PGHomeLocation];
}
- (void)documentSortedNodesDidChange:(NSNotification *)aNotif
{
	[self documentShowsInfoDidChange:nil];
	[self documentShowsThumbnailsDidChange:nil];
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
	PGNode *const node = aNotif ? [[aNotif userInfo] objectForKey:PGDocumentNodeKey] : [self activeNode];
	if(![self activeNode]) {
		if([node isViewable]) [self setActiveNode:node initialLocation:PGHomeLocation];
	} else if([self activeNode] == node) {
		if(![node isViewable] && ![self tryToGoForward:YES allowAlerts:NO] && ![self tryToGoForward:NO allowAlerts:NO]) [self setActiveNode:[[[self activeDocument] node] sortedViewableNodeFirst:YES] initialLocation:PGHomeLocation];
	}
	if(aNotif) {
		[self documentShowsInfoDidChange:nil];
		[self documentShowsThumbnailsDidChange:nil];
		[self _updateNodeIndex];
	}
}
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif
{
	[_imageView setImageRep:[_imageView rep] orientation:[[self activeNode] orientationWithBase:YES] size:[self _sizeForImageRep:[_imageView rep] orientation:[[self activeNode] orientationWithBase:YES]]];
}

#pragma mark -

- (void)documentShowsInfoDidChange:(NSNotification *)aNotif
{
	if([self shouldShowInfo]) {
		[[_infoPanel content] setCount:[[[self activeDocument] node] viewableNodeCount]];
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
		[_thumbnailController AE_addObserver:self selector:@selector(thumbnailControllerContentInsetDidChange:) name:PGThumbnailControllerContentInsetDidChangeNotification];
	} else {
		[_thumbnailController AE_removeObserver:self name:PGThumbnailControllerContentInsetDidChangeNotification];
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
	PGInfoCorner const corner = ltr ? PGMinXMinYCorner : PGMaxXMinYCorner;
	PGInset inset = PGZeroInset;
	switch(corner) {
		case PGMinXMinYCorner: inset.minY = [self findPanelShown] ? NSHeight([_findPanel frame]) : 0; break;
		case PGMaxXMinYCorner: inset.minX = [self findPanelShown] ? NSWidth([_findPanel frame]) : 0; break;
	}
	if(_thumbnailController) inset = PGAddInsets(inset, [_thumbnailController contentInset]);
	[_infoPanel setFrameInset:inset];
	[[_infoPanel content] setOrigin:corner];
	[_infoPanel updateFrameDisplay:YES];
}
- (void)documentImageScaleDidChange:(NSNotification *)aNotif
{
	[self _updateImageViewSizeAllowAnimation:_allowZoomAnimation];
}
- (void)documentAnimatesImagesDidChange:(NSNotification *)aNotif
{
	[_imageView setAnimates:[[self activeDocument] animatesImages]];
}
- (void)documentTimerIntervalDidChange:(NSNotification *)aNotif
{
	[self setTimerRunning:[self isTimerRunning]];
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
	[clipView setBackgroundColor:[[PGPrefController sharedPrefController] backgroundPatternColor]];
}

#pragma mark -PGDisplayController(Private)

- (void)_setImageView:(PGImageView *)aView
{
	if(aView == _imageView) return;
	[_imageView unbind:@"antialiasWhenUpscaling"];
	[_imageView unbind:@"drawsRoundedCorners"];
	[_imageView release];
	_imageView = [aView retain];
	[_imageView bind:@"antialiasWhenUpscaling" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:PGAntialiasWhenUpscalingKey options:nil];
	[_imageView bind:@"drawsRoundedCorners" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:PGRoundsImageCornersKey options:nil];
	[self documentAnimatesImagesDidChange:nil];
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
	[self AE_postNotificationName:PGDisplayControllerActiveNodeDidChangeNotification];
	return YES;
}
- (void)_readActiveNode
{
	[self PG_cancelPreviousPerformRequestsWithSelector:@selector(showLoadingIndicator) object:nil];
	if(!_activeNode) return [self nodeReadyForViewing:nil];
	_reading = YES;
	[self PG_performSelector:@selector(showLoadingIndicator) withObject:nil fireDate:nil interval:-0.5f options:0];
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
	[self AE_postNotificationName:PGDisplayControllerActiveNodeWasReadNotification];
}
- (NSSize)_sizeForImageRep:(NSImageRep *)rep
          orientation:(PGOrientation)orientation
{
	return [self _sizeForImageRep:rep orientation:orientation scaleMode:[[self activeDocument] imageScaleMode] factor:[[self activeDocument] imageScaleFactor]];
}
- (NSSize)_sizeForImageRep:(NSImageRep *)rep
          orientation:(PGOrientation)orientation
          scaleMode:(PGImageScaleMode)scaleMode
          factor:(float)factor
{
	if(!rep) return NSZeroSize;
	NSSize originalSize = PGActualSizeWithDPI == scaleMode ? [rep size] : NSMakeSize([rep pixelsWide], [rep pixelsHigh]);
	if(orientation & PGRotated90CC) {
		float const w = originalSize.width;
		originalSize.width = originalSize.height;
		originalSize.height = w;
	}
	NSSize newSize = originalSize;
	if(PGConstantFactorScale == scaleMode) {
		newSize.width *= factor;
		newSize.height *= factor;
	} else if(PGActualSizeWithDPI != scaleMode) {
		PGImageScaleConstraint const constraint = [[self activeDocument] imageScaleConstraint];
		BOOL const resIndependent = [[self activeNode] isResolutionIndependent];
		NSSize const minSize = constraint != PGUpscale || resIndependent ? NSZeroSize : newSize;
		NSSize const maxSize = constraint != PGDownscale || resIndependent ? NSMakeSize(FLT_MAX, FLT_MAX) : newSize;
		NSRect const bounds = [clipView insetBounds];
		float scaleX = NSWidth(bounds) / roundf(newSize.width);
		float scaleY = NSHeight(bounds) / roundf(newSize.height);
		if(PGAutomaticScale == scaleMode) {
			NSSize const scrollMax = [clipView maximumDistanceForScrollType:PGScrollByPage];
			if(scaleX > scaleY) scaleX = scaleY = MAX(scaleY, MIN(scaleX, (floorf(newSize.height * scaleX / scrollMax.height + 0.3) * scrollMax.height) / newSize.height));
			else if(scaleX < scaleY) scaleX = scaleY = MAX(scaleX, MIN(scaleY, (floorf(newSize.width * scaleY / scrollMax.width + 0.3) * scrollMax.width) / newSize.width));
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
		if([parent parentNode]) text = [NSString stringWithFormat:@"%@ %C %@", [[parent identifier] displayName], 0x25B8, text];
	} else text = NSLocalizedString(@"No image", @"Label for when no image is being displayed in the window.");
	[[_infoPanel content] setMessageText:text];
}
- (void)_setCopyAsDesktopPicturePanelDidEnd:(NSSavePanel *)savePanel returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if(NSFileHandlingPanelOKButton != returnCode) return;
	NSString *const path = [savePanel filename];
	[[[self activeNode] data] writeToFile:path atomically:NO];
	if(![[NSScreen AE_mainScreen] AE_setDesktopPicturePath:path]) NSBeep();
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
	[encodingView retain];

	[[self window] useOptimizedDrawing:YES];
	[[self window] setMinSize:PGWindowMinSize];

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
	PGDisplayableIdentifier *const identifier = [[[self activeDocument] node] identifier];
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

#pragma mark -NSResponder

- (BOOL)performKeyEquivalent:(NSEvent *)anEvent
{
	unsigned const modifiers = (NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask) & [anEvent modifierFlags];
	unsigned short const keyCode = [anEvent keyCode];
	PGDocumentController *const d = [PGDocumentController sharedDocumentController];
	if(!modifiers || NSCommandKeyMask & modifiers) switch(keyCode) {
		case PGKeyI: return [d performToggleInfo];
	}
	return [super performKeyEquivalent:anEvent] || [d performKeyEquivalent:anEvent];
}
- (id)validRequestorForSendType:(NSString *)sendType
      returnType:(NSString *)returnType
{
	return (!returnType || [@"" isEqual:returnType]) && [self writeSelectionToPasteboard:nil types:[NSArray arrayWithObject:sendType]] ? self : [super validRequestorForSendType:sendType returnType:returnType];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super initWithWindowNibName:@"PGWindow"])) {
		(void)[self window]; // Just load the window so we don't have to worry about it.

		_graphicPanel = [[PGAlertView PG_bezelPanel] retain];
		_infoPanel = [[PGInfoView PG_bezelPanel] retain];
		[self _updateInfoPanelText];

		_allowZoomAnimation = YES;

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
	[_thumbnailController release];
	[_nextTimerFireDate release];
	[_timer invalidate];
	[_timer release];
	[super dealloc];
}

#pragma mark -NSObject(NSMenuValidation)

- (BOOL)validateMenuItem:(NSMenuItem *)anItem
{
	(void)[[PGDocumentController sharedDocumentController] validateMenuItem:anItem];
	SEL const action = [anItem action];
	if(@selector(jumpToPage:) == action) {
		PGNode *const node = [[anItem representedObject] nonretainedObjectValue];
		NSCellStateValue state = NSOffState;
		if(node && node == [self activeNode]) state = NSOnState;
		else if([[self activeNode] isDescendantOfNode:node]) state = NSMixedState;
		[anItem setState:state];
		return [node isViewable] || [anItem submenu];
	}
	if(@selector(reveal:) == action && [[self activeDocument] isOnline]) [anItem setTitle:NSLocalizedString(@"Reveal in Browser", @"Reveal in Finder, Path Finder (www.cocoatech.com) or web browser. Three states of the same item.")];
	if(![[self activeNode] isViewable]) {
		if(@selector(reveal:) == action) return NO;
		if(@selector(setAsDesktopPicture:) == action) return NO;
		if(@selector(setCopyAsDesktopPicture:) == action) return NO;
		if(@selector(pauseDocument:) == action) return NO;
		if(@selector(pauseAndCloseDocument:) == action) return NO;
		if(@selector(copy:) == action) return NO;
	}
	if(![[[self activeDocument] node] hasNodesWithData]) {
		if(@selector(saveImagesTo:) == action) return NO;
	}
	if(![[self activeNode] canSaveData]) {
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
	if(@selector(performFindPanelAction:) == action) switch([anItem tag]) {
		case NSFindPanelActionShowFindPanel:
		case NSFindPanelActionNext:
		case NSFindPanelActionPrevious: break;
		default: return NO;
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
	if([[self activeDocument] baseOrientation] == PGUpright) {
		if(@selector(revertOrientation:) == action) return NO;
	}
	PGDocument *const doc = [self activeDocument];
	if([doc imageScaleMode] == PGConstantFactorScale) {
		if(@selector(zoomIn:) == action && fabsf([_imageView averageScaleFactor] - PGScaleMax) < 0.01) return NO;
		if(@selector(zoomOut:) == action && fabsf([_imageView averageScaleFactor] - PGScaleMin) < 0.01) return NO;
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

#pragma mark -NSObject(NSWindowDelegate)

- (BOOL)window:(NSWindow *)window
        shouldPopUpDocumentPathMenu:(NSMenu *)menu
{
	return ![[self activeDocument] isOnline];
}
- (BOOL)window:(NSWindow *)window
        shouldDragDocumentWithEvent:(NSEvent *)event
        from:(NSPoint)dragImageLocation
        withPasteboard:(NSPasteboard *)pboard
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

#pragma mark -NSObject(NSWindowNotifications)

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

#pragma mark -NSObject(NSServicesRequests)

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

#pragma mark -NSObject(PGClipViewDelegate)

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
	unsigned const modifiers = (NSCommandKeyMask | NSShiftKeyMask | NSAlternateKeyMask) & [anEvent modifierFlags];
	unsigned short const keyCode = [anEvent keyCode];
	if(!modifiers) switch(keyCode) {
		case PGKeyEscape: return [[PGDocumentController sharedDocumentController] performEscapeKeyAction];
		case PGKeyPadPlus: [self nextPage:self]; return YES;
		case PGKeyPadMinus: [self previousPage:self]; return YES;
	}
	if(!modifiers || NSShiftKeyMask == modifiers) switch(keyCode) {
		case PGKeySpace:
		{
			if(![_imageView canAnimateRep]) return NO;
			BOOL const nowPlaying = ![[self activeDocument] animatesImages];
			[[_graphicPanel content] pushGraphic:[PGBezierPathIconGraphic graphicWithIconType:(nowPlaying ? AEPlayIcon : AEPauseIcon)] window:[self window]];
			[[self activeDocument] setAnimatesImages:nowPlaying];
			return YES;
		}
	}
	if(!modifiers || NSCommandKeyMask == modifiers) switch(keyCode) {
		case PGKeyEquals:
		case PGKeyMinus: [self zoomKeyDown:anEvent]; return YES;
	}
	float const timerFactor = NSAlternateKeyMask == modifiers ? 10.0f : 1.0f;
	PGDocument *const d = [self activeDocument];
	if(!modifiers || NSAlternateKeyMask == modifiers) switch(keyCode) {
		case PGKey0: [self setTimerRunning:NO]; return YES;
		case PGKey1: [d setTimerInterval:1 * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey2: [d setTimerInterval:2 * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey3: [d setTimerInterval:3 * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey4: [d setTimerInterval:4 * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey5: [d setTimerInterval:5 * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey6: [d setTimerInterval:6 * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey7: [d setTimerInterval:7 * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey8: [d setTimerInterval:8 * timerFactor]; [self setTimerRunning:YES]; return YES;
		case PGKey9: [d setTimerInterval:9 * timerFactor]; [self setTimerRunning:YES]; return YES;
	}
	return [self performKeyEquivalent:anEvent];
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
	[[self activeDocument] setImageScaleFactor:MAX(PGScaleMin, MIN([_imageView averageScaleFactor] * (amount / 500 + 1), PGScaleMax))];
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

#pragma mark -NSObject(PGDocumentWindowDelegate)

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

#pragma mark -NSObject(PGEncodingAlertDelegate)

- (void)encodingAlertDidEnd:(PGEncodingAlert *)sender
        selectedEncoding:(NSStringEncoding)encoding
{
	if(encoding) [[self activeNode] startLoadWithInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInt:encoding], PGStringEncodingKey, nil]];
}

#pragma mark -<PGDisplayControlling>

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

@end
