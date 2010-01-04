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
#import "PGLocalizing.h"

// Other Sources
#import "PGFoundationAdditions.h"

@implementation NSObject(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName {}

@end

@implementation NSArray(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[self makeObjectsPerformSelector:@selector(PG_localizeFromTable:) withObject:tableName];
}

@end

@implementation NSWindow(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[self setTitle:NSLocalizedStringFromTable([self title], tableName, nil)];
	[[self contentView] PG_localizeFromTable:tableName];
}

@end

@implementation NSView(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[[self subviews] PG_localizeFromTable:tableName];
}

@end

@implementation NSControl(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[[self cell] PG_localizeFromTable:tableName];
}

@end

@implementation NSMatrix(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[[self cells] PG_localizeFromTable:tableName];
}

@end

@implementation NSButtonCell(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[self setTitle:NSLocalizedStringFromTable([self title], tableName, nil)];
	[self setAlternateTitle:NSLocalizedStringFromTable([self alternateTitle], tableName, nil)];
}

@end

@implementation NSTextFieldCell(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[self setStringValue:NSLocalizedStringFromTable([self stringValue], tableName, nil)];
}

@end

@implementation NSPopUpButtonCell(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	// Don't call super because NSPopUpButtonCell doesn't behave like a NSButtonCell.
	[[self menu] PG_localizeFromTable:tableName];
}

@end

@implementation NSSegmentedCell(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	NSInteger i = 0;
	for(; i < [self segmentCount]; i++) [self setLabel:NSLocalizedStringFromTable([self labelForSegment:i], tableName, nil) forSegment:i];
}

@end

@implementation NSTableView(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[[self tableColumns] PG_localizeFromTable:tableName];
}

@end

@implementation NSTableColumn(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[[self headerCell] PG_localizeFromTable:tableName];
}

@end

@implementation NSMenu(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[self setTitle:NSLocalizedStringFromTable([self title], tableName, nil)];
	[[self itemArray] PG_localizeFromTable:tableName];
}

@end

@implementation NSMenuItem(PGLocalizing)

- (void)PG_localizeFromTable:(NSString *)tableName
{
	[super PG_localizeFromTable:tableName];
	[self setTitle:NSLocalizedStringFromTable([self title], tableName, nil)];
	[[self submenu] PG_localizeFromTable:tableName];
}

@end

#pragma mark -

static BOOL (*PGNSBundleLoadNibFileExternalNameTableWithZone)(id, SEL, NSString *, NSDictionary *, NSZone *);
@interface PGBundle : NSBundle
@end

@implementation NSBundle(PGLocalizing)

+ (void)PG_prepareToAutoLocalize
{
	if(PGNSBundleLoadNibFileExternalNameTableWithZone) return;
	PGNSBundleLoadNibFileExternalNameTableWithZone = (BOOL (*)(id, SEL, NSString *, NSDictionary *, NSZone *))[self PG_useInstance:NO implementationFromClass:[PGBundle class] forSelector:@selector(loadNibFile:externalNameTable:withZone:)];
}

@end

@implementation PGBundle

#pragma mark -PGBundle(NSNibLoading)

+ (BOOL)loadNibFile:(NSString *)fileName externalNameTable:(NSDictionary *)context withZone:(NSZone *)zone
{
	if(![context objectForKey:NSNibTopLevelObjects]) {
		NSMutableDictionary *const dict = [[context mutableCopy] autorelease];
		[dict setObject:[NSMutableArray array] forKey:NSNibTopLevelObjects];
		context = dict;
	}
	if(!PGNSBundleLoadNibFileExternalNameTableWithZone(self, _cmd, fileName, context, zone)) return NO;
	[[context objectForKey:NSNibTopLevelObjects] PG_localizeFromTable:[[fileName lastPathComponent] stringByDeletingPathExtension]];
	return YES;
}

@end
