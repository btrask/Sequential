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

THIS SOFTWARE IS PROVIDED BY THE Sequential Project ''AS IS'' AND ANY
EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE Sequential Project BE LIABLE FOR ANY
DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
(INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE. */
#import "NSMenuItemAdditions.h"

@interface NSMenu (AEUndocumented)

- (id)_menuImpl;

@end

@protocol AECarbonMenuImpl

- (void)performActionWithHighlightingForItemAtIndex:(int)integer;

@end

@implementation NSMenuItem (AEAdditions)

- (void)AE_addAfterItem:(NSMenuItem *)anItem
{
	NSMenu *const menu = [anItem menu];
	NSAssert(menu, @"Can't add item after an item not in a menu.");
	[menu insertItem:self atIndex:[menu indexOfItem:anItem] + 1];
}
- (void)AE_removeFromMenu
{
	[[self menu] removeItem:self];
}
- (BOOL)AE_performAction
{
	NSMenu *const menu = [self menu];
	[menu update];
	if(![self isEnabled]) return NO;
	int const i = [menu indexOfItem:self];
	if([menu respondsToSelector:@selector(_menuImpl)]) {
		id const menuImpl = [menu _menuImpl];
		if([menuImpl respondsToSelector:@selector(performActionWithHighlightingForItemAtIndex:)]) {
			[menuImpl performActionWithHighlightingForItemAtIndex:i];
			return YES;
		}
	}
	[menu performActionForItemAtIndex:i];
	return YES;
}

@end
