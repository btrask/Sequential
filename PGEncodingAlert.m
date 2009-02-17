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
#import "PGEncodingAlert.h"

// Other
#import "PGZooming.h"

@implementation PGEncodingAlert

#pragma mark Instance Methods

- (id)initWithStringData:(NSData *)data
      guess:(NSStringEncoding)guess;
{
	if(!(self = [self initWithWindowNibName:@"PGEncoding"])) return nil;
	(void)[self window]; // Just load it.
	NSStringEncoding const *const encodings = [NSString availableStringEncodings];
	NSMutableArray *const usedEncodings = [[NSMutableArray alloc] init];
	NSMutableArray *const encodingNames = [[NSMutableArray alloc] init];
	NSMutableArray *const samples = [[NSMutableArray alloc] init];
	unsigned i = 0, defaultRow = 0;
	for(; encodings[i]; i++) {
		NSString *const sample = [[[NSString alloc] initWithBytes:[data bytes] length:[data length] encoding:encodings[i]] autorelease];
		if(!sample) continue;
		if(encodings[i] == guess) defaultRow = [encodingNames count];
		[encodingNames addObject:[NSString localizedNameOfStringEncoding:encodings[i]]];
		[samples addObject:sample];
		[usedEncodings addObject:[NSNumber numberWithInt:encodings[i]]];
	}
	_encodings = usedEncodings;
	_encodingNames = encodingNames;
	_samples = samples;
	[encodingsTable reloadData];
	[encodingsTable selectRow:defaultRow byExtendingSelection:NO];
	[encodingsTable scrollRowToVisible:defaultRow];
	[encodingsTable setDoubleAction:@selector(ok:)];
	[encodingsTable setTarget:self];
	return self;
}

#pragma mark -

- (IBAction)ok:(id)sender
{
	if(sender == encodingsTable && [encodingsTable clickedRow] < 0) return; // We get sent row -1 if the user double-clicks the header.
	NSStringEncoding const encoding = [[_encodings objectAtIndex:[encodingsTable selectedRow]] intValue];
	if(_delegate) [NSApp endSheet:[self window] returnCode:encoding];
	else [NSApp stopModalWithCode:encoding];
}
- (IBAction)cancel:(id)sender
{
	if(_delegate) [NSApp endSheet:[self window] returnCode:0];
	else [NSApp stopModalWithCode:0];
}

#pragma mark -

- (void)beginSheetForWindow:(NSWindow *)window
	withDelegate:(id)anObject
{
	if(window) {
		_delegate = anObject;
		[NSApp beginSheet:[self window] modalForWindow:window modalDelegate:[self retain] didEndSelector:@selector(sheetDidEnd:returnCode:contextInfo:) contextInfo:NULL];
	} else {
		_delegate = nil;
		NSStringEncoding const encoding = [NSApp runModalForWindow:[self window]];
		[[self window] close];
		[anObject encodingAlertDidEnd:self selectedEncoding:encoding];
	}
}
- (void)sheetDidEnd:(NSWindow *)sheet
	returnCode:(int)returnCode
        contextInfo:(void *)contextInfo
{
	[_delegate encodingAlertDidEnd:[self autorelease] selectedEncoding:returnCode];
	[sheet orderOut:self];
}

#pragma mark NSWindowDelegate Protocol

- (NSRect)windowWillUseStandardFrame:(NSWindow *)window
          defaultFrame:(NSRect)defaultFrame
{
	return [window PG_zoomedFrame];
}

#pragma mark NSTableDataSource Protocol

- (int)numberOfRowsInTableView:(NSTableView *)tableView
{
	return [_encodings count];
}
- (id)tableView:(NSTableView *)tableView
      objectValueForTableColumn:(NSTableColumn *)tableColumn
      row:(int)row
{
	if(tableColumn == encodingColumn) return [_encodingNames objectAtIndex:row];
	if(tableColumn == sampleColumn) return [_samples objectAtIndex:row];
	return nil;
}

#pragma mark NSObject

- (void)dealloc
{
	[_encodings release];
	[_encodingNames release];
	[_samples release];
	[super dealloc];
}

@end
