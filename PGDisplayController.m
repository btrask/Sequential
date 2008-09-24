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
#import "PGGenericImageAdapter.h"
#import "PGResourceIdentifier.h"

// Views
#import "PGDocumentWindow.h"
#import "PGImageView.h"
#import "PGBezelPanel.h"
#import "PGAlertView.h"
#import "PGOSDView.h"
#import "PGFindView.h"

// Controllers
#import "PGDocumentController.h"
#import "PGPrefController.h"
#import "PGBookmarkController.h"
#import "PGExtractAlert.h"
#import "PGEncodingAlert.h"

// Other
#import "PGNonretainedObjectProxy.h"

// Categories
#import "NSControlAdditions.h"
#import "NSObjectAdditions.h"
#import "NSStringAdditions.h"

NSString *const PGDisplayControllerActiveNodeDidChangeNotification = @"PGDisplayControllerActiveNodeDidChange";
NSString *const PGDisplayControllerTimerDidChangeNotification      = @"PGDisplayControllerTimerDidChange";

#define PGScaleMax 16.0f
#define PGScaleMin (1.0f / 8.0f)

static inline NSSize PGConstrainSize(NSSize min, NSSize size, NSSize max)
{
	return NSMakeSize(MIN(MAX(min.width, size.width), max.width), MIN(MAX(min.height, size.height), max.height));
}
static inline NSSize PGScaleSize(NSSize size, float scaleX, float scaleY)
{
	return NSMakeSize(size.width * scaleX, size.height * scaleY);
}

@interface PGDisplayController (Private)

- (void)_loadActiveNode;
- (NSSize)_sizeForImageRep:(NSImageRep *)rep orientation:(PGOrientation)orientation;
- (void)_updateImageViewSizeAllowAnimation:(BOOL)flag;
- (void)_updateNodeIndex;
- (void)_updateInfoPanelLocationAnimate:(BOOL)flag;
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
- (IBAction)toggleOnScreenDisplay:(id)sender
{
	[[self activeDocument] setShowsOnScreenDisplay:![[self activeDocument] showsOnScreenDisplay]];
}

#pragma mark -

