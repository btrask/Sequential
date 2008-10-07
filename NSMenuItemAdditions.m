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
