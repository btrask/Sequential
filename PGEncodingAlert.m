/* Copyright © 2007-2008 Ben Trask. All rights reserved.

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
3. The names of its contributors may not be used to endorse or promote
   products derived from this Software without specific prior written
   permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE CONTRIBUTORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS WITH THE SOFTWARE. */
#import "PGEncodingAlert.h"

// Other
#import "PGZooming.h"

@implementation PGEncodingAlert

#pragma mark Instance Methods

- (id)initWithString:(char const *)bytes
      guess:(NSStringEncoding)guess
{
	if(!(self = [self initWithWindowNibName:@""])) return nil;
	(void)[self window]; // Just load it.
	NSStringEncoding const *const encodings = [NSString availableStringEncodings];
	NSMutableArray *const usedEncodings = [[NSMutableArray alloc] init];
	NSMutableArray *const encodingNames = [[NSMutableArray alloc] init];
	NSMutableArray *const samples = [[NSMutableArray alloc] init];
	unsigned i = 0, defaultRow = 0;
	for(; encodings[i]; i++) {
		NSString *const sample = [[[NSString alloc] initWithBytesNoCopy:(void *)bytes length:strlen(bytes) encoding:encodings[i] freeWhenDone:NO] autorelease];
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
		[anObject encodingAlertDidEnd:self selectedEncoding:[NSApp runModalForWindow:[self window]]];
		[[self window] close];
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
	return [window PG_zoomedRectWithDefaultFrame:defaultFrame];
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