- (IBAction)zoomIn:(id)sender
{
	PGDocument *const doc = [self activeDocument];
	[doc setImageScaleFactor:MIN(PGScaleMax, [imageView averageScaleFactor] * 2)];
	[doc setImageScalingMode:PGConstantFactorScaling];
}
- (IBAction)zoomOut:(id)sender
{
	PGDocument *const doc = [self activeDocument];
	[doc setImageScaleFactor:MAX(PGScaleMin, [imageView averageScaleFactor] / 2)];
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
	if(![[self activeNode] reload]) return;
	[reloadButton setEnabled:NO];
	[self _loadActiveNode];
}
- (IBAction)decrypt:(id)sender
{
	PGNode *const activeNode = [self activeNode];
	[activeNode AE_addObserver:self selector:@selector(nodeLoadingDidProgress:) name:PGNodeLoadingDidProgressNotification];
	[activeNode AE_addObserver:self selector:@selector(nodeReadyForViewing:) name:PGNodeReadyForViewingNotification];
	[activeNode setPassword:[passwordField stringValue]];
	[activeNode loadWithInfo:nil];
	[activeNode becomeViewed];
}
- (IBAction)chooseEncoding:(id)sender
{
	PGEncodingAlert *const alert = [[[PGEncodingAlert alloc] initWithString:[[self activeNode] unencodedSampleString] guess:[[self activeNode] defaultEncoding]] autorelease];
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
	[_activeDocument storeNode:[self activeNode] center:[clipView center] query:[searchField stringValue]];
	[_activeDocument AE_removeObserver:self name:PGDocumentWillRemoveNodesNotification];
	[_activeDocument AE_removeObserver:self name:PGDocumentSortedNodesDidChangeNotification];
	[_activeDocument AE_removeObserver:self name:PGDocumentNodeDisplayNameDidChangeNotification];
	[_activeDocument AE_removeObserver:self name:PGDocumentNodeIsViewableDidChangeNotification];
	[_activeDocument AE_removeObserver:self name:PGDocumentBaseOrientationDidChangeNotification];
	[_activeDocument AE_removeObserver:self name:PGPrefObjectShowsOnScreenDisplayDidChangeNotification];
	[_activeDocument AE_removeObserver:self name:PGPrefObjectReadingDirectionDidChangeNotification];
	[_activeDocument AE_removeObserver:self name:PGPrefObjectImageScaleDidChangeNotification];
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
	[_activeDocument AE_addObserver:self selector:@selector(documentShowsOnScreenDisplayDidChange:) name:PGPrefObjectShowsOnScreenDisplayDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentReadingDirectionDidChange:) name:PGPrefObjectReadingDirectionDidChangeNotification];
	[_activeDocument AE_addObserver:self selector:@selector(documentImageScaleDidChange:) name:PGPrefObjectImageScaleDidChangeNotification];
	NSDisableScreenUpdates();
	[self setActiveNode:nil initialLocation:PGHomeLocation]; // Clear the screen, because the new node might take a while to load.
	[self documentSortedNodesDidChange:nil];
	[self _updateInfoPanelLocationAnimate:NO];
	if([_activeDocument showsOnScreenDisplay]) [_infoPanel displayOverWindow:[self window]];
	else [_infoPanel close];
	PGNode *node;
	NSPoint center;
	NSString *query;
	if([_activeDocument getStoredNode:&node center:&center query:&query]) {
		[self setActiveNode:node initialLocation:PGHomeLocation];
		[clipView scrollToCenterAt:center allowAnimation:NO];
		[searchField setStringValue:query];
	} else [self setActiveNode:[_activeDocument initialNode] initialLocation:PGHomeLocation];
	NSEnableScreenUpdates();
	[self setTimerInterval:0];
	return NO;
}
- (void)activateDocument:(PGDocument *)document {}

#pragma mark -

- (PGNode *)activeNode
{
	return [[_activeNode retain] autorelease];
}
- (void)setActiveNode:(PGNode *)aNode
        initialLocation:(PGPageLocation)location
{
	if(aNode == _activeNode) return;
	[_activeNode AE_removeObserver:self name:PGNodeLoadingDidProgressNotification];
	[_activeNode AE_removeObserver:self name:PGNodeReadyForViewingNotification];
	[_activeNode release];
	_activeNode = [aNode retain];
	[self _updateNodeIndex];
	[self _updateInfoPanelText];
	_initialLocation = location;
	[self _loadActiveNode];
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
		if(flag) [(PGAlertView *)[_graphicPanel contentView] pushGraphic:(left ? [PGAlertGraphic loopedLeftGraphic] : [PGAlertGraphic loopedRightGraphic]) window:[self window]];
		return YES;
	}
	if(flag) [(PGAlertView *)[_graphicPanel contentView] pushGraphic:(left ? [PGAlertGraphic cannotGoLeftGraphic] : [PGAlertGraphic cannotGoRightGraphic]) window:[self window]];
	return NO;
}
- (void)showNode:(PGNode *)node
{
	[self setActiveDocument:[node document] closeIfAppropriate:NO];
	[self setActiveNode:node initialLocation:PGHomeLocation];
}

#pragma mark -

- (PGImageView *)imageView
{
	return [[imageView retain] autorelease];
}
- (void)setImageView:(PGImageView *)aView
{
	if(aView == imageView) return;
	[imageView removeFromSuperview];
	if(aView) [clipView addSubview:aView];
	[imageView unbind:@"animates"];
	[imageView unbind:@"antialiasWhenUpscaling"];
	[imageView unbind:@"drawsRoundedCorners"];
	[imageView release];
	imageView = [aView retain];
}
- (void)sendComponentsTo:(PGDisplayController *)controller
{
	if(!controller) return;
	PGImageView *ourImageView = [self imageView];
	[self setImageView:nil];
	[controller setImageView:ourImageView];
}

