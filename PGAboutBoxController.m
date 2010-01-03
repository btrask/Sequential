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
#import "PGAboutBoxController.h"

// Other Sources
#import "PGFoundationAdditions.h"
#import "PGZooming.h"

static NSString *const PGPaneItemKey = @"PGPaneItem";

static PGAboutBoxController *PGSharedAboutBoxController;

@implementation PGAboutBoxController

#pragma mark +PGAboutBoxController

+ (id)sharedAboutBoxController
{
	return PGSharedAboutBoxController ? PGSharedAboutBoxController : [[[self alloc] init] autorelease];
}

#pragma mark -PGAboutBoxController

- (IBAction)changePane:(id)sender
{
	NSString *path = nil;
	switch([paneControl selectedSegment]) {
		case 0: path = [[NSBundle mainBundle] pathForResource:@"Credits" ofType:@"rtf"]; break;
		case 1: path = [[NSBundle mainBundle] pathForResource:@"History" ofType:@"txt"]; break;
		case 2: path = [[NSBundle mainBundle] pathForResource:@"License" ofType:@"txt"]; break;
	}
	if(!path) return;
	[textView setSelectedRange:NSMakeRange(0, 0)];
	[[textView textStorage] removeLayoutManager:[textView layoutManager]];
	NSDictionary *attrs = nil;
	[[[NSTextStorage alloc] initWithURL:[path PG_fileURL] options:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithUnsignedInteger:NSUTF8StringEncoding], NSCharacterEncodingDocumentAttribute, nil] documentAttributes:&attrs error:NULL] addLayoutManager:[textView layoutManager]];
	if(PGEqualObjects([attrs objectForKey:NSDocumentTypeDocumentAttribute], NSPlainTextDocumentType)) {
		NSFont *const font = [NSFont fontWithName:@"Monaco" size:10.0f]; // There's no way to ask for the system-wide fixed pitch font, so we use 10pt Monaco since it's the default for TextEdit.
		if(font) [textView setFont:font];
	}
}

#pragma mark -NSWindowController

- (void)windowDidLoad
{
	[paneControl sizeToFit];
	[paneControl retain];
	[paneControl removeFromSuperview];
	if([paneControl respondsToSelector:@selector(setSegmentStyle:)]) [paneControl setSegmentStyle:NSSegmentStyleTexturedRounded];
	NSToolbar *const toolbar = [[(NSToolbar *)[NSToolbar alloc] initWithIdentifier:@"PGAboutBoxControllerToolbar"] autorelease];
	[toolbar setDisplayMode:NSToolbarDisplayModeIconOnly];
	[toolbar setSizeMode:NSToolbarSizeModeRegular];
	[toolbar setAllowsUserCustomization:NO];
	[toolbar setDelegate:self];
	[[self window] setToolbar:toolbar];
	[[self window] setShowsToolbarButton:NO];
	[[self window] center];
	[self changePane:nil];
	[super windowDidLoad];
}

#pragma mark -NSObject

- (id)init
{
	if((self = [super initWithWindowNibName:@"PGAbout"])) {
		if(PGSharedAboutBoxController) {
			[self release];
			return [PGSharedAboutBoxController retain];
		} else PGSharedAboutBoxController = [self retain];
	}
	return self;
}
- (void)dealloc
{
	[paneControl release];
	[super dealloc];
}

#pragma mark -<NSToolbarDelegate>

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)ident willBeInsertedIntoToolbar:(BOOL)flag
{
	NSParameterAssert(PGEqualObjects(ident, PGPaneItemKey));
	NSToolbarItem *const item = [[[NSToolbarItem alloc] initWithItemIdentifier:ident] autorelease];
	[item setView:paneControl];
	[item setMinSize:[paneControl frame].size];
	return item;
}
- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar
{
	return [NSArray arrayWithObjects:NSToolbarFlexibleSpaceItemIdentifier, PGPaneItemKey, NSToolbarFlexibleSpaceItemIdentifier, nil];
}
- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar
{
	return [self toolbarDefaultItemIdentifiers:toolbar];
}

#pragma mark -<NSWindowDelegate>

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window defaultFrame:(NSRect)newFrame
{
	return [window PG_zoomedFrame];
}

@end