#pragma mark -

- (BOOL)loadingIndicatorShown
{
	return _loadingGraphic != nil;
}
- (void)showLoadingIndicator
{
	if(_loadingGraphic) return [_loadingGraphic setProgress:[[self activeNode] loadingProgress]];
	_loadingGraphic = [[PGLoadingGraphic loadingGraphic] retain];
	[_loadingGraphic setProgress:[[self activeNode] loadingProgress]];
	[(PGAlertView *)[_graphicPanel contentView] pushGraphic:_loadingGraphic window:[self window]];
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
		[self _updateInfoPanelLocationAnimate:NO];
		NSEnableScreenUpdates();
	} else {
		[_findPanel fadeOut];
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
	[self showLoadingIndicator];
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
		PGOrientation const orientation = [[self activeNode] orientation];
		[imageView setImageRep:rep orientation:orientation size:[self _sizeForImageRep:rep orientation:orientation]];
		[clipView setDocumentView:imageView];
		[clipView scrollToLocation:_initialLocation allowAnimation:NO];
		[[self window] makeFirstResponder:clipView];
	}
	[self PG_cancelPreviousPerformRequestsWithSelector:@selector(showLoadingIndicator) object:nil];
	[(PGAlertView *)[_graphicPanel contentView] popGraphicsOfType:PGSingleImageGraphic]; // Hide most alerts.
	[_loadingGraphic release];
	_loadingGraphic = nil;
	[[self activeNode] AE_removeObserver:self name:PGNodeLoadingDidProgressNotification];
	[[self activeNode] AE_removeObserver:self name:PGNodeReadyForViewingNotification];
	[self AE_postNotificationName:PGDisplayControllerActiveNodeDidChangeNotification];
	[self _runTimer];
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
	unsigned const count = [[[self activeDocument] node] viewableNodeCount];
	[(PGOSDView *)[_infoPanel contentView] setCount:count];
	if(![self activeNode] && count) [self setActiveNode:[[[self activeDocument] node] sortedViewableNodeFirst:YES] initialLocation:PGHomeLocation];
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
	[self _updateNodeIndex];
	[(PGOSDView *)[_infoPanel contentView] setCount:[[[self activeDocument] node] viewableNodeCount]];
}

- (void)documentShowsOnScreenDisplayDidChange:(NSNotification *)aNotif
{
	if([[self activeDocument] showsOnScreenDisplay]) [_infoPanel displayOverWindow:[self window]];
	else [_infoPanel fadeOut];
}
- (void)documentReadingDirectionDidChange:(NSNotification *)aNotif
{
	[self _updateInfoPanelLocationAnimate:NO];
}
- (void)documentImageScaleDidChange:(NSNotification *)aNotif
{
	[self _updateImageViewSizeAllowAnimation:YES];
}
- (void)documentBaseOrientationDidChange:(NSNotification *)aNotif
{
	[imageView setImageRep:[imageView rep] orientation:[[self activeNode] orientation] size:[self _sizeForImageRep:[imageView rep] orientation:[[self activeNode] orientation]]];
}

#pragma mark -

- (void)prefControllerBackgroundPatternColorDidChange:(NSNotification *)aNotif;
{
	[clipView setBackgroundColor:[[PGPrefController sharedPrefController] backgroundPatternColor]];
}

#pragma mark Private Protocol

- (void)_loadActiveNode
{
	[self PG_cancelPreviousPerformRequestsWithSelector:@selector(showLoadingIndicator) object:nil];
	if(!_activeNode) return [self nodeReadyForViewing:nil];
	[self PG_performSelector:@selector(showLoadingIndicator) withObject:nil afterDelay:0.5 retain:NO];
	[_activeNode AE_addObserver:self selector:@selector(nodeLoadingDidProgress:) name:PGNodeLoadingDidProgressNotification];
	[_activeNode AE_addObserver:self selector:@selector(nodeReadyForViewing:) name:PGNodeReadyForViewingNotification];
	[_activeNode becomeViewed];
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
		float scaleX = NSWidth([clipView bounds]) / roundf(newSize.width);
		float scaleY = NSHeight([clipView bounds]) / roundf(newSize.height);
		if(PGAutomaticScaling == scalingMode) scaleX = scaleY = MAX(scaleX, scaleY);
		else if(PGViewFitScaling == scalingMode) scaleX = scaleY = MIN(scaleX, scaleY);
		newSize = PGConstrainSize(minSize, PGScaleSize(newSize, scaleX, scaleY), maxSize);
	}
	return NSMakeSize(roundf(newSize.width), roundf(newSize.height));
}
- (void)_updateImageViewSizeAllowAnimation:(BOOL)flag
{
	[imageView setSize:[self _sizeForImageRep:[imageView rep] orientation:[imageView orientation]] allowAnimation:flag];
}
- (void)_updateNodeIndex
{
	_displayImageIndex = [[self activeNode] viewableNodeIndex];
	[(PGOSDView *)[_infoPanel contentView] setIndex:_displayImageIndex];
	[self synchronizeWindowTitleWithDocumentName];
}
- (void)_updateInfoPanelLocationAnimate:(BOOL)flag
{
	if(![self activeDocument]) return; // If we're closing, don't bother.
	PGOSDCorner const corner = [[self activeDocument] readingDirection] == PGReadingDirectionLeftToRight ? PGMinXMinYCorner : PGMaxXMinYCorner;
	[[_infoPanel contentView] setOrigin:corner offset:NSMakeSize(0, (PGMinXMinYCorner == corner && [self findPanelShown] ? NSHeight([_findPanel frame]) : 0))];
	[_infoPanel changeFrameAnimate:flag];
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
	[[_infoPanel contentView] setMessageText:text];
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
	if([[self activeDocument] baseOrientation] == PGUpright) {
		if(@selector(revertOrientation:) == action) return NO;
	}
	PGDocument *const doc = [self activeDocument];
	if([doc imageScalingMode] == PGConstantFactorScaling) {
		if(@selector(zoomIn:) == action && [imageView averageScaleFactor] >= PGScaleMax) return NO;
		if(@selector(zoomOut:) == action && [imageView averageScaleFactor] <= PGScaleMin) return NO;
	}
	PGNode *const firstNode = [[[self activeDocument] node] sortedViewableNodeFirst:YES];
	if(!firstNode) { // We could use -hasViewableNodes, but we might have to get -firstNode anyway.
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
	if([aNotif object] == _findPanel) [self _updateInfoPanelLocationAnimate:YES];
	else if([aNotif object] == [self window]) {
		if([_findPanel parentWindow]) [_findPanel close];
		[self close];
	}
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

- (void)clipViewWasClicked:(PGClipView *)sender
        event:(NSEvent *)anEvent
{
	BOOL const primary = [anEvent type] == NSLeftMouseDown;
	BOOL const rtl = [[self activeDocument] readingDirection] == PGReadingDirectionRightToLeft;
	BOOL forward;
	switch([[[NSUserDefaults standardUserDefaults] objectForKey:PGMouseClickActionKey] intValue]) {
		case PGNextPreviousAction: forward = primary; break;
		case PGLeftRightAction: forward = primary == rtl; break;
		case PGRightLeftAction: forward = primary != rtl; break;
	}
	if([anEvent modifierFlags] & NSShiftKeyMask) forward = !forward;
	if(forward) [self nextPage:self];
	else [self previousPage:self];
}
- (BOOL)clipView:(PGClipView *)sender
        handleKeyDown:(NSEvent *)anEvent
{
	unsigned const modifiers = [anEvent modifierFlags];
	NSString *const characters = [anEvent charactersIgnoringModifiers];
	if([characters length] != 1) return NO;
	unichar const key = [characters characterAtIndex:0];
	if(modifiers & NSNumericPadKeyMask) switch(key) {
		case '=':
		case '+': [self nextPage:self]; return YES;
		case '-': [self previousPage:self]; return YES;
	} else if(key >= '0' && key <= '9') {
		[self setTimerInterval:(modifiers & NSAlternateKeyMask ? 10.0 : 1.0) * (key - '0')];
		return YES;
	} else switch(key) {
		case '\e': [self toggleFullscreen:self]; return YES;
		case 'i':
		{
			if(NSCommandKeyMask & modifiers) {
				[self toggleOnScreenDisplay:self];
				return YES;
			}
		}
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
	[imageView setUsesCaching:NO];
	PGDocument *const doc = [self activeDocument];
	[doc setImageScaleFactor:MAX(PGScaleMin, MIN(PGScaleMax, [imageView averageScaleFactor] * (amount / 500 + 1)))];
	[doc setImageScalingMode:PGConstantFactorScaling];
}
- (void)clipView:(PGClipView *)sender
        rotateByDegrees:(float)amount
{
	[clipView scrollToCenterAt:[imageView rotateByDegrees:amount] allowAnimation:NO];
}
- (void)clipViewGestureDidEnd:(PGClipView *)sender
{
	[imageView setUsesCaching:YES];
	float const deg = [imageView rotationInDegrees];
	[imageView setRotationInDegrees:0];
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
		if(![types containsObject:NSTIFFPboardType] || [clipView documentView] != imageView) break;
		NSImageRep *const rep = [imageView rep];
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
	if(encoding) [[self activeNode] setEncoding:encoding];
}

#pragma mark NSWindowController

- (IBAction)showWindow:(id)sender
{
	[super showWindow:sender];
	[self _updateInfoPanelLocationAnimate:NO];
	[self documentShowsOnScreenDisplayDidChange:nil];
}

#pragma mark -

- (void)windowDidLoad
{
	[super windowDidLoad];
	// We don't need to retain imageView because -setImageView: automatically gets called when the Nib is loaded.
	[passwordView retain];
	[encodingView retain];

	[[self window] useOptimizedDrawing:YES];

	[clipView setPostsFrameChangedNotifications:YES];
	[clipView AE_addObserver:self selector:@selector(clipViewFrameDidChange:) name:NSViewFrameDidChangeNotification];

	_findPanel = [[PGBezelPanel alloc] initWithContentView:findView];
	[_findPanel setInitialFirstResponder:searchField];
	[_findPanel setDelegate:self];
	[_findPanel setAcceptsEvents:YES];

	[imageView bind:@"animates" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:PGAnimatesImagesKey options:nil];
	[imageView bind:@"antialiasWhenUpscaling" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:PGAntialiasWhenUpscalingKey options:nil];
	[imageView bind:@"drawsRoundedCorners" toObject:[NSUserDefaults standardUserDefaults] withKeyPath:PGRoundsImageCornersKey options:nil];
	[self prefControllerBackgroundPatternColorDidChange:nil];
}
- (void)synchronizeWindowTitleWithDocumentName
{
	PGResourceIdentifier *const identifier = [[[self activeDocument] node] identifier];
	NSURL *const URL = [identifier URL];
	if(PGIsLeopardOrLater()) {
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
	NSString *const titleDetails = count ? [NSString stringWithFormat:@" (%u/%u)", _displayImageIndex + 1, count] : @"";
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
		_infoPanel = [[PGOSDView PG_bezelPanel] retain];
		[self _updateInfoPanelText];

		[[PGPrefController sharedPrefController] AE_addObserver:self selector:@selector(prefControllerBackgroundPatternColorDidChange:) name:PGPrefControllerBackgroundPatternColorDidChangeNotification];
	}
	return self;
}
- (void)dealloc
{
	[self PG_cancelPreviousPerformRequests];
	[self AE_removeObserver];
	[self setImageView:nil];
	[passwordView release];
	[encodingView release];
	[_activeNode release];
	[_graphicPanel release];
	[_loadingGraphic release];
	[_infoPanel release];
	[_findPanel release];
	[_findFieldEditor release];
	[_nextTimerFireDate release];
	[_timer invalidate];
	[_timer release];
	[super dealloc];
}

@end
